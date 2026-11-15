import os
import sys
import logging
from typing import List, Optional, Dict, Any

# Compatibility shim for models trained with scikit-learn <= 1.6 unpickled in scikit-learn >= 1.7
if "_loss" not in sys.modules:
    try:
        from sklearn._loss import _loss
        sys.modules["_loss"] = _loss
    except (ImportError, ModuleNotFoundError):
        pass

import joblib
import numpy as np
import pandas as pd

logger = logging.getLogger("ralpa_engine")

# Base feature schema required by the Colab-trained models (carevora_training_colab_v2)
DROP_COLUMNS = [
    "resident_id",
    "split",
    "current_risk_score_0_1",
    "current_risk_level",
    "trajectory_label",
    "high_risk_label",
]

CORE_BASE_FEATURES = [
    "facial_happy_prob",
    "facial_sad_prob",
    "facial_neutral_prob",
    "vocal_positive_score",
    "vocal_stress_score",
    "vocal_energy_score",
    "speech_rate_words_per_sec",
    "response_latency_sec",
    "questionnaire_loneliness_score_0_10",
    "emotional_wellness_score_0_10",
    "social_isolation_score_0_10",
    "family_contacts_per_week",
    "social_interactions_per_week",
    "activity_participation_score_0_10",
    "conversation_minutes_per_assessment",
    "social_baseline_deviation",
    "positive_emotion_baseline_deviation",
    "wellness_baseline_deviation",
]

BASE_FEATURES_ORDER = ["visit_month"] + CORE_BASE_FEATURES


class RALPAEngine:
    """
    RALPA: Resident-Adaptive Longitudinal Prediction Algorithm
    Component: J26-IT-421 (Carevora Emotional Wellness Component)
    Specification: IT23228108(2).pdf (Methodology Sec 3.1 - 3.5, FR5 - FR8)

    Non-diagnostic longitudinal prediction and early-warning engine:
    1. Loads and runs the two Google Colab-trained ML ensembles:
       - carevora_high_risk_model (4-model ensemble: 2xLightGBM, LogReg, HistGB; threshold 0.31)
       - carevora_trajectory_model (3-model ensemble: 2xLightGBM, LogReg; 3 classes)
    2. Builds the exact 149-feature longitudinal schema (19 base + 126 history/deviation + 4 composites).
    3. Maintains resident-adaptive baseline modeling and deviation detection from historical sessions.
    4. Distinguishes transient fluctuations from sustained drift via slope regression.
    5. Projects 14-day and 7-day future risk trajectories when history is sufficient.
    6. Enforces the Insufficient History Guard (< 2 sessions -> BASELINE_ESTABLISHING).
    7. Exposes explainable contributing factors and personalized intervention recommendations.
    """

    def __init__(self, models_dir: Optional[str] = None):
        self.weights = {
            "questionnaire": 0.40,
            "social": 0.25,
            "facial": 0.20,
            "vocal": 0.15,
        }

        if models_dir is None:
            models_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
        self.models_dir = models_dir

        self.high_risk_model_path: Optional[str] = None
        self.trajectory_model_path: Optional[str] = None

        self.high_risk_artifact: Optional[Dict[str, Any]] = None
        self.trajectory_artifact: Optional[Dict[str, Any]] = None

        self.expected_features: List[str] = []
        self.high_risk_threshold: float = 0.31
        self.trajectory_classes: List[str] = ["deteriorating", "improving", "stable"]

        self.models_loaded: bool = False
        self.load_error: Optional[str] = None

        self._load_colab_models()

    def _resolve_model_path(self, candidate_names: List[str]) -> Optional[str]:
        for name in candidate_names:
            p = os.path.join(self.models_dir, name)
            if os.path.exists(p):
                return p
        return None

    def _load_colab_models(self) -> None:
        """Loads and verifies both Google Colab-trained .joblib model artifacts."""
        high_risk_candidates = [
            "carevora_high_risk_model.joblib",
            "carevora_high_risk_model - Copy(4).joblib",
            "carevora_high_risk_model - Copy.joblib",
        ]
        trajectory_candidates = [
            "carevora_trajectory_model.joblib",
            "carevora_trajectory_model(6).joblib",
            "carevora_trajectory_model (1).joblib",
        ]

        self.high_risk_model_path = self._resolve_model_path(high_risk_candidates)
        self.trajectory_model_path = self._resolve_model_path(trajectory_candidates)

        if not self.high_risk_model_path or not self.trajectory_model_path:
            missing = []
            if not self.high_risk_model_path:
                missing.append(f"High-risk model (looked for: {high_risk_candidates})")
            if not self.trajectory_model_path:
                missing.append(f"Trajectory model (looked for: {trajectory_candidates})")
            self.load_error = f"Model artifact(s) not found in {self.models_dir}: {'; '.join(missing)}"
            logger.warning(self.load_error)
            return

        try:
            h_obj = joblib.load(self.high_risk_model_path)
            t_obj = joblib.load(self.trajectory_model_path)

            if not isinstance(h_obj, dict) or "models" not in h_obj or "features" not in h_obj:
                raise ValueError("High-risk artifact missing required keys ('models', 'features', 'threshold')")
            if not isinstance(t_obj, dict) or "models" not in t_obj or "features" not in t_obj:
                raise ValueError("Trajectory artifact missing required keys ('models', 'features', 'classes')")

            self.high_risk_artifact = h_obj
            self.trajectory_artifact = t_obj

            self.expected_features = h_obj.get("features", [])
            self.high_risk_threshold = float(h_obj.get("threshold", 0.31))
            self.trajectory_classes = list(t_obj.get("classes", ["deteriorating", "improving", "stable"]))

            # Ensure pipeline estimators remain valid across scikit-learn version differences
            self._patch_imputers(self.high_risk_artifact)
            self._patch_imputers(self.trajectory_artifact)

            self.models_loaded = True
            logger.info(
                f"Successfully loaded Colab models. High-Risk: {os.path.basename(self.high_risk_model_path)}, "
                f"Trajectory: {os.path.basename(self.trajectory_model_path)}. Features: {len(self.expected_features)}"
            )
        except Exception as e:
            self.models_loaded = False
            self.load_error = f"Failed to load joblib models: {e}"
            logger.error(self.load_error, exc_info=True)

    @staticmethod
    def _patch_imputers(artifact: Optional[Dict[str, Any]]) -> None:
        """Adds missing _fill_dtype to SimpleImputer instances unpickled across scikit-learn versions."""
        if not artifact or "models" not in artifact:
            return
        from sklearn.impute import SimpleImputer
        from sklearn.pipeline import Pipeline

        def _patch(est):
            if isinstance(est, Pipeline):
                for _, step in est.steps:
                    _patch(step)
            elif isinstance(est, SimpleImputer):
                if not hasattr(est, "_fill_dtype"):
                    est._fill_dtype = getattr(est, "_fit_dtype", None)

        models = artifact["models"]
        iterable = models.values() if isinstance(models, dict) else models
        for m in iterable:
            _patch(m)

    @staticmethod
    def _safe_float(val: Any, default: float = 80.0, min_val: float = 0.0, max_val: float = 100.0) -> float:
        if val is None:
            return default
        try:
            f = float(val)
            if np.isnan(f) or np.isinf(f):
                return default
            return float(np.clip(f, min_val, max_val))
        except (ValueError, TypeError):
            return default

    def _build_feature_row(
        self,
        current_scores: Dict[str, Any],
        extracted_history_scores: List[float],
        raw_features: Optional[Dict[str, Any]] = None,
    ) -> pd.DataFrame:
        """
        Constructs the exact 149-column feature vector required by the Colab models:
        19 base features + 18*7 historical lag/mean/std/deviation features + 4 composites.
        """
        raw = raw_features or {}
        q_score = current_scores.get("questionnaire", 85.0)
        facial_score = current_scores.get("facial", 80.0)
        vocal_score = current_scores.get("vocal", 80.0)
        social_score = current_scores.get("social", 80.0)

        # 1. Base values for the current session
        visit_month = int(raw.get("visit_month", len(extracted_history_scores) + 1))
        facial_happy = float(raw.get("facial_happy_prob", np.clip(facial_score / 100.0, 0.0, 1.0)))
        facial_sad = float(raw.get("facial_sad_prob", np.clip((100.0 - facial_score) / 100.0 * 0.5, 0.0, 1.0)))
        facial_neutral = float(raw.get("facial_neutral_prob", max(0.0, 1.0 - facial_happy - facial_sad)))

        vocal_pos = float(raw.get("vocal_positive_score", np.clip(vocal_score / 100.0, 0.0, 1.0)))
        vocal_stress = float(raw.get("vocal_stress_score", np.clip((100.0 - vocal_score) / 100.0, 0.0, 1.0)))
        vocal_energy = float(raw.get("vocal_energy_score", np.clip(vocal_score / 100.0, 0.0, 1.0)))

        speech_rate = float(raw.get("speech_rate_words_per_sec", 2.5))
        resp_latency = float(raw.get("response_latency_sec", 1.8))

        q_loneliness_0_10 = float(raw.get("questionnaire_loneliness_score_0_10", np.clip((100.0 - q_score) / 10.0, 0.0, 10.0)))
        emo_wellness_0_10 = float(raw.get("emotional_wellness_score_0_10", np.clip(q_score / 10.0, 0.0, 10.0)))
        social_isolation_0_10 = float(raw.get("social_isolation_score_0_10", np.clip((100.0 - social_score) / 10.0, 0.0, 10.0)))

        family_contacts = float(raw.get("family_contacts_per_week", max(1.0, round(social_score / 25.0))))
        social_interactions = float(raw.get("social_interactions_per_week", max(2.0, round(social_score / 15.0))))
        activity_part_0_10 = float(raw.get("activity_participation_score_0_10", np.clip(social_score / 10.0, 0.0, 10.0)))
        conv_mins = float(raw.get("conversation_minutes_per_assessment", 15.0))

        # Baseline deviations (compared to historical average if history exists)
        if len(extracted_history_scores) >= 1:
            hist_mean_risk = float(np.mean(extracted_history_scores))
            current_risk = 100.0 - (q_score * 0.40 + social_score * 0.25 + facial_score * 0.20 + vocal_score * 0.15)
            wellness_dev = float((100.0 - current_risk) - (100.0 - hist_mean_risk)) / 10.0
            social_dev = float((social_score - (100.0 - hist_mean_risk)) / 10.0)
            pos_emotion_dev = float((facial_happy - 0.5) * 2.0)
        else:
            wellness_dev = 0.0
            social_dev = 0.0
            pos_emotion_dev = 0.0

        current_base_row = {
            "visit_month": visit_month,
            "facial_happy_prob": facial_happy,
            "facial_sad_prob": facial_sad,
            "facial_neutral_prob": facial_neutral,
            "vocal_positive_score": vocal_pos,
            "vocal_stress_score": vocal_stress,
            "vocal_energy_score": vocal_energy,
            "speech_rate_words_per_sec": speech_rate,
            "response_latency_sec": resp_latency,
            "questionnaire_loneliness_score_0_10": q_loneliness_0_10,
            "emotional_wellness_score_0_10": emo_wellness_0_10,
            "social_isolation_score_0_10": social_isolation_0_10,
            "family_contacts_per_week": family_contacts,
            "social_interactions_per_week": social_interactions,
            "activity_participation_score_0_10": activity_part_0_10,
            "conversation_minutes_per_assessment": conv_mins,
            "social_baseline_deviation": float(raw.get("social_baseline_deviation", social_dev)),
            "positive_emotion_baseline_deviation": float(raw.get("positive_emotion_baseline_deviation", pos_emotion_dev)),
            "wellness_baseline_deviation": float(raw.get("wellness_baseline_deviation", wellness_dev)),
        }

        # 2. Reconstruct synthetic/historical timeline for feature engineering
        # Build timeline DataFrame containing history sessions + current session
        hist_rows = []
        for i, h_risk in enumerate(extracted_history_scores):
            h_well = 100.0 - h_risk
            hist_rows.append({
                "visit_month": i + 1,
                "facial_happy_prob": np.clip(h_well / 100.0, 0.0, 1.0),
                "facial_sad_prob": np.clip(h_risk / 200.0, 0.0, 1.0),
                "facial_neutral_prob": max(0.0, 1.0 - (h_well / 100.0) - (h_risk / 200.0)),
                "vocal_positive_score": np.clip(h_well / 100.0, 0.0, 1.0),
                "vocal_stress_score": np.clip(h_risk / 100.0, 0.0, 1.0),
                "vocal_energy_score": np.clip(h_well / 100.0, 0.0, 1.0),
                "speech_rate_words_per_sec": speech_rate,
                "response_latency_sec": resp_latency,
                "questionnaire_loneliness_score_0_10": np.clip(h_risk / 10.0, 0.0, 10.0),
                "emotional_wellness_score_0_10": np.clip(h_well / 10.0, 0.0, 10.0),
                "social_isolation_score_0_10": np.clip(h_risk / 10.0, 0.0, 10.0),
                "family_contacts_per_week": family_contacts,
                "social_interactions_per_week": social_interactions,
                "activity_participation_score_0_10": np.clip(h_well / 10.0, 0.0, 10.0),
                "conversation_minutes_per_assessment": conv_mins,
                "social_baseline_deviation": 0.0,
                "positive_emotion_baseline_deviation": 0.0,
                "wellness_baseline_deviation": 0.0,
            })

        timeline = pd.DataFrame(hist_rows + [current_base_row])

        # 3. Apply exact feature engineering as defined in Colab notebook Cell 5:
        # lag1, lag2, expmean, expstd, roll3, vs_hist, delta1 for all 18 core columns
        new_cols = {}
        for c in CORE_BASE_FEATURES:
            s = timeline[c]
            new_cols[c + "_lag1"] = s.shift(1)
            new_cols[c + "_lag2"] = s.shift(2)
            new_cols[c + "_expmean"] = s.expanding().mean().shift(1)
            new_cols[c + "_expstd"] = s.expanding().std().shift(1)
            new_cols[c + "_roll3"] = s.rolling(3, min_periods=1).mean()
            new_cols[c + "_vs_hist"] = s - new_cols[c + "_expmean"]
            new_cols[c + "_delta1"] = s - new_cols[c + "_lag1"]

        full_df = pd.concat([timeline, pd.DataFrame(new_cols, index=timeline.index)], axis=1)

        # 4. Composite indicators
        full_df["neg_affect"] = (
            full_df.facial_sad_prob + full_df.vocal_stress_score -
            full_df.facial_happy_prob - full_df.vocal_positive_score
        )
        full_df["social_deficit"] = (
            full_df.questionnaire_loneliness_score_0_10 + full_df.social_isolation_score_0_10 -
            full_df.activity_participation_score_0_10
        )
        full_df["wellness_gap"] = (
            full_df.questionnaire_loneliness_score_0_10 - full_df.emotional_wellness_score_0_10
        )
        full_df["contact_total"] = (
            full_df.family_contacts_per_week + full_df.social_interactions_per_week
        )

        # Extract only the latest row (the current session)
        curr_row = full_df.iloc[[-1]].copy()

        # Align with the exact 149 features expected by the models
        if self.expected_features:
            for f in self.expected_features:
                if f not in curr_row.columns:
                    curr_row[f] = 0.0
            curr_row = curr_row[self.expected_features]

        return curr_row

    def predict_progression(
        self,
        resident_id: int,
        current_scores: dict,
        history_scores: list = None,
        score_domain: str = "wellness",
        raw_features: Optional[dict] = None,
    ) -> dict:
        """
        Executes the full emotional wellness workflow:
        Multimodal fusion -> Insufficient history check -> 149-feature processing ->
        Colab High-Risk Model -> Colab Trajectory Model -> RALPA Baseline & Projection ->
        Explainable Factor Attribution -> Personalized Caregiver Recommendations.
        """
        has_questionnaire = (current_scores.get("questionnaire") is not None) if current_scores else False
        has_facial = (current_scores.get("facial") is not None) if current_scores else False
        has_vocal = (current_scores.get("vocal") is not None) if current_scores else False
        has_social = (current_scores.get("social") is not None) if current_scores else False

        modality_availability = {
            "questionnaire": has_questionnaire,
            "facial": has_facial,
            "vocal": has_vocal,
            "social": has_social,
        }
        prediction_mode = "COMPLETE" if all(modality_availability.values()) else "PARTIAL"

        q_score = self._safe_float(current_scores.get("questionnaire") if current_scores else None, 85.0)
        facial_score = self._safe_float(current_scores.get("facial") if current_scores else None, 80.0)
        vocal_score = self._safe_float(current_scores.get("vocal") if current_scores else None, 80.0)
        social_score = self._safe_float(current_scores.get("social") if current_scores else None, 80.0)

        # 1. Multimodal Feature Fusion (Grounded in Sec 3.2 weights)
        fused_wellness = (
            q_score * self.weights["questionnaire"] +
            social_score * self.weights["social"] +
            facial_score * self.weights["facial"] +
            vocal_score * self.weights["vocal"]
        )
        fused_wellness = float(np.clip(fused_wellness, 0.0, 100.0))
        current_risk_score = round(100.0 - fused_wellness, 1)

        # 2. Extract and sanitize historical session scores
        extracted_risk_scores: List[float] = []
        if history_scores and isinstance(history_scores, list):
            for item in history_scores:
                is_explicit_risk = False
                if isinstance(item, dict):
                    if "risk" in item:
                        score_val = item["risk"]
                        is_explicit_risk = True
                    else:
                        score_val = item.get("score", item.get("wellness", 50.0))
                else:
                    score_val = item
                try:
                    f = float(score_val)
                    if not (np.isnan(f) or np.isinf(f)):
                        clamped = float(np.clip(f, 0.0, 100.0))
                        if is_explicit_risk or score_domain == "risk":
                            extracted_risk_scores.append(clamped)
                        else:
                            extracted_risk_scores.append(round(100.0 - clamped, 1))
                except (ValueError, TypeError):
                    continue

        # 3. Insufficient History Guard (Methodology Sec 3.1 & 3.5, FR5)
        # At least 2 completed sessions across distinct timepoints are strictly required
        if len(extracted_risk_scores) < 2:
            return {
                "resident_id": resident_id,
                "current_wellness_index": round(fused_wellness, 1),
                "current_risk_score": current_risk_score,
                "risk_level": "LOW" if current_risk_score < 40 else ("MODERATE" if current_risk_score < 70 else "HIGH"),
                "trajectory": "BASELINE_ESTABLISHING",
                "trajectory_status_label": "Baseline Establishing (Insufficient Longitudinal Data)",
                "prediction_mode": prediction_mode,
                "modality_availability": modality_availability,
                "is_insufficient_history": True,
                "confidence_score": 0.60,
                "baseline_score": current_risk_score,
                "baseline_deviation": 0.0,
                "baseline_deviation_percent": 0.0,
                "longitudinal_slope": 0.0,
                "forecast_14_days": None,
                "forecast_7_days": None,
                "ml_models_evaluation": {
                    "models_loaded": self.models_loaded,
                    "load_error": self.load_error,
                    "evaluation_note": "ML model inference suspended during initial session: resident-specific history < 2 sessions."
                },
                "message": (
                    "Insufficient longitudinal history. Per RALPA specification Sec 3.1, "
                    "at least 2 completed sessions across distinct timepoints are required to compute "
                    "a resident-specific baseline and detect trajectory drift."
                ),
                "contributing_factors": self._calculate_contributing_factors(
                    q_score, facial_score, vocal_score, social_score, 0.0
                ),
                "recommendations": self._generate_recommendations(current_risk_score, "BASELINE_ESTABLISHING"),
                "model_metadata": {
                    "algorithm": "RALPA (Resident-Adaptive Longitudinal Prediction Algorithm)",
                    "high_risk_model_file": os.path.basename(self.high_risk_model_path) if self.high_risk_model_path else None,
                    "trajectory_model_file": os.path.basename(self.trajectory_model_path) if self.trajectory_model_path else None,
                    "specification_reference": "IT23228108.pdf Section 3.1-3.5",
                    "evaluation_state": "Baseline Calibration",
                },
            }

        # 4. Resident-Adaptive Baseline & Slope (RALPA Core Engine)
        history_arr = np.array(extracted_risk_scores, dtype=float)
        personal_baseline = float(np.mean(history_arr))
        deviation = current_risk_score - personal_baseline
        deviation_pct = round((deviation / max(personal_baseline, 1.0)) * 100.0, 1)

        time_steps = np.arange(len(history_arr) + 1)
        extended_series = np.append(history_arr, current_risk_score)
        slope, _ = np.polyfit(time_steps, extended_series, 1)

        # 5. Colab Models Inference (149-feature schema)
        ml_eval = {
            "models_loaded": self.models_loaded,
            "load_error": self.load_error,
            "high_risk_model": None,
            "trajectory_model": None,
        }

        ml_trajectory_class = None
        ml_is_high_risk = None
        ml_high_risk_prob = None

        if self.models_loaded and self.high_risk_artifact and self.trajectory_artifact:
            try:
                features_df = self._build_feature_row(
                    current_scores={
                        "questionnaire": q_score,
                        "facial": facial_score,
                        "vocal": vocal_score,
                        "social": social_score,
                    },
                    extracted_history_scores=extracted_risk_scores,
                    raw_features=raw_features,
                )

                # High-risk model prediction (4 models ensemble)
                h_models = self.high_risk_artifact["models"]
                probas_h = [m.predict_proba(features_df)[:, 1] for m in h_models.values()]
                ml_high_risk_prob = float(np.mean(probas_h))
                ml_is_high_risk = bool(ml_high_risk_prob >= self.high_risk_threshold)

                ml_eval["high_risk_model"] = {
                    "available": True,
                    "ensemble_count": len(h_models),
                    "model_types": [type(m).__name__ for m in h_models.values()],
                    "high_risk_probability": round(ml_high_risk_prob, 4),
                    "alert_threshold": self.high_risk_threshold,
                    "is_high_risk": ml_is_high_risk,
                    "target": "high_risk_label (binary)",
                }

                # Trajectory model prediction (3 models ensemble)
                t_models = self.trajectory_artifact["models"]
                probas_t = [m.predict_proba(features_df) for m in t_models]
                ens_proba_t = np.mean(probas_t, axis=0)[0]
                pred_t_idx = int(np.argmax(ens_proba_t))
                ml_trajectory_class = self.trajectory_classes[pred_t_idx]

                ml_eval["trajectory_model"] = {
                    "available": True,
                    "ensemble_count": len(t_models),
                    "model_types": [type(m).__name__ for m in t_models],
                    "predicted_trajectory": ml_trajectory_class,
                    "class_probabilities": {
                        c: round(float(p), 4) for c, p in zip(self.trajectory_classes, ens_proba_t)
                    },
                    "target": "trajectory_label (deteriorating, improving, stable)",
                }
            except Exception as e:
                logger.error(f"Inference error with Colab models: {e}", exc_info=True)
                ml_eval["inference_error"] = str(e)

        # 6. Harmonize RALPA Physical Slope with Colab Trajectory Classification
        # If ML model predicted deteriorating or RALPA slope indicates sustained deterioration
        if (ml_trajectory_class == "deteriorating") or (slope > 1.2 or deviation > 10.0):
            trajectory = "DETERIORATING"
            trajectory_label = "Deteriorating / Increasing Risk"
            risk_level = "HIGH" if (ml_is_high_risk or current_risk_score >= 60.0) else "MODERATE"
        elif (ml_trajectory_class == "improving") or (slope < -1.2 or deviation < -10.0):
            trajectory = "IMPROVING"
            trajectory_label = "Improving Wellness Trajectory"
            risk_level = "LOW"
        else:
            trajectory = "STABLE"
            trajectory_label = "Stable Within Personal Baseline"
            risk_level = "HIGH" if (ml_is_high_risk and current_risk_score >= 65.0) else ("MODERATE" if current_risk_score >= 45.0 else "LOW")

        # 7. 14-Day Trajectory Projection (and 7-Day for legacy test suite)
        forecast_14_days = [
            round(float(np.clip(current_risk_score + (day * slope * 0.4), 0.0, 100.0)), 1)
            for day in range(1, 15)
        ]
        forecast_7_days = forecast_14_days[:7]

        confidence = 0.95 if self.models_loaded else 0.88

        return {
            "resident_id": resident_id,
            "current_wellness_index": round(fused_wellness, 1),
            "current_risk_score": current_risk_score,
            "risk_level": risk_level,
            "trajectory": trajectory,
            "trajectory_status_label": trajectory_label,
            "prediction_mode": prediction_mode,
            "modality_availability": modality_availability,
            "is_insufficient_history": False,
            "confidence_score": confidence,
            "baseline_score": round(personal_baseline, 1),
            "baseline_deviation": round(deviation, 1),
            "baseline_deviation_percent": deviation_pct,
            "longitudinal_slope": round(float(slope), 2),
            "forecast_14_days": forecast_14_days,
            "forecast_7_days": forecast_7_days,
            "ml_models_evaluation": ml_eval,
            "contributing_factors": self._calculate_contributing_factors(
                q_score, facial_score, vocal_score, social_score, deviation
            ),
            "recommendations": self._generate_recommendations(current_risk_score, trajectory),
            "model_metadata": {
                "algorithm": "RALPA (Resident-Adaptive Longitudinal Prediction Algorithm)",
                "high_risk_model_file": os.path.basename(self.high_risk_model_path) if self.high_risk_model_path else None,
                "trajectory_model_file": os.path.basename(self.trajectory_model_path) if self.trajectory_model_path else None,
                "feature_count_expected": len(self.expected_features),
                "specification_reference": "IT23228108.pdf Section 3.1-3.5",
                "evaluation_state": "Ensemble ML + RALPA Longitudinal Regression",
            },
        }

    def _calculate_contributing_factors(
        self,
        q_score: float,
        facial_score: float,
        vocal_score: float,
        social_score: float,
        baseline_deviation: float,
    ) -> list:
        """
        Explainable indicators combining multimodal observation weights and baseline deviation.
        Aligned with Table 3:1 and Section 3.4 (Feature Importance & Explainability).
        """
        return [
            {
                "title": "Questionnaire Self-Report",
                "category": "Standardized Questionnaire",
                "raw_score": round(q_score, 1),
                "weight_percentage": 40.0,
                "description": "Standardized loneliness and social connection assessment responses.",
            },
            {
                "title": "Social-Behavioral Participation",
                "category": "Behavioral Indicators",
                "raw_score": round(social_score, 1),
                "weight_percentage": 25.0,
                "description": "Interaction frequency, lounge presence, and group activity logs.",
            },
            {
                "title": "Facial Affect Expression",
                "category": "Facial Affect (FER-2013)",
                "raw_score": round(facial_score, 1),
                "weight_percentage": 20.0,
                "description": "PyTorch CNN affective valence and facial composure features.",
            },
            {
                "title": "Vocal Acoustic Modulation",
                "category": "Vocal Prosody",
                "raw_score": round(vocal_score, 1),
                "weight_percentage": 15.0,
                "description": "Speech rate, fundamental frequency variation, and conversational cadence.",
            },
            {
                "title": "Historical Baseline Drift",
                "category": "Longitudinal Deviation (RALPA)",
                "raw_score": round(abs(baseline_deviation), 1),
                "weight_percentage": 0.0,
                "description": f"Resident personal baseline deviation: {baseline_deviation:+.1f} points.",
            },
        ]

    def _generate_recommendations(self, risk_score: float, trajectory: str) -> list:
        """
        Personalized non-diagnostic activity recommendations grounded in
        Section 1.2.1 (Sri Lankan elderly coping mechanisms; Wijesiri et al., 2019) and Section 4.1.
        """
        is_elevated = (risk_score >= 60.0) or (trajectory == "DETERIORATING")
        return [
            {
                "category": "Music Therapy",
                "title": "Soothing Classical & Traditional Chants",
                "rationale": "Acoustic rhythm stabilization supports positive affect and reduces vocal agitation.",
                "priority": "High" if is_elevated else "Recommended",
            },
            {
                "category": "Reading & Literature",
                "title": "Illustrated Historical Narratives",
                "rationale": "Provides comfortable personal engagement and prompts conversational recall.",
                "priority": "Medium",
            },
            {
                "category": "Religious / Cultural",
                "title": "Spiritual Reflection & Chanting",
                "rationale": "Grounded in Sri Lankan care home coping mechanisms (Wijesiri et al., 2019).",
                "priority": "Essential" if is_elevated else "Recommended",
            },
            {
                "category": "Social Interaction",
                "title": "Peer Carrom & Tea Time Connection",
                "rationale": "Facilitated small-group engagement to rebuild voluntary interaction rhythm.",
                "priority": "High" if is_elevated else "Recommended",
            },
        ]


if __name__ == "__main__":
    import json

    print("==================================================")
    print("Initializing RALPA Engine...")
    print("==================================================")
    engine = RALPAEngine()

    print(f"Models loaded: {engine.models_loaded}")
    if engine.load_error:
        print(f"Load error: {engine.load_error}")

    print("\nRunning sample prediction test:")
    sample_scores = {
        "questionnaire": 82.0,
        "facial": 78.0,
        "vocal": 75.0,
        "social": 80.0,
    }
    sample_history = [70.0, 75.0, 78.0]
    result = engine.predict_progression(
        resident_id=1,
        current_scores=sample_scores,
        history_scores=sample_history,
    )

    print(f"Current Wellness Index : {result.get('current_wellness_index')}")
    print(f"Current Risk Score     : {result.get('current_risk_score')}")
    print(f"Risk Level             : {result.get('risk_level')}")
    print(f"Trajectory             : {result.get('trajectory')} ({result.get('trajectory_status_label')})")
    print(f"Baseline Score         : {result.get('baseline_score')}")
    print(f"Baseline Deviation     : {result.get('baseline_deviation')}")
    print(f"Longitudinal Slope     : {result.get('longitudinal_slope')}")
    print(f"14-Day Forecast        : {result.get('forecast_14_days')}")

    ml_eval = result.get("ml_models_evaluation", {})
    if ml_eval.get("high_risk_model"):
        print(f"High-Risk Model Prob   : {ml_eval['high_risk_model'].get('high_risk_probability')}")
    if ml_eval.get("trajectory_model"):
        print(f"Trajectory Model Pred  : {ml_eval['trajectory_model'].get('predicted_trajectory')}")

    print("==================================================")
    print("RALPA Engine run successfully!")
    print("==================================================")
