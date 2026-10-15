import unittest
import io
import os
import sys
import numpy as np
import pandas as pd
from PIL import Image
from fastapi.testclient import TestClient

# Ensure service directory is on path
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from main import app, ml_service
from vision_analyzer import analyze_facial_affect, get_trained_model
from audio_analyzer import analyze_vocal_affect
from ralpa_engine import RALPAEngine
from ml_prediction_service import CarevoraMLPredictionService

class TestAiMicroservice(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def create_synthetic_image(self, color=(200, 200, 200), size=(64, 64)):
        img = Image.new("RGB", size, color=color)
        buf = io.BytesIO()
        img.save(buf, format="JPEG")
        return buf.getvalue()

    def test_01_root_endpoint_metadata(self):
        resp = self.client.get("/")
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["status"], "online")
        self.assertIn("facial", data["models"])
        self.assertIn("Retired", data["models"]["facial"])
        self.assertIn("high_risk_classifier", data["models"])
        self.assertIn("trajectory_classifier", data["models"])
        self.assertIn("model_metadata", data)
        self.assertEqual(data["model_metadata"]["feature_count"], 149)
        self.assertAlmostEqual(data["model_metadata"]["high_risk_threshold"], 0.31, places=2)

    def test_02_joblib_models_loaded_correctly(self):
        service = CarevoraMLPredictionService()
        self.assertIsNotNone(service.high_risk_artifact)
        self.assertIsNotNone(service.trajectory_artifact)

        # High risk model verification
        self.assertEqual(len(service.expected_features), 149)
        self.assertAlmostEqual(service.high_risk_threshold, 0.31, places=2)
        self.assertEqual(len(service.high_risk_artifact['models']), 4)
        self.assertIn('lgb', service.high_risk_artifact['models'])
        self.assertIn('lr', service.high_risk_artifact['models'])

        # Trajectory model verification
        self.assertEqual(len(service.trajectory_artifact['models']), 3)
        self.assertEqual(service.trajectory_classes, ['deteriorating', 'improving', 'stable'])

    def test_03_retired_facial_model_behavior(self):
        # 1. get_trained_model returns retired placeholder with no weights loaded
        model = get_trained_model()
        self.assertTrue(getattr(model, "is_retired", True))

        # 2. analyze_facial_affect returns retired status
        res = analyze_facial_affect(image_bytes=b"dummy")
        self.assertEqual(res["status"], "retired")
        self.assertFalse(res["is_active"])
        self.assertIsNone(res["dominant_emotion"])

        # 3. HTTP POST /api/ml/analyze-photo returns 200 with retired payload
        img_bytes = self.create_synthetic_image()
        resp = self.client.post(
            "/api/ml/analyze-photo",
            files={"file": ("test_face.jpg", img_bytes, "image/jpeg")}
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertFalse(data["success"])
        self.assertEqual(data["status"], "retired")
        self.assertIn("retired", data["message"].lower())

    def test_04_vocal_acoustic_feature_extraction(self):
        samples = (np.sin(2 * np.pi * 440 * np.linspace(0, 0.5, 8000)) * 60).astype(np.int8).tobytes()
        res = analyze_vocal_affect(audio_bytes=samples)

        self.assertEqual(res["modality"], "Vocal Acoustic Analysis")
        self.assertIn("Rule-Based", res["method"])
        self.assertIn("metrics", res)
        self.assertIn("pitch_modulation", res["metrics"])
        self.assertIn("cadence_stability", res["metrics"])

    def test_05_vocal_audio_endpoint(self):
        samples = (np.sin(2 * np.pi * 440 * np.linspace(0, 0.5, 8000)) * 50).astype(np.int8).tobytes()
        resp = self.client.post(
            "/api/ml/analyze-audio",
            files={"file": ("test_voice.raw", samples, "application/octet-stream")}
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data["success"])
        self.assertEqual(data["analysis"]["modality"], "Vocal Acoustic Analysis")

    def test_06_colab_models_prediction_service(self):
        service = CarevoraMLPredictionService()
        # High-risk profile (low scores, deteriorating trend)
        feature_df = service.build_feature_vector_from_assessment(
            resident_id=901,
            questionnaire_score=30.0,
            social_score=25.0,
            vocal_score=35.0,
            history_scores=[70.0, 55.0, 40.0]
        )
        self.assertEqual(feature_df.shape, (1, 149))

        res = service.predict_all(feature_df)
        self.assertIn("high_risk_prediction", res)
        self.assertIn("trajectory_class_prediction", res)

        hr = res["high_risk_prediction"]
        self.assertTrue(hr["is_high_risk"])
        self.assertEqual(hr["high_risk_label"], 1)
        self.assertGreaterEqual(hr["high_risk_probability"], hr["threshold_used"])

        traj = res["trajectory_class_prediction"]
        self.assertIn(traj["predicted_trajectory_class"], ['deteriorating', 'improving', 'stable'])
        self.assertIn("class_probabilities", traj)
        self.assertEqual(len(traj["class_probabilities"]), 3)

    def test_07_predict_models_direct_api_endpoint(self):
        req_body = {
            "resident_id": 902,
            "questionnaire_score": 85.0,
            "social_score": 90.0,
            "vocal_score": 85.0,
            "history_scores": [80.0, 82.0, 85.0]
        }
        resp = self.client.post("/api/ml/predict-models", json=req_body)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertTrue(data["success"])
        self.assertIn("data", data)
        self.assertIn("high_risk_prediction", data["data"])
        self.assertIn("trajectory_class_prediction", data["data"])

    def test_08_predict_ralpa_endpoint_integration(self):
        req_body = {
            "resident_id": 903,
            "questionnaire_score": 60.0,
            "social_score": 65.0,
            "history_scores": [50.0, 55.0, 60.0]
        }
        resp = self.client.post("/api/ml/predict-ralpa", json=req_body)
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertTrue(body["success"])
        data = body["data"]

        # 1. Existing RALPA engine fields preserved
        self.assertIn("current_wellness_index", data)
        self.assertIn("current_risk_score", data)
        self.assertIn("trajectory", data)
        self.assertIn("forecast_14_days", data)
        self.assertEqual(len(data["forecast_14_days"]), 14)
        self.assertIn("contributing_factors", data)
        self.assertIn("recommendations", data)

        # 2. Colab ML models integrated
        self.assertIn("ml_risk_assessment", data)
        self.assertIn("is_high_risk", data["ml_risk_assessment"])
        self.assertIn("threshold_used", data["ml_risk_assessment"])
        self.assertAlmostEqual(data["ml_risk_assessment"]["threshold_used"], 0.31, places=2)

        self.assertIn("ml_trajectory_prediction", data)
        self.assertIn(data["ml_trajectory_prediction"]["predicted_trajectory_class"], ['deteriorating', 'improving', 'stable'])

        # 3. Modality breakdown notes retired facial
        self.assertEqual(data["modality_breakdown"]["facial"]["status"], "retired")
        self.assertFalse(data["modality_breakdown"]["facial"]["is_active"])

    def test_09_predict_ralpa_insufficient_history(self):
        req_body = {
            "resident_id": 904,
            "questionnaire_score": 80.0,
            "history_scores": [75.0] # Only 1 historical observation
        }
        resp = self.client.post("/api/ml/predict-ralpa", json=req_body)
        self.assertEqual(resp.status_code, 200)
        data = resp.json()["data"]

        self.assertTrue(data["is_insufficient_history"])
        self.assertEqual(data["trajectory"], "BASELINE_ESTABLISHING")
        self.assertIsNone(data["forecast_14_days"])
        self.assertIn("ml_risk_assessment", data)

if __name__ == "__main__":
    unittest.main()
