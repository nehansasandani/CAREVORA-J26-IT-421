import os
import json
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from vision_analyzer import analyze_facial_affect
from audio_analyzer import analyze_vocal_affect
from ralpa_engine import RALPAEngine
from ml_prediction_service import CarevoraMLPredictionService

app = FastAPI(
    title="CAREVORA AI/ML Microservice",
    description="Multimodal Wellness Monitoring, Colab-Trained Ensemble Risk/Trajectory Classifiers & RALPA Engine",
    version="2.0.0"
)

# Enable CORS for Flutter Web & Mobile Clients (localhost, 127.0.0.1, and Android emulators)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

ralpa = RALPAEngine()
ml_service = CarevoraMLPredictionService()

class MultimodalAssessmentRequest(BaseModel):
    resident_id: int
    questionnaire_score: float = 85.0
    facial_cues: Optional[Dict[str, Any]] = None
    vocal_cues: Optional[Dict[str, Any]] = None
    social_score: Optional[float] = 80.0
    history_scores: Optional[List[Any]] = None
    score_domain: Optional[str] = "wellness"

class ModelPredictionRequest(BaseModel):
    resident_id: int = 1
    questionnaire_score: float = 80.0
    social_score: float = 80.0
    vocal_score: Optional[float] = 80.0
    history_scores: Optional[List[float]] = None
    feature_dict: Optional[Dict[str, float]] = None

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "CAREVORA AI/ML Intelligence Microservice",
        "models": {
            "facial": "Retired (FER-2013 LightweightEmotionCNN decommissioned from active pipeline)",
            "vocal": "CREMA-D Acoustic Feature Pipeline (Rule-based)",
            "high_risk_classifier": "Carevora High-Risk Ensemble (LightGBM, LR, HGB - Colab Trained)",
            "trajectory_classifier": "Carevora Trajectory Ensemble (LightGBM, LR - Colab Trained)",
            "ralpa_longitudinal": "RALPA Latent Progression Engine (Longitudinal Baseline & 14-Day Projection)"
        },
        "model_metadata": {
            "high_risk_threshold": ml_service.high_risk_threshold,
            "trajectory_classes": ml_service.trajectory_classes,
            "feature_count": len(ml_service.expected_features)
        }
    }

@app.get("/api/ml/model-metrics")
def get_model_metrics():
    """
    Returns empirical train & test metrics for the Colab-trained models and benchmarks.
    """
    return {
        "success": True,
        "data": {
            "high_risk_model": {
                "algorithm": "Ensemble (LGBM, LGBM_seed7, LogisticRegression, HistGradientBoosting)",
                "decision_threshold": ml_service.high_risk_threshold,
                "test_accuracy": 0.6522,
                "test_precision": 0.6780,
                "test_recall": 0.8659,
                "test_f1": 0.7605,
                "test_roc_auc": 0.6563,
                "dataset": "Carevora Longitudinal Synthetic Assessment Benchmark (900 held-out test records)",
                "clinical_disclaimer": "Experimental assistive decision-support model; not a clinical diagnostic system."
            },
            "trajectory_model": {
                "algorithm": "Ensemble (LGBM, LGBM_seed7, LogisticRegression)",
                "classes": ml_service.trajectory_classes,
                "test_accuracy": 0.4144,
                "macro_f1": 0.3568,
                "macro_precision": 0.4256,
                "macro_recall": 0.3842,
                "roc_auc_ovr": 0.5804,
                "clinical_disclaimer": "Experimental multiclass trajectory projection; supplements RALPA trend slope."
            },
            "facial_emotion_model": {
                "status": "retired",
                "message": "FER-2013 facial CNN removed from active inference pipeline."
            }
        }
    }

@app.post("/api/ml/analyze-photo")
async def analyze_photo(file: UploadFile = File(...)):
    """
    Facial emotion inference endpoint (Decommissioned).
    Informs caller that the image-based facial CNN is retired from the active pipeline.
    """
    return {
        "success": False,
        "status": "retired",
        "message": "Facial emotion recognition model (FER-2013) has been retired from the active application pipeline. Image upload for affect detection is disabled.",
        "analysis": {
            "status": "retired",
            "is_active": False,
            "dominant_emotion": None,
            "mood_summary": "UNAVAILABLE",
            "confidence": 0.0,
            "contributing_insight": "Facial affect scanning is retired from the active pipeline. Assessment relies on structured clinical questionnaire, behavioral indicators, and acoustic vocal metrics."
        }
    }

@app.post("/api/ml/analyze-audio")
async def analyze_audio(file: UploadFile = File(...)):
    """
    Acoustic speech feature extraction from recorded audio file/bytes.
    Rule-based zero crossings, RMS energy, and cadence metrics.
    """
    contents = await file.read()
    res = analyze_vocal_affect(audio_bytes=contents)
    return {
        "success": True,
        "filename": file.filename,
        "analysis": res
    }

@app.post("/api/ml/predict-models")
def predict_models_direct(req: ModelPredictionRequest):
    """
    Dedicated endpoint executing the Colab-trained High-Risk and Trajectory models directly
    on structured resident assessment inputs.
    """
    try:
        if req.feature_dict:
            import pandas as pd
            missing = [f for f in ml_service.expected_features if f not in req.feature_dict]
            if missing:
                raise HTTPException(status_code=400, detail=f"Missing required feature columns: {missing[:5]}")
            df = pd.DataFrame([req.feature_dict])[ml_service.expected_features]
        else:
            df = ml_service.build_feature_vector_from_assessment(
                resident_id=req.resident_id,
                questionnaire_score=req.questionnaire_score,
                social_score=req.social_score,
                vocal_score=req.vocal_score,
                history_scores=req.history_scores
            )

        predictions = ml_service.predict_all(df)
        return {
            "success": True,
            "resident_id": req.resident_id,
            "data": predictions
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Model prediction error: {str(e)}")

@app.post("/api/ml/predict-ralpa")
def predict_ralpa_progression(req: MultimodalAssessmentRequest):
    # 1. Vision Emotion Inference (Retired status)
    face_res = analyze_facial_affect(simulated_cues=req.facial_cues)
    
    # 2. Audio Acoustic Inference
    audio_res = analyze_vocal_affect(simulated_cues=req.vocal_cues)

    # 3. Colab-Trained ML Model Inference
    feature_df = ml_service.build_feature_vector_from_assessment(
        resident_id=req.resident_id,
        questionnaire_score=req.questionnaire_score,
        social_score=req.social_score or 80.0,
        vocal_score=audio_res.get('vocal_wellness_score', 80.0),
        history_scores=req.history_scores
    )
    ml_predictions = ml_service.predict_all(feature_df)

    # 4. Multimodal Latent Fusion & RALPA Trajectory Progression
    scores = {
        'questionnaire': req.questionnaire_score,
        'facial': None, # Explicitly mark facial as retired / None
        'vocal': audio_res['vocal_wellness_score'],
        'social': req.social_score or 80.0
    }

    prediction = ralpa.predict_progression(
        resident_id=req.resident_id,
        current_scores=scores,
        history_scores=req.history_scores,
        score_domain=req.score_domain or "wellness"
    )

    return {
        "success": True,
        "data": {
            **prediction,
            "ml_risk_assessment": ml_predictions["high_risk_prediction"],
            "ml_trajectory_prediction": ml_predictions["trajectory_class_prediction"],
            "modality_breakdown": {
                "facial": face_res,
                "vocal": audio_res
            }
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
