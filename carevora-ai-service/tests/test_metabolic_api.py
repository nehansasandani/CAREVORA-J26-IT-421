import os
import sys
import unittest

from fastapi.testclient import TestClient

# Ensure service directory is on path
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from main import app

HOME_INPUTS = {
    "resident_id": 1, "age": 68, "sex": "male", "waist_cm": 108, "height_cm": 172,
    "systolic_bp": [142, 138], "diastolic_bp": 84, "resting_hr_avg": 78, "smoking_status": "former",
    "drinks_per_week": 3, "vigorous_min_week": 0, "moderate_min_week": 60, "sedentary_hours": 9,
    "on_bp_meds": True, "on_cholesterol_meds": False, "on_diabetes_meds": False,
    "told_hypertension": True, "told_high_cholesterol": True, "told_diabetes": False,
}
CLINIC_LABS = {"fasting_glucose": 112, "hba1c": 6.1, "hdl": 38, "ldl": 130, "triglycerides": 210}


class TestMetabolicRiskApi(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def predict(self, payload):
        resp = self.client.post("/api/ml/predict-metabolic", json=payload)
        self.assertEqual(resp.status_code, 200, resp.text)
        body = resp.json()
        self.assertTrue(body["success"])
        return body["data"]

    def test_root_lists_metabolic_model(self):
        models = self.client.get("/").json()["models"]
        self.assertIn("metabolic", models)
        self.assertNotEqual(models["metabolic"], "unavailable")

    def test_home_inputs_give_tiers_for_all_outcomes(self):
        data = self.predict(HOME_INPUTS)
        self.assertEqual(data["resident_id"], 1)
        self.assertIn("not a diagnosis", data["disclaimer"])
        for outcome in ("diabetes", "cvd", "fatty_liver"):
            res = data["results"][outcome]
            self.assertEqual(res["status"], "ok")
            self.assertEqual(res["model_tier"], "home")
            self.assertIn(res["risk_tier"], ("low", "watch", "high"))
            self.assertTrue(0.0 <= res["probability"] <= 1.0)
            self.assertLessEqual(len(res["top_reasons"]), 3)

    def test_clinic_labs_switch_to_clinic_model(self):
        data = self.predict({**HOME_INPUTS, **CLINIC_LABS})
        self.assertEqual(data["results"]["diabetes"]["model_tier"], "clinic")
        self.assertEqual(data["results"]["cvd"]["model_tier"], "clinic")
        self.assertEqual(sorted(data["results"]["cvd"]["inputs_to_improve_estimate"]),
                         ["alt", "ast", "creatinine", "ggt"])

    def test_out_of_range_and_unused_inputs_are_reported(self):
        data = self.predict({**HOME_INPUTS, "systolic_bp": 400, "steps_per_day": 5200})
        self.assertTrue(any("systolic_bp" in w for w in data["input_warnings"]))
        self.assertIn("steps_per_day", data["inputs_not_used"])

    def test_missing_core_inputs_give_clear_message(self):
        data = self.predict({"waist_cm": 100})
        res = data["results"]["cvd"]
        self.assertEqual(res["status"], "insufficient_information")
        self.assertIn("age", res["missing_inputs"])

    def test_diagnosed_diabetes_is_not_screened(self):
        data = self.predict({**HOME_INPUTS, "told_diabetes": True})
        self.assertEqual(data["results"]["diabetes"]["status"], "not_applicable")

    def test_invalid_sex_is_rejected(self):
        resp = self.client.post("/api/ml/predict-metabolic", json={**HOME_INPUTS, "sex": "unknown"})
        self.assertEqual(resp.status_code, 422)

    def test_model_info(self):
        resp = self.client.get("/api/ml/metabolic/model-info")
        self.assertEqual(resp.status_code, 200)
        info = resp.json()["data"]
        self.assertEqual(set(info["outcomes"]), {"diabetes", "cvd", "fatty_liver"})
        self.assertIn("thresholds", info["outcomes"]["cvd"]["tiers"]["home"])


if __name__ == "__main__":
    unittest.main()
