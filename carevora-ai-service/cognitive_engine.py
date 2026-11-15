"""
Cognitive Wellness Scoring Engine (ACRF Fixed Weights & Trained Random Forest Artifact)
Part of CAREVORA AI/ML Intelligence Microservice.

Methodology & Architecture:
1. ACRF Linear Wellness Metric:
   - Fixed base weights across five designated categories:
       * Memory: 0.25
       * Attention: 0.20
       * Orientation: 0.20
       * Recall: 0.20
       * Reasoning: 0.15
     Sum of weights = 1.00.
   - Normalized continuous 0.0 - 100.0 scale where higher scores indicate higher wellness/accuracy.
   - Non-diagnostic baseline wellness metric for longitudinal tracking.

2. Trained Random Forest Classifier:
   - Artifact: carevora-ai-service/models/carevora_cognitive_model.joblib
   - Pipeline: SimpleImputer -> StandardScaler -> RandomForestClassifier
   - Input: 31 ordered features:
       * 2 Demographics: age, education_years
       * 5 Domain Scores: memory_score, attention_score, orientation_score, recall_score, reasoning_score
       * 5 Domain Accuracies: memory_accuracy, attention_accuracy, orientation_accuracy, recall_accuracy, reasoning_accuracy
       * 5 Domain Response Times: memory_response_time, attention_response_time, orientation_response_time, recall_response_time, reasoning_response_time
       * 14 ACRF Engineered Features: acrf_base_*, acrf_change_*, acrf_level, acrf_change, acrf_n_declining, acrf_weakest_domain
   - Target Classes: ['Low', 'Moderate', 'High']
   - Alert Threshold: 0.48 (flags High-risk progression probability)
   - Experimental Notice: This model was trained on synthetic data for research and proof-of-concept
     demonstration. It is NOT clinically validated and makes no medical claims.
   - Zero-Fabrication Guarantee: Features are never synthesized or hallucinated. If complete inputs
     are absent, the model explicitly returns unavailable status while preserving the ACRF score.
"""

import os
import math
import warnings
from typing import Dict, Any, List, Optional
import pandas as pd
import joblib

# Required for unpickling the fitted ACRF transformer inside the artifact
import carevora_acrf

ACRF_BASE_WEIGHTS: Dict[str, float] = {
    "memory": 0.25,
    "attention": 0.20,
    "orientation": 0.20,
    "recall": 0.20,
    "reasoning": 0.15,
}

REQUIRED_CATEGORIES = list(ACRF_BASE_WEIGHTS.keys())

DEFAULT_MODEL_PATH = os.path.join(
    os.path.dirname(__file__), "models", "carevora_cognitive_model.joblib"
)


class CognitiveValidationError(ValueError):
    """Raised when category scores or required task metrics fail validation constraints."""
    pass


def validate_score_value(val: Any, category_name: str) -> float:
    """
    Validates that a category score is a finite real number within [0.0, 100.0].
    Explicitly rejects None, booleans, strings, NaN, infinity, and out-of-range values.
    """
    if val is None:
        raise CognitiveValidationError(
            f"Score for category '{category_name}' is required and cannot be null/None."
        )

    if isinstance(val, bool):
        raise CognitiveValidationError(
            f"Score for category '{category_name}' must be a numeric value, not a boolean."
        )

    try:
        f_val = float(val)
    except (TypeError, ValueError) as exc:
        raise CognitiveValidationError(
            f"Score for category '{category_name}' must be a numeric float or int, received: {val!r}"
        ) from exc

    if math.isnan(f_val):
        raise CognitiveValidationError(
            f"Score for category '{category_name}' cannot be NaN (Not a Number)."
        )

    if math.isinf(f_val):
        raise CognitiveValidationError(
            f"Score for category '{category_name}' cannot be infinite (inf or -inf)."
        )

    if f_val < 0.0 or f_val > 100.0:
        raise CognitiveValidationError(
            f"Score for category '{category_name}' must be within [0.0, 100.0]. Received: {f_val}"
        )

    return f_val


class CognitiveEngine:
    """
    Cognitive wellness scoring engine providing:
    1. Fixed ACRF weighted wellness scoring (memory: 0.25, attention: 0.20, orientation: 0.20, recall: 0.20, reasoning: 0.15).
    2. Trained Random Forest model evaluation using verified joblib artifact.
    """

    def __init__(
        self,
        model_path: Optional[str] = None,
        weights: Optional[Dict[str, float]] = None,
    ):
        self.weights = weights or dict(ACRF_BASE_WEIGHTS)
        weight_sum = sum(self.weights.values())
        if not math.isclose(weight_sum, 1.0, rel_tol=1e-5):
            raise ValueError(f"ACRF base weights must sum to 1.00, got: {weight_sum}")

        self.model_path = model_path or DEFAULT_MODEL_PATH
        self.model_pipeline = None
        self.acrf_transformer = None
        self.expected_features: List[str] = []
        self.labels: List[str] = []
        self.alert_threshold: float = 0.48
        self.model_name: str = "Random Forest"
        self.feature_set: str = "B: raw + ACRF"
        self.model_loaded: bool = False
        self.load_error: Optional[str] = None

        self._load_model_artifact()

    def _load_model_artifact(self) -> None:
        """Loads and verifies the saved Random Forest joblib artifact."""
        if not os.path.exists(self.model_path):
            self.model_loaded = False
            self.load_error = f"Model artifact file not found at: {self.model_path}"
            return

        try:
            artifact = joblib.load(self.model_path)
            self.model_pipeline = artifact["model"]
            self.acrf_transformer = artifact["acrf"]
            self.expected_features = list(artifact["features"])
            self.labels = list(artifact["labels"])
            self.alert_threshold = float(artifact.get("alert_threshold", 0.48))
            self.model_name = str(artifact.get("model_name", "Random Forest"))
            self.feature_set = str(artifact.get("feature_set", "B: raw + ACRF"))

            # Ensure pipeline SimpleImputer compatibility across scikit-learn versions
            self._patch_imputer(self.model_pipeline)

            self.model_loaded = True
            self.load_error = None
        except Exception as exc:
            self.model_loaded = False
            self.load_error = f"Failed to load model artifact: {exc}"

    @staticmethod
    def _patch_imputer(est: Any) -> None:
        """Compatibility fix: adds missing _fill_dtype to SimpleImputer instances."""
        from sklearn.impute import SimpleImputer
        from sklearn.pipeline import Pipeline
        if isinstance(est, Pipeline):
            for _, step in est.steps:
                CognitiveEngine._patch_imputer(step)
        elif isinstance(est, SimpleImputer):
            if not hasattr(est, "_fill_dtype"):
                est._fill_dtype = getattr(est, "_fit_dtype", None)

    def validate_scores(self, raw_scores: Dict[str, Any]) -> Dict[str, float]:
        """
        Validates the five required categories (memory, attention, orientation, recall, reasoning).
        Rejects missing keys and malformed values.
        """
        if not isinstance(raw_scores, dict):
            raise CognitiveValidationError(
                f"Expected scores dictionary, received: {type(raw_scores).__name__}"
            )

        validated: Dict[str, float] = {}
        missing_categories = [cat for cat in REQUIRED_CATEGORIES if cat not in raw_scores]
        if missing_categories:
            raise CognitiveValidationError(
                f"Missing required cognitive categories: {', '.join(missing_categories)}. "
                f"Required categories are: {', '.join(REQUIRED_CATEGORIES)}"
            )

        for cat in REQUIRED_CATEGORIES:
            validated[cat] = validate_score_value(raw_scores[cat], cat)

        return validated

    def calculate_acrf_score(self, validated_scores: Dict[str, float]) -> Dict[str, Any]:
        """
        Calculates the ACRF weighted score and individual category contributions.
        Returns rounded figures with full floating-point precision details.
        """
        contributions: List[Dict[str, Any]] = []
        total_weighted_score = 0.0

        for cat in REQUIRED_CATEGORIES:
            score = validated_scores[cat]
            weight = self.weights[cat]
            contribution = score * weight
            total_weighted_score += contribution

            contributions.append({
                "category": cat,
                "score": round(score, 2),
                "weight": weight,
                "contribution": round(contribution, 4),
                "weight_percentage": f"{int(weight * 100)}%"
            })

        rounded_score = round(total_weighted_score, 2)

        return {
            "acrf_score": rounded_score,
            "raw_weighted_score": total_weighted_score,
            "scale": "0-100",
            "scoring_direction": "Higher score indicates higher observed cognitive wellness / task accuracy",
            "weights_applied": dict(self.weights),
            "category_scores": {k: round(v, 2) for k, v in validated_scores.items()},
            "category_contributions": contributions,
            "methodology": "ACRF Fixed Base Weights (Non-Diagnostic Wellness Metric)",
            "clinical_disclaimer": (
                "The ACRF score is an arithmetic weighted wellness metric based on administered assessment tasks. "
                "It is not a clinical diagnosis, cognitive impairment screen, or medical prediction."
            )
        }

    def evaluate_ml_model(
        self,
        validated_scores: Dict[str, float],
        resident_id: Optional[int] = None,
        age: Optional[float] = None,
        education_years: Optional[float] = None,
        accuracies: Optional[Dict[str, float]] = None,
        response_times: Optional[Dict[str, float]] = None,
        assessment_number: Optional[int] = None,
        history: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        """
        Performs Random Forest model inference using the trained artifact.
        
        Zero-Fabrication Contract:
        If any of the 31 required features (age, education_years, domain accuracies,
        or domain response times) are missing or invalid, model inference is declined
        and an explicit status is returned. No values are synthesized or assumed.
        """
        if not self.model_loaded:
            return {
                "available": False,
                "model_type": "RandomForestClassifier",
                "status_message": f"Random Forest model is unavailable: {self.load_error or 'artifact not loaded'}.",
                "prediction": None,
                "probabilities": None,
                "missing_features": list(self.expected_features),
                "feature_count_expected": len(self.expected_features),
                "experimental_label": "Synthetic Data Experiment (Non-Clinical)"
            }

        # Check for missing demographic and task metrics
        missing_features: List[str] = []

        if age is None:
            missing_features.append("age")
        elif not isinstance(age, (int, float)) or math.isnan(age) or math.isinf(age) or age <= 0 or age > 130:
            missing_features.append("age (invalid: must be positive number <= 130)")

        if education_years is None:
            missing_features.append("education_years")
        elif not isinstance(education_years, (int, float)) or math.isnan(education_years) or math.isinf(education_years) or education_years < 0 or education_years > 40:
            missing_features.append("education_years (invalid: must be number between 0 and 40)")

        # Validate domain accuracies
        if accuracies is None or not isinstance(accuracies, dict):
            for cat in REQUIRED_CATEGORIES:
                missing_features.append(f"{cat}_accuracy")
        else:
            for cat in REQUIRED_CATEGORIES:
                val = accuracies.get(cat)
                if val is None:
                    missing_features.append(f"{cat}_accuracy")
                elif not isinstance(val, (int, float)) or math.isnan(val) or math.isinf(val) or val < 0.0 or val > 100.0:
                    missing_features.append(f"{cat}_accuracy (invalid: must be in [0.0, 1.0] or [0.0, 100.0])")

        # Validate domain response times
        if response_times is None or not isinstance(response_times, dict):
            for cat in REQUIRED_CATEGORIES:
                missing_features.append(f"{cat}_response_time")
        else:
            for cat in REQUIRED_CATEGORIES:
                val = response_times.get(cat)
                if val is None:
                    missing_features.append(f"{cat}_response_time")
                elif not isinstance(val, (int, float)) or math.isnan(val) or math.isinf(val) or val <= 0.0:
                    missing_features.append(f"{cat}_response_time (invalid: must be > 0.0 seconds)")

        if missing_features:
            return {
                "available": False,
                "model_type": "RandomForestClassifier",
                "status_message": (
                    "Random Forest model inference is unavailable because required task features were not provided. "
                    f"Missing features: {', '.join(missing_features)}. "
                    "Predictions are never fabricated when inputs are incomplete. Baseline ACRF score calculated successfully."
                ),
                "prediction": None,
                "probabilities": None,
                "missing_features": missing_features,
                "feature_count_expected": len(self.expected_features),
                "experimental_label": "Synthetic Data Experiment (Non-Clinical)"
            }

        # Normalize accuracies: if supplied on 0-100 scale, map to 0-1 proportion to match training scaler
        norm_accuracies: Dict[str, float] = {}
        for cat in REQUIRED_CATEGORIES:
            raw_acc = float(accuracies[cat])
            norm_accuracies[cat] = raw_acc / 100.0 if raw_acc > 1.0 else raw_acc

        norm_rt: Dict[str, float] = {cat: float(response_times[cat]) for cat in REQUIRED_CATEGORIES}
        r_id = resident_id if resident_id is not None else 1
        curr_seq = assessment_number if assessment_number is not None else 1

        try:
            # Build DataFrame for ACRF transformer (handles optional longitudinal history)
            acrf_input_rows: List[Dict[str, Any]] = []

            if history and isinstance(history, list):
                for idx, past in enumerate(history):
                    h_seq = past.get("assessment_number", idx + 1)
                    h_row: Dict[str, Any] = {
                        "resident_id": past.get("resident_id", r_id),
                        "assessment_number": h_seq,
                    }
                    for cat in REQUIRED_CATEGORIES:
                        h_row[f"{cat}_score"] = float(past.get(f"{cat}_score", past.get(cat, validated_scores[cat])))
                        h_row[f"{cat}_response_time"] = float(past.get(f"{cat}_response_time", norm_rt[cat]))
                    acrf_input_rows.append(h_row)

                if curr_seq <= max(r["assessment_number"] for r in acrf_input_rows):
                    curr_seq = max(r["assessment_number"] for r in acrf_input_rows) + 1

            current_acrf_input = {
                "resident_id": r_id,
                "assessment_number": curr_seq,
            }
            for cat in REQUIRED_CATEGORIES:
                current_acrf_input[f"{cat}_score"] = validated_scores[cat]
                current_acrf_input[f"{cat}_response_time"] = norm_rt[cat]
            acrf_input_rows.append(current_acrf_input)

            acrf_df = pd.DataFrame(acrf_input_rows)
            acrf_features_df = self.acrf_transformer.transform(acrf_df)
            current_acrf_features = acrf_features_df.iloc[-1]

            # Assemble full 31 feature vector in exact model schema
            feature_row: Dict[str, Any] = {
                "age": float(age),
                "education_years": float(education_years),
                "memory_score": validated_scores["memory"],
                "attention_score": validated_scores["attention"],
                "orientation_score": validated_scores["orientation"],
                "recall_score": validated_scores["recall"],
                "reasoning_score": validated_scores["reasoning"],
                "memory_accuracy": norm_accuracies["memory"],
                "attention_accuracy": norm_accuracies["attention"],
                "orientation_accuracy": norm_accuracies["orientation"],
                "recall_accuracy": norm_accuracies["recall"],
                "reasoning_accuracy": norm_accuracies["reasoning"],
                "memory_response_time": norm_rt["memory"],
                "attention_response_time": norm_rt["attention"],
                "orientation_response_time": norm_rt["orientation"],
                "recall_response_time": norm_rt["recall"],
                "reasoning_response_time": norm_rt["reasoning"],
            }

            for col in acrf_features_df.columns:
                feature_row[col] = current_acrf_features[col]

            X = pd.DataFrame([feature_row])[self.expected_features]

            pred_idx = int(self.model_pipeline.predict(X)[0])
            pred_label = self.labels[pred_idx]
            probabilities_arr = self.model_pipeline.predict_proba(X)[0]
            probabilities_dict = {
                self.labels[i]: round(float(probabilities_arr[i]), 4)
                for i in range(len(self.labels))
            }

            high_prob = probabilities_dict.get("High", 0.0)
            alert_triggered = bool(high_prob >= self.alert_threshold)

            return {
                "available": True,
                "model_type": "RandomForestClassifier",
                "status_message": (
                    "Experimental prediction generated using artifact trained on synthetic data. "
                    "Non-clinical demonstration metric."
                ),
                "prediction": pred_label,
                "probabilities": probabilities_dict,
                "alert_threshold": self.alert_threshold,
                "alert_triggered": alert_triggered,
                "feature_set": self.feature_set,
                "missing_features": [],
                "feature_count_expected": len(self.expected_features),
                "experimental_label": "Synthetic Data Experiment (Non-Clinical)",
                "disclaimer": (
                    "This model was experimentally trained on synthetic data for research and "
                    "demonstration purposes only. It is not clinically validated."
                )
            }
        except Exception as exc:
            return {
                "available": False,
                "model_type": "RandomForestClassifier",
                "status_message": f"Feature preparation or model inference error: {exc}",
                "prediction": None,
                "probabilities": None,
                "missing_features": [],
                "feature_count_expected": len(self.expected_features),
                "experimental_label": "Synthetic Data Experiment (Non-Clinical)"
            }

    def evaluate(
        self,
        raw_scores: Dict[str, Any],
        resident_id: Optional[int] = None,
        age: Optional[float] = None,
        education_years: Optional[float] = None,
        accuracies: Optional[Dict[str, float]] = None,
        response_times: Optional[Dict[str, float]] = None,
        assessment_number: Optional[int] = None,
        history: Optional[List[Dict[str, Any]]] = None,
    ) -> Dict[str, Any]:
        """
        Complete cognitive assessment evaluation:
        1. Validates category scores.
        2. Computes ACRF weighted score and category breakdowns using fixed weights.
        3. Executes Random Forest model evaluation using verified artifact if inputs are complete.
        """
        validated_scores = self.validate_scores(raw_scores)
        acrf_result = self.calculate_acrf_score(validated_scores)
        ml_status = self.evaluate_ml_model(
            validated_scores=validated_scores,
            resident_id=resident_id,
            age=age,
            education_years=education_years,
            accuracies=accuracies,
            response_times=response_times,
            assessment_number=assessment_number,
            history=history,
        )

        return {
            "resident_id": resident_id,
            "acrf_assessment": acrf_result,
            "ml_model_evaluation": ml_status
        }
