import json
import urllib.request
import urllib.error
import numpy as np
import io
import wave
from PIL import Image

FASTAPI_URL = "http://127.0.0.1:8000"
BACKEND_URL = "http://localhost:8081"

def request(url, method="GET", data=None, headers=None):
    if headers is None:
        headers = {}
    req_data = None
    if data is not None:
        if isinstance(data, dict):
            req_data = json.dumps(data).encode("utf-8")
            headers["Content-Type"] = "application/json"
        elif isinstance(data, bytes):
            req_data = data
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return resp.status, content
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="ignore")
        return e.code, body
    except Exception as e:
        return 0, str(e)

print("="*75)
print("1. VERIFY FASTAPI AI MICROSERVICE ENDPOINTS & INFERENCE")
print("="*75)

# 1.1 Root status
code, resp = request(f"{FASTAPI_URL}/")
print(f"FastAPI Root: HTTP {code}")
print(f"Root Payload: {resp}\n")

# 1.2 Facial emotion endpoint with real PIL image
img = Image.new("RGB", (48, 48), color=(200, 160, 140))
buf = io.BytesIO()
img.save(buf, format="JPEG")
jpeg_bytes = buf.getvalue()

boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
body = (
    f"--{boundary}\r\n"
    f'Content-Disposition: form-data; name="file"; filename="test_face.jpg"\r\n'
    f"Content-Type: image/jpeg\r\n\r\n"
).encode("utf-8") + jpeg_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

headers = {"Content-Type": f"multipart/form-data; boundary={boundary}"}
code, resp = request(f"{FASTAPI_URL}/api/ml/analyze-photo", method="POST", data=body, headers=headers)
print(f"Facial Analysis (POST /api/ml/analyze-photo): HTTP {code}")
face_json = json.loads(resp)
analysis = face_json.get("analysis", {})
print(f"  Status: {face_json.get('status')}")
print(f"  Success: {face_json.get('success')}")
print(f"  Message: {face_json.get('message')}")
print(f"  Modality: {analysis.get('modality')}")
print(f"  Is Active: {analysis.get('is_active')}\n")

# 1.2b Colab-Trained ML Prediction Service endpoint
code, resp = request(f"{FASTAPI_URL}/api/ml/predict-models", method="POST", data={
    "resident_id": 101,
    "questionnaire_score": 40.0,
    "social_score": 35.0,
    "vocal_score": 45.0,
    "history_scores": [75.0, 60.0, 45.0]
})
print(f"Colab Models Direct Inference (POST /api/ml/predict-models): HTTP {code}")
colab_json = json.loads(resp)
if colab_json.get("success"):
    cdata = colab_json.get("data", {})
    hr_data = cdata.get("high_risk_prediction", {})
    tr_data = cdata.get("trajectory_class_prediction", {})
    print(f"  High Risk Prediction: {hr_data.get('classification_status')} (Prob: {hr_data.get('high_risk_probability')}, Threshold: {hr_data.get('threshold_used')})")
    print(f"  Trajectory Prediction: {tr_data.get('predicted_trajectory_class')} (Confidence: {tr_data.get('confidence_score')})")
    print(f"  Trajectory Probabilities: {tr_data.get('class_probabilities')}\n")

# 1.3 Audio feature extraction endpoint
audio_buf = io.BytesIO()
with wave.open(audio_buf, 'wb') as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(16000)
    samples = (np.sin(2 * np.pi * 440 * np.linspace(0, 1, 16000)) * 16384).astype(np.int16)
    wf.writeframes(samples.tobytes())
wav_bytes = audio_buf.getvalue()

audio_body = (
    f"--{boundary}\r\n"
    f'Content-Disposition: form-data; name="file"; filename="voice_sample.wav"\r\n'
    f"Content-Type: audio/wav\r\n\r\n"
).encode("utf-8") + wav_bytes + f"\r\n--{boundary}--\r\n".encode("utf-8")

code, resp = request(f"{FASTAPI_URL}/api/ml/analyze-audio", method="POST", data=audio_body, headers=headers)
print(f"Vocal Feature Extraction (POST /api/ml/analyze-audio): HTTP {code}")
audio_json = json.loads(resp)
a_analysis = audio_json.get("analysis", {})
print(f"  Modality: {a_analysis.get('modality')}")
print(f"  Method: {a_analysis.get('method')}")
print(f"  Grounding Dataset: {a_analysis.get('grounding_dataset')}")
print(f"  Acoustic Profile: {a_analysis.get('acoustic_profile')} ({a_analysis.get('profile_label')})")
print(f"  Vocal Wellness Score: {a_analysis.get('vocal_wellness_score')}")
print(f"  Metrics: {a_analysis.get('metrics')}")
print(f"  Clinical Disclaimer: {a_analysis.get('clinical_disclaimer')}\n")

# 1.4 Comprehensive RALPA Multi-Case Execution
print("="*75)
print("2. VERIFY RALPA PROGRESSION CASES")
print("="*75)

ralpa_cases = [
    {
        "name": "Zero History (Initial Session)",
        "payload": {
            "resident_id": 101,
            "questionnaire_score": 85.0,
            "social_score": 80.0,
            "history_scores": []
        }
    },
    {
        "name": "One History Session (Insufficient for baseline)",
        "payload": {
            "resident_id": 102,
            "questionnaire_score": 85.0,
            "social_score": 80.0,
            "history_scores": [82.0]
        }
    },
    {
        "name": "Two Equal Sessions (Stable Baseline)",
        "payload": {
            "resident_id": 103,
            "questionnaire_score": 80.0,
            "social_score": 80.0,
            "history_scores": [77.0, 77.0]
        }
    },
    {
        "name": "Increasing Wellness (Improving Trajectory)",
        "payload": {
            "resident_id": 104,
            "questionnaire_score": 90.0,
            "social_score": 88.0,
            "history_scores": [50.0, 60.0, 70.0, 80.0]
        }
    },
    {
        "name": "Decreasing Wellness (Deteriorating Trajectory)",
        "payload": {
            "resident_id": 105,
            "questionnaire_score": 40.0,
            "social_score": 35.0,
            "history_scores": [85.0, 75.0, 65.0, 50.0]
        }
    },
    {
        "name": "Stable Scores Across Longitudinal Timepoints",
        "payload": {
            "resident_id": 106,
            "questionnaire_score": 78.0,
            "social_score": 80.0,
            "history_scores": [79.0, 80.0, 78.0, 81.0, 79.0]
        }
    },
    {
        "name": "Out-of-Range Negative & Overflow Clamping",
        "payload": {
            "resident_id": 107,
            "questionnaire_score": -45.0,
            "social_score": 250.0,
            "history_scores": [-100.0, 150.0, 85.0]
        }
    },
    {
        "name": "Missing/None Values Handling",
        "payload": {
            "resident_id": 108,
            "questionnaire_score": 75.0,
            "social_score": None,
            "history_scores": [None, "invalid_val", 70.0, 72.0]
        }
    },
    {
        "name": "Multiple Residents with Isolated Histories",
        "payload": {
            "resident_id": 109,
            "questionnaire_score": 88.0,
            "social_score": 85.0,
            "history_scores": [85.0, 87.0, 86.0]
        }
    }
]

for tc in ralpa_cases:
    code, resp = request(f"{FASTAPI_URL}/api/ml/predict-ralpa", method="POST", data=tc["payload"])
    parsed = json.loads(resp)
    data = parsed.get("data", {})
    forecast = data.get("forecast_14_days")
    f_len = len(forecast) if forecast else 0
    insufficient = data.get("is_insufficient_history")
    print(f"Case [{tc['name']}]:")
    print(f"  Status: HTTP {code}")
    print(f"  Wellness Index: {data.get('current_wellness_index')}, Risk Score: {data.get('current_risk_score')}")
    print(f"  Trajectory: {data.get('trajectory')} ({data.get('trajectory_status_label')})")
    print(f"  Risk Level: {data.get('risk_level')}")
    print(f"  Baseline: {data.get('baseline_score')}, Deviation: {data.get('baseline_deviation')}, Slope: {data.get('longitudinal_slope')}")
    print(f"  Insufficient History Flag: {insufficient}")
    print(f"  14-Day Forecast Points: {f_len} {forecast[:4] if forecast else 'None'}\n")

# 1.5 Deterministic Check
p1 = json.loads(request(f"{FASTAPI_URL}/api/ml/predict-ralpa", method="POST", data=ralpa_cases[3]["payload"])[1])
p2 = json.loads(request(f"{FASTAPI_URL}/api/ml/predict-ralpa", method="POST", data=ralpa_cases[3]["payload"])[1])
print(f"Deterministic Verification (Identical Inputs): {p1 == p2}\n")

print("="*75)
print("3. VERIFY SPRING BOOT AUTH & RBAC (ROLE-BASED ACCESS CONTROL)")
print("="*75)

def login(email, password):
    code, resp = request(f"{BACKEND_URL}/api/auth/login", method="POST", data={"email": email, "password": password})
    if code == 200:
        body = json.loads(resp)
        return body.get("data")
    return None

doctor_auth = login("dr.reed@carevora.com", "doctor123")
cg1_auth = login("eleanor.vance@carevora.com", "carevora_admin")
cg2_auth = login("david.silva@carevora.com", "carevora123")
elder1_auth = login("sarah.jenkins@carevora.com", "carevora123")
elder2_auth = login("arthur.p@carevora.com", "carevora123")

print(f"Doctor Authenticated: Role={doctor_auth.get('role') if doctor_auth else 'None'}")
print(f"Caregiver 1 Authenticated: Facility Home ID={cg1_auth.get('elderHomeId') if cg1_auth else 'None'}")
print(f"Caregiver 2 Authenticated: Facility Home ID={cg2_auth.get('elderHomeId') if cg2_auth else 'None'}")
print(f"Elder 1 (Sarah) Authenticated: Resident ID={elder1_auth.get('residentId') if elder1_auth else 'None'}")
print(f"Elder 2 (Arthur) Authenticated: Resident ID={elder2_auth.get('residentId') if elder2_auth else 'None'}\n")

rbac_tests = [
    ("Doctor access Resident 1 (Facility 1)", doctor_auth['token'], 1, 200),
    ("Doctor access Resident 3 (Facility 2)", doctor_auth['token'], 3, 200),
    ("Caregiver 1 access Resident 1 (Facility 1)", cg1_auth['token'], 1, 200),
    ("Caregiver 1 CROSS-FACILITY access Resident 3 (Facility 2)", cg1_auth['token'], 3, 403),
    ("Caregiver 2 access Resident 3 (Facility 2)", cg2_auth['token'], 3, 200),
    ("Caregiver 2 CROSS-FACILITY access Resident 1 (Facility 1)", cg2_auth['token'], 1, 403),
    ("Elder 1 access Self (Resident 1)", elder1_auth['token'], 1, 200),
    ("Elder 1 OTHER-RESIDENT access Resident 2 (Facility 1 Arthur)", elder1_auth['token'], 2, 403),
    ("Elder 1 OTHER-FACILITY access Resident 3 (Facility 2 Margaret)", elder1_auth['token'], 3, 403),
]

for name, token, res_id, expected_status in rbac_tests:
    code, resp = request(f"{BACKEND_URL}/api/residents/{res_id}", headers={"Authorization": f"Bearer {token}"})
    status_str = "PASS" if code == expected_status else f"FAIL (Got HTTP {code})"
    print(f"RBAC [{name}]: Expected=HTTP {expected_status}, Actual=HTTP {code} -> {status_str}")

print("\n" + "="*75)
print("4. VERIFY ASSESSMENT SUBMISSION & JPA PERSISTENCE")
print("="*75)

# Submit valid assessment for Sarah (Resident 1) as Caregiver 1
submit_payload = {
    "residentId": 1,
    "answers": [1, 2, 1, 2, 1],
    "includeFacialCheck": True,
    "includeVoiceCheck": True
}
code, resp = request(f"{BACKEND_URL}/api/assessments/submit", method="POST", data=submit_payload, headers={"Authorization": f"Bearer {cg1_auth['token']}"})
print(f"Submit Assessment (POST /api/assessments/submit): HTTP {code}")
saved_assessment = json.loads(resp).get("data", {}) if code == 200 else {}
assessment_id = saved_assessment.get("id")
print(f"Created Assessment ID: {assessment_id}")
print(f"Calculated Overall Score: {saved_assessment.get('overallScore')}")
print(f"Calculated Emotional Score: {saved_assessment.get('emotionalScore')}")
print(f"Calculated Social Score: {saved_assessment.get('socialScore')}")
print(f"Contributing Factors Count: {len(saved_assessment.get('contributingFactors', []))}")
print(f"Recommendations Count: {len(saved_assessment.get('recommendations', []))}")

# Read history back
code, resp = request(f"{BACKEND_URL}/api/assessments/resident/1", headers={"Authorization": f"Bearer {cg1_auth['token']}"})
print(f"\nRead Resident 1 History (GET /api/assessments/resident/1): HTTP {code}")
if code == 200:
    history = json.loads(resp).get("data", [])
    print(f"Assessment records found in DB: {len(history)}")
    found = any(a.get("id") == assessment_id for a in history)
    print(f"Submitted assessment persisted in database: {found}")

# Verify Spring Boot -> FastAPI Trajectory bridge with now 2 longitudinal assessments in DB
print("\n" + "="*75)
print("5. VERIFY SPRING BOOT -> FASTAPI BRIDGE (GET /api/ai/trajectory/1)")
print("="*75)

code, resp = request(f"{BACKEND_URL}/api/ai/trajectory/1", headers={"Authorization": f"Bearer {cg1_auth['token']}"})
print(f"Backend Bridge /api/ai/trajectory/1: HTTP {code}")
bridge_data = json.loads(resp).get("data", {})
print(f"Bridge Trajectory Response: {bridge_data.get('trajectory')} ({bridge_data.get('trajectory_status_label')})")
print(f"Current Risk Score: {bridge_data.get('current_risk_score')}, Baseline: {bridge_data.get('baseline_score')}")
print(f"Longitudinal Slope: {bridge_data.get('longitudinal_slope')}")
print(f"14-Day Continuous Forecast Points: {len(bridge_data.get('forecast_14_days', [])) if bridge_data.get('forecast_14_days') else 'None'}")
print(f"First 4 Forecast Values: {bridge_data.get('forecast_14_days', [])[:4] if bridge_data.get('forecast_14_days') else 'None'}")
