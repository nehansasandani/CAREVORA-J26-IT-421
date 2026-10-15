import numpy as np
from typing import Optional, List, Dict, Any

class RALPAEngine:
    """
    RALPA: Resident-Adaptive Longitudinal Prediction Algorithm
    Component: J26-IT-421 (Carevora Emotional Wellness)
    Specification: IT23228108.pdf (Methodology Sec 3.1 - 3.5, FR5 - FR8)

    Non-diagnostic predictive progression engine that:
    1. Establishes a resident-specific emotional & behavioral baseline from longitudinal observations.
    2. Quantifies baseline deviation between new observations and historical normal pattern.
    3. Analyzes temporal trends to distinguish transient fluctuation from sustained deterioration.
    4. Projects 14-day loneliness and social-isolation risk trajectories.
    5. Discloses feature contributions and flags insufficient historical data safely.
    """

    def __init__(self):
        # Multimodal fusion weights grounded in Sec 3.2:
        # Questionnaire (40%), Social-Behavioral (25%), Facial Affect (20%), Vocal Prosody (15%)
        self.weights = {
            'questionnaire': 0.40,
            'social': 0.25,
            'facial': 0.20,
            'vocal': 0.15
        }

    def predict_progression(
        self,
        resident_id: int,
        current_scores: dict,
        history_scores: list = None,
        score_domain: str = "wellness"
    ) -> dict:
        def _safe_float(val, default=80.0):
            if val is None:
                return default
            try:
                f = float(val)
                if np.isnan(f) or np.isinf(f):
                    return default
                return float(np.clip(f, 0.0, 100.0))
            except (ValueError, TypeError):
                return default

        q_score = _safe_float(
            current_scores.get('questionnaire', current_scores.get('questionnaire_score'))
            if current_scores else None, 85.0
        )
        facial_score = _safe_float(
            current_scores.get('facial', current_scores.get('facial_score'))
            if current_scores else None, 85.0
        )
        vocal_score = _safe_float(
            current_scores.get('vocal', current_scores.get('vocal_score'))
            if current_scores else None, 80.0
        )
        social_score = _safe_float(
            current_scores.get('social', current_scores.get('social_score'))
            if current_scores else None, 80.0
        )

        # 1. Multimodal Feature Fusion
        fused_wellness = (
            q_score * self.weights['questionnaire'] +
            social_score * self.weights['social'] +
            facial_score * self.weights['facial'] +
            vocal_score * self.weights['vocal']
        )
        fused_wellness = float(np.clip(fused_wellness, 0.0, 100.0))

        # Invert wellness index to derive Loneliness & Isolation Risk (0 = Low risk, 100 = High risk)
        current_risk_score = round(100.0 - fused_wellness, 1)

        # 2. Extract and sanitize historical session scores
        # In Carevora, historical assessments record overall wellness scores (0-100, where 100 is best).
        # To compute baseline drift against loneliness & isolation risk, wellness scores are mapped to risk (100 - wellness).
        extracted_risk_scores = []
        if history_scores and isinstance(history_scores, list):
            for item in history_scores:
                is_explicit_risk = False
                if isinstance(item, dict):
                    if 'risk' in item:
                        score_val = item['risk']
                        is_explicit_risk = True
                    else:
                        score_val = item.get('score', item.get('wellness', 50.0))
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

        # Require at least 2 distinct historical sessions to compute a valid personal baseline
        if len(extracted_risk_scores) < 2:
            return {
                "resident_id": resident_id,
                "current_wellness_index": round(fused_wellness, 1),
                "current_risk_score": current_risk_score,
                "risk_level": "LOW" if current_risk_score < 40 else ("MODERATE" if current_risk_score < 70 else "HIGH"),
                "trajectory": "BASELINE_ESTABLISHING",
                "trajectory_status_label": "Baseline Establishing (Insufficient Longitudinal Data)",
                "is_insufficient_history": True,
                "confidence_score": 0.60,
                "baseline_score": current_risk_score,
                "baseline_deviation": 0.0,
                "baseline_deviation_percent": 0.0,
                "longitudinal_slope": None,
                "forecast_14_days": None,
                "message": (
                    "Insufficient longitudinal history. Per RALPA specification Sec 3.1, "
                    "at least 2 completed sessions across distinct timepoints are required to compute "
                    "a resident-specific baseline and detect trajectory drift."
                ),
                "contributing_factors": self._calculate_contributing_factors(q_score, facial_score, vocal_score, social_score),
                "recommendations": self._generate_recommendations(current_risk_score),
                "model_metadata": {
                    "algorithm": "RALPA (Resident-Adaptive Longitudinal Prediction Algorithm)",
                    "specification_reference": "IT23228108.pdf Section 3.1-3.5",
                    "evaluation_state": "Baseline Calibration"
                }
            }

        # 3. Resident-Adaptive Baseline & Trend Calculation
        history_arr = np.array(extracted_risk_scores, dtype=float)
        personal_baseline = float(np.mean(history_arr))
        deviation = current_risk_score - personal_baseline
        deviation_pct = round((deviation / max(personal_baseline, 1.0)) * 100.0, 1)

        # Distinguish short-term noise from sustained drift via linear slope
        time_steps = np.arange(len(history_arr) + 1)
        extended_series = np.append(history_arr, current_risk_score)
        slope, _ = np.polyfit(time_steps, extended_series, 1)

        if slope > 1.2 or deviation > 10.0:
            trajectory = "DETERIORATING"
            trajectory_label = "Deteriorating / Increasing Risk"
            risk_level = "HIGH" if current_risk_score >= 65.0 else "MODERATE"
        elif slope < -1.2 or deviation < -10.0:
            trajectory = "IMPROVING"
            trajectory_label = "Improving Wellness Trajectory"
            risk_level = "LOW"
        else:
            trajectory = "STABLE"
            trajectory_label = "Stable Within Personal Baseline"
            risk_level = "LOW" if current_risk_score < 45.0 else "MODERATE"

        # 4. 14-Day Trajectory Projection (Days 1 to 14)
        forecast_14_days = [
            round(float(np.clip(current_risk_score + (day * slope * 0.4), 0.0, 100.0)), 1)
            for day in range(1, 15)
        ]

        return {
            "resident_id": resident_id,
            "current_wellness_index": round(fused_wellness, 1),
            "current_risk_score": current_risk_score,
            "risk_level": risk_level,
            "trajectory": trajectory,
            "trajectory_status_label": trajectory_label,
            "is_insufficient_history": False,
            "confidence_score": 0.88,
            "baseline_score": round(personal_baseline, 1),
            "baseline_deviation": round(deviation, 1),
            "baseline_deviation_percent": deviation_pct,
            "longitudinal_slope": round(float(slope), 2),
            "forecast_14_days": forecast_14_days,
            "contributing_factors": self._calculate_contributing_factors(q_score, facial_score, vocal_score, social_score),
            "recommendations": self._generate_recommendations(current_risk_score),
            "model_metadata": {
                "algorithm": "RALPA (Resident-Adaptive Longitudinal Prediction Algorithm)",
                "specification_reference": "IT23228108.pdf Section 3.1-3.5",
                "evaluation_state": "Longitudinal Comparative Regression"
            }
        }

    def _calculate_contributing_factors(self, q_score: float, facial_score: Optional[float], vocal_score: float, social_score: float) -> list:
        # Transparent feature contributions reflecting relative modality weights
        if facial_score is not None:
            return [
                {
                    "title": "Questionnaire Self-Report",
                    "category": "Standardized Questionnaire",
                    "raw_score": round(q_score, 1),
                    "weight_percentage": 40.0,
                    "description": "Standardized loneliness and social connection assessment responses."
                },
                {
                    "title": "Social-Behavioral Participation",
                    "category": "Behavioral Indicators",
                    "raw_score": round(social_score, 1),
                    "weight_percentage": 25.0,
                    "description": "Interaction frequency, lounge presence, and group activity logs."
                },
                {
                    "title": "Facial Affect Expression",
                    "category": "Facial Affect (FER-2013)",
                    "raw_score": round(facial_score, 1),
                    "weight_percentage": 20.0,
                    "description": "Visual affective valence and composure features."
                },
                {
                    "title": "Vocal Acoustic Modulation",
                    "category": "Vocal Prosody",
                    "raw_score": round(vocal_score, 1),
                    "weight_percentage": 15.0,
                    "description": "Speech rate, fundamental frequency variation, and conversational cadence."
                }
            ]
        else:
            return [
                {
                    "title": "Questionnaire Self-Report",
                    "category": "Standardized Questionnaire",
                    "raw_score": round(q_score, 1),
                    "weight_percentage": 50.0,
                    "description": "Standardized loneliness and social connection assessment responses."
                },
                {
                    "title": "Social-Behavioral Participation",
                    "category": "Behavioral Indicators",
                    "raw_score": round(social_score, 1),
                    "weight_percentage": 31.25,
                    "description": "Interaction frequency, lounge presence, and group activity logs."
                },
                {
                    "title": "Vocal Acoustic Modulation",
                    "category": "Vocal Prosody",
                    "raw_score": round(vocal_score, 1),
                    "weight_percentage": 18.75,
                    "description": "Speech rate, fundamental frequency variation, and conversational cadence."
                },
                {
                    "title": "Facial Affect Expression",
                    "category": "Facial Affect (Retired)",
                    "raw_score": None,
                    "weight_percentage": 0.0,
                    "description": "Facial emotion recognition model has been retired from active pipeline."
                }
            ]

    def _generate_recommendations(self, risk_score: float) -> list:
        is_elevated = risk_score >= 60.0
        return [
            {
                "category": "Music Therapy",
                "title": "Soothing Classical & Traditional Chants",
                "rationale": "Acoustic rhythm stabilization supports positive affect and reduces vocal agitation.",
                "priority": "High" if is_elevated else "Recommended"
            },
            {
                "category": "Reading & Literature",
                "title": "Illustrated Historical Narratives",
                "rationale": "Provides comfortable personal engagement and prompts conversational recall.",
                "priority": "Medium"
            },
            {
                "category": "Religious / Cultural",
                "title": "Spiritual Reflection & Chanting",
                "rationale": "Grounded in Sri Lankan care home coping mechanisms (Wijesiri et al., 2019).",
                "priority": "Essential" if is_elevated else "Recommended"
            },
            {
                "category": "Social Interaction",
                "title": "Peer Carrom & Tea Time Connection",
                "rationale": "Facilitated small-group engagement to rebuild voluntary interaction rhythm.",
                "priority": "High" if is_elevated else "Recommended"
            }
        ]
