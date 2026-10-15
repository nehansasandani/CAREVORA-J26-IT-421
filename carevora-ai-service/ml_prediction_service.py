import os
import sys
import numpy as np
import pandas as pd
import joblib
from typing import Dict, List, Any, Optional, Tuple

# Base 19 features established during training
BASE_COLUMNS = [
    'visit_month',
    'facial_happy_prob',
    'facial_sad_prob',
    'facial_neutral_prob',
    'vocal_positive_score',
    'vocal_stress_score',
    'vocal_energy_score',
    'speech_rate_words_per_sec',
    'response_latency_sec',
    'questionnaire_loneliness_score_0_10',
    'emotional_wellness_score_0_10',
    'social_isolation_score_0_10',
    'family_contacts_per_week',
    'social_interactions_per_week',
    'activity_participation_score_0_10',
    'conversation_minutes_per_assessment',
    'social_baseline_deviation',
    'positive_emotion_baseline_deviation',
    'wellness_baseline_deviation'
]

CORE_COLUMNS = [c for c in BASE_COLUMNS if c != 'visit_month']

class CarevoraMLPredictionService:
    """
    Dedicated ML prediction service loading and executing the Colab-trained
    Carevora machine learning models:
    1. High-Risk Binary Ensemble Classifier (LGBM, LR, HGB) with calibrated threshold 0.31
    2. Trajectory Multiclass Ensemble Classifier (LGBM, LR) for ['deteriorating', 'improving', 'stable']
    """

    def __init__(self, models_dir: Optional[str] = None):
        if models_dir is None:
            models_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "models")
        self.models_dir = models_dir

        self.high_risk_path = os.path.join(self.models_dir, "carevora_high_risk_model.joblib")
        self.trajectory_path = os.path.join(self.models_dir, "carevora_trajectory_model.joblib")

        self.high_risk_artifact: Optional[Dict[str, Any]] = None
        self.trajectory_artifact: Optional[Dict[str, Any]] = None

        self._load_models()

    def _load_models(self):
        if not os.path.exists(self.high_risk_path):
            raise FileNotFoundError(f"High risk model artifact not found at: {self.high_risk_path}")
        if not os.path.exists(self.trajectory_path):
            raise FileNotFoundError(f"Trajectory model artifact not found at: {self.trajectory_path}")

        try:
            self.high_risk_artifact = joblib.load(self.high_risk_path)
            self.trajectory_artifact = joblib.load(self.trajectory_path)
        except Exception as e:
            raise RuntimeError(f"Failed loading joblib models: {e}")

        # Validate loaded structure
        assert 'models' in self.high_risk_artifact, "Missing 'models' in high_risk artifact"
        assert 'features' in self.high_risk_artifact, "Missing 'features' in high_risk artifact"
        assert 'threshold' in self.high_risk_artifact, "Missing 'threshold' in high_risk artifact"

        assert 'models' in self.trajectory_artifact, "Missing 'models' in trajectory artifact"
        assert 'features' in self.trajectory_artifact, "Missing 'features' in trajectory artifact"
        assert 'classes' in self.trajectory_artifact, "Missing 'classes' in trajectory artifact"

    @property
    def high_risk_threshold(self) -> float:
        return float(self.high_risk_artifact['threshold'])

    @property
    def expected_features(self) -> List[str]:
        return list(self.high_risk_artifact['features'])

    @property
    def trajectory_classes(self) -> List[str]:
        return list(self.trajectory_artifact['classes'])

    def transform_longitudinal_records(self, session_rows: List[Dict[str, Any]]) -> pd.DataFrame:
        """
        Takes chronological session records for a single resident, applies the exact
        training feature engineering (lags, expanding mean/std, rolling-3, deltas,
        and composite indices) and returns the full feature-engineered DataFrame.
        """
        if not session_rows:
            raise ValueError("No session records provided for feature transformation")

        df = pd.DataFrame(session_rows).copy()
        
        # Ensure all 19 BASE_COLUMNS exist
        for col in BASE_COLUMNS:
            if col not in df.columns:
                df[col] = np.nan

        # Sort chronologically by visit_month
        df = df.sort_values('visit_month').reset_index(drop=True)

        new_features = {}
        for c in CORE_COLUMNS:
            series = df[c]
            new_features[c + '_lag1'] = series.shift(1)
            new_features[c + '_lag2'] = series.shift(2)
            new_features[c + '_expmean'] = series.expanding().mean().shift(1)
            new_features[c + '_expstd'] = series.expanding().std().shift(1)
            new_features[c + '_roll3'] = series.rolling(3, min_periods=1).mean()
            new_features[c + '_vs_hist'] = series - new_features[c + '_expmean']
            new_features[c + '_delta1'] = series - new_features[c + '_lag1']

        derived_df = pd.DataFrame(new_features, index=df.index)
        full_df = pd.concat([df, derived_df], axis=1)

        # Composite indicators exactly matching Colab training script
        full_df['neg_affect'] = (
            full_df['facial_sad_prob'] + full_df['vocal_stress_score'] -
            full_df['facial_happy_prob'] - full_df['vocal_positive_score']
        )
        full_df['social_deficit'] = (
            full_df['questionnaire_loneliness_score_0_10'] +
            full_df['social_isolation_score_0_10'] -
            full_df['activity_participation_score_0_10']
        )
        full_df['wellness_gap'] = (
            full_df['questionnaire_loneliness_score_0_10'] -
            full_df['emotional_wellness_score_0_10']
        )
        full_df['contact_total'] = (
            full_df['family_contacts_per_week'] +
            full_df['social_interactions_per_week']
        )

        return full_df

    def build_feature_vector_from_assessment(
        self,
        resident_id: int,
        questionnaire_score: float,
        social_score: float,
        vocal_score: Optional[float] = None,
        history_scores: Optional[List[float]] = None
    ) -> pd.DataFrame:
        """
        Constructs the feature vector from an API assessment call.
        Converts available scores to domain metrics, constructs longitudinal visits,
        and leaves unobserved modalities (e.g. decommissioned facial model) as NaN.
        """
        history = list(history_scores) if history_scores else []
        sessions = []

        # Reconstruct prior visits if history scores exist
        for idx, h_score in enumerate(history):
            h_val = float(h_score)
            h_wellness_10 = float(np.clip(h_val / 10.0, 0.0, 10.0))
            h_loneliness_10 = round(10.0 - h_wellness_10, 2)
            sessions.append({
                'visit_month': idx + 1,
                'facial_happy_prob': np.nan, # Facial model retired; unobserved
                'facial_sad_prob': np.nan,
                'facial_neutral_prob': np.nan,
                'vocal_positive_score': np.nan,
                'vocal_stress_score': np.nan,
                'vocal_energy_score': np.nan,
                'speech_rate_words_per_sec': np.nan,
                'response_latency_sec': np.nan,
                'questionnaire_loneliness_score_0_10': h_loneliness_10,
                'emotional_wellness_score_0_10': h_wellness_10,
                'social_isolation_score_0_10': h_loneliness_10,
                'family_contacts_per_week': np.nan,
                'social_interactions_per_week': np.nan,
                'activity_participation_score_0_10': h_wellness_10,
                'conversation_minutes_per_assessment': np.nan,
                'social_baseline_deviation': 0.0,
                'positive_emotion_baseline_deviation': 0.0,
                'wellness_baseline_deviation': 0.0
            })

        # Current visit
        cur_q_10 = float(np.clip(questionnaire_score / 10.0, 0.0, 10.0))
        cur_loneliness_10 = round(10.0 - cur_q_10, 2)
        cur_s_10 = float(np.clip(social_score / 10.0, 0.0, 10.0)) if social_score is not None else 8.0
        cur_isolation_10 = round(10.0 - cur_s_10, 2)

        v_pos = (float(np.clip(vocal_score / 100.0, 0.0, 1.0))) if vocal_score is not None else np.nan
        v_stress = round(1.0 - v_pos, 2) if v_pos is not np.nan else np.nan

        current_month = len(history) + 1
        
        # Calculate baseline deviations if history is available
        if history:
            mean_hist_wellness = float(np.mean(history)) / 10.0
            wellness_dev = round(cur_q_10 - mean_hist_wellness, 2)
        else:
            wellness_dev = 0.0

        sessions.append({
            'visit_month': current_month,
            'facial_happy_prob': np.nan, # Facial model retired
            'facial_sad_prob': np.nan,
            'facial_neutral_prob': np.nan,
            'vocal_positive_score': v_pos,
            'vocal_stress_score': v_stress,
            'vocal_energy_score': np.nan,
            'speech_rate_words_per_sec': np.nan,
            'response_latency_sec': np.nan,
            'questionnaire_loneliness_score_0_10': cur_loneliness_10,
            'emotional_wellness_score_0_10': cur_q_10,
            'social_isolation_score_0_10': cur_isolation_10,
            'family_contacts_per_week': np.nan,
            'social_interactions_per_week': np.nan,
            'activity_participation_score_0_10': cur_s_10,
            'conversation_minutes_per_assessment': np.nan,
            'social_baseline_deviation': 0.0,
            'positive_emotion_baseline_deviation': 0.0,
            'wellness_baseline_deviation': wellness_dev
        })

        full_transformed = self.transform_longitudinal_records(sessions)
        
        # Select the latest visit row, aligned with expected 149 features
        current_row = full_transformed.iloc[[-1]][self.expected_features]
        return current_row

    def predict_high_risk(self, feature_df: pd.DataFrame) -> Dict[str, Any]:
        """
        Executes the high-risk ensemble (LGBM, LGBM2, LogisticRegression, HistGradientBoosting)
        and applies the saved optimal decision threshold.
        """
        if feature_df.shape[1] != len(self.expected_features):
            raise ValueError(f"Expected {len(self.expected_features)} features, got {feature_df.shape[1]}")

        model_probas = {}
        models_dict = self.high_risk_artifact['models']
        for name, model in models_dict.items():
            prob = model.predict_proba(feature_df)[:, 1][0]
            model_probas[name] = round(float(prob), 4)

        ensemble_prob = float(np.mean(list(model_probas.values())))
        threshold = self.high_risk_threshold
        is_high_risk = bool(ensemble_prob >= threshold)

        return {
            "is_high_risk": is_high_risk,
            "high_risk_label": 1 if is_high_risk else 0,
            "high_risk_probability": round(ensemble_prob, 4),
            "threshold_used": round(threshold, 4),
            "classification_status": "HIGH_RISK" if is_high_risk else "NOT_HIGH_RISK",
            "model_breakdown_probabilities": model_probas,
            "evaluation_disclaimer": "Experimental decision-support classifier trained on longitudinal indicators."
        }

    def predict_trajectory_class(self, feature_df: pd.DataFrame) -> Dict[str, Any]:
        """
        Executes the trajectory ensemble (LGBM, LGBM2, LogisticRegression)
        and outputs class probabilities for ['deteriorating', 'improving', 'stable'].
        """
        if feature_df.shape[1] != len(self.expected_features):
            raise ValueError(f"Expected {len(self.expected_features)} features, got {feature_df.shape[1]}")

        models_list = self.trajectory_artifact['models']
        classes = self.trajectory_classes

        probas_list = []
        for model in models_list:
            p = model.predict_proba(feature_df)[0]
            probas_list.append(p)

        ensemble_proba = np.mean(probas_list, axis=0)
        best_idx = int(np.argmax(ensemble_proba))
        predicted_class = classes[best_idx]

        class_probabilities = {
            classes[i]: round(float(ensemble_proba[i]), 4)
            for i in range(len(classes))
        }

        return {
            "predicted_trajectory_class": predicted_class,
            "confidence_score": round(float(ensemble_proba[best_idx]), 4),
            "class_probabilities": class_probabilities,
            "available_classes": classes,
            "evaluation_disclaimer": "Multiclass longitudinal trend classification from Colab-trained model ensemble."
        }

    def predict_all(self, feature_df: pd.DataFrame) -> Dict[str, Any]:
        """
        Executes both high-risk and trajectory classifiers on the given feature DataFrame.
        """
        return {
            "high_risk_prediction": self.predict_high_risk(feature_df),
            "trajectory_class_prediction": self.predict_trajectory_class(feature_df)
        }
