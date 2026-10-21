import os
import json
import math
from pathlib import Path
from typing import List, Literal, Optional, Dict, Any, Union

from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

# LightGBM must load its OpenMP runtime before torch does; importing torch first makes the
# RALPA LightGBM models segfault on load on macOS (two libomp copies in one process).
import lightgbm  # noqa: F401  pyrefly: ignore [missing-import]

from vision_analyzer import analyze_facial_affect
from audio_analyzer import analyze_vocal_affect
from ralpa_engine import RALPAEngine
from cognitive_engine import CognitiveEngine, CognitiveValidationError
from carevora_risk.predictor import RiskPredictor

app = FastAPI(
    title="CAREVORA AI/ML Microservice",
    description="Multimodal Emotion Recognition, RALPA Trajectory Forecasting, ACRF Cognitive Scoring "
                "& Metabolic Risk Tiers Engine",
    version="1.2.0"
)

# Enable CORS for Flutter Web & Mobile Clients (localhost, 127.0.0.1, and Android emulators)
# Avoiding wildcard allow_origins=["*"] with allow_credentials=True to comply with CORS specification
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

ralpa = RALPAEngine()
cognitive_engine = CognitiveEngine()

# Metabolic risk tiers: logistic regression models trained on NHANES 2013-2018 (see ML/README.md),
# shipped as portable JSON and scored without scikit-learn.
METABOLIC_MODEL_DIR = Path(os.environ.get(
    "CAREVORA_METABOLIC_MODEL_DIR", Path(__file__).resolve().parent / "models" / "metabolic"))
try:
    metabolic_predictor: Optional[RiskPredictor] = RiskPredictor(METABOLIC_MODEL_DIR)
    metabolic_load_error: Optional[str] = None
except (OSError, ValueError, KeyError) as exc:
    metabolic_predictor = None
    metabolic_load_error = f"Metabolic models could not be loaded from {METABOLIC_MODEL_DIR}: {exc}"


# ============================================================================
# Request / Response Schemas: Emotional & Multimodal RALPA
# ============================================================================

class MultimodalAssessmentRequest(BaseModel):
    resident_id: int
    questionnaire_score: float = 85.0
    facial_cues: Optional[Dict[str, Any]] = None
    vocal_cues: Optional[Dict[str, Any]] = None
    social_score: Optional[float] = None
    history_scores: Optional[List[Any]] = None
    score_domain: Optional[str] = "wellness"
    raw_features: Optional[Dict[str, Any]] = None



# ============================================================================
# Request / Response Schemas: Cognitive Wellness & ACRF Scoring
# ============================================================================

class CognitiveCategoryScores(BaseModel):
    memory: float = Field(..., ge=0.0, le=100.0, description="Memory assessment score on 0-100 scale")
    attention: float = Field(..., ge=0.0, le=100.0, description="Attention assessment score on 0-100 scale")
    orientation: float = Field(..., ge=0.0, le=100.0, description="Orientation assessment score on 0-100 scale")
    recall: float = Field(..., ge=0.0, le=100.0, description="Recall assessment score on 0-100 scale")
    reasoning: float = Field(..., ge=0.0, le=100.0, description="Reasoning assessment score on 0-100 scale")

    @field_validator("memory", "attention", "orientation", "recall", "reasoning", mode="after")
    @classmethod
    def check_finite(cls, v: float) -> float:
        if math.isnan(v):
            raise ValueError("Category score cannot be NaN")
        if math.isinf(v):
            raise ValueError("Category score cannot be infinite")
        return v


class CognitiveAssessmentRequest(BaseModel):
    resident_id: Optional[int] = Field(None, description="Resident identifier")
    scores: Optional[CognitiveCategoryScores] = Field(None, description="Cognitive subcategory scores object")

    memory: Optional[float] = Field(None, ge=0.0, le=100.0)
    attention: Optional[float] = Field(None, ge=0.0, le=100.0)
    orientation: Optional[float] = Field(None, ge=0.0, le=100.0)
    recall: Optional[float] = Field(None, ge=0.0, le=100.0)
    reasoning: Optional[float] = Field(None, ge=0.0, le=100.0)

    # Optional demographic & task features for Random Forest ML inference (synthetic data experiment)
    age: Optional[float] = Field(None, gt=0.0, le=130.0, description="Resident age in years")
    education_years: Optional[float] = Field(None, ge=0.0, le=40.0, description="Years of formal education")
    accuracies: Optional[Dict[str, float]] = Field(None, description="Per-domain task accuracies (0.0 to 1.0 or 0 to 100)")
    response_times: Optional[Dict[str, float]] = Field(None, description="Per-domain task response times in seconds")
    assessment_number: Optional[int] = Field(None, ge=1, description="Sequential assessment index")
    history: Optional[List[Dict[str, Any]]] = Field(None, description="Historical assessments for longitudinal tracking")

    @model_validator(mode="after")
    def populate_and_validate_scores(self) -> "CognitiveAssessmentRequest":
        if self.scores is not None:
            return self

        flat = [self.memory, self.attention, self.orientation, self.recall, self.reasoning]
        if any(f is not None for f in flat):
            if any(f is None for f in flat):
                raise ValueError(
                    "All 5 cognitive categories (memory, attention, orientation, recall, reasoning) "
                    "are required when submitting flat scores."
                )
            self.scores = CognitiveCategoryScores(
                memory=self.memory,  # type: ignore[arg-type]
                attention=self.attention,  # type: ignore[arg-type]
                orientation=self.orientation,  # type: ignore[arg-type]
                recall=self.recall,  # type: ignore[arg-type]
                reasoning=self.reasoning,  # type: ignore[arg-type]
            )
            return self

        raise ValueError(
            "Cognitive scores required. Supply 'scores' object or top-level 'memory', 'attention', "
            "'orientation', 'recall', and 'reasoning' fields."
        )


class CategoryContributionDto(BaseModel):
    category: str
    score: float
    weight: float
    contribution: float
    weight_percentage: str


class AcrfAssessmentDto(BaseModel):
    acrf_score: float
    raw_weighted_score: float
    scale: str
    scoring_direction: str
    weights_applied: Dict[str, float]
    category_scores: Dict[str, float]
    category_contributions: List[CategoryContributionDto]
    methodology: str
    clinical_disclaimer: str


class MlModelStatusDto(BaseModel):
    available: bool
    model_type: str
    status_message: str
    prediction: Optional[Any] = None
    probabilities: Optional[Dict[str, float]] = None
    alert_threshold: Optional[float] = None
    alert_triggered: Optional[bool] = None
    feature_set: Optional[str] = None
    missing_features: Optional[List[str]] = None
    feature_count_expected: Optional[int] = None
    experimental_label: Optional[str] = None
    disclaimer: Optional[str] = None


class CognitiveAssessmentData(BaseModel):
    resident_id: Optional[int] = None
    acrf_assessment: AcrfAssessmentDto
    ml_model_evaluation: MlModelStatusDto


class CognitiveAssessmentResponse(BaseModel):
    success: bool
    data: CognitiveAssessmentData


# ============================================================================
# Request Schema: Metabolic Health Risk Tiers
# ============================================================================

class MetabolicRiskRequest(BaseModel):
    """Inputs for the metabolic risk models. Every field is optional: the service picks the
    highest tier (home < clinic < extended) whose inputs are complete and says what is missing.
    Out-of-range values are ignored and reported in `input_warnings`."""
    model_config = ConfigDict(extra="allow")   # unknown keys are returned in `inputs_not_used`

    resident_id: Optional[int] = Field(None, description="Resident identifier (not used by the model)")

    # Home tier
    age: Optional[float] = Field(None, description="Years")
    sex: Optional[Literal["male", "female"]] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    bmi: Optional[float] = Field(None, description="kg/m2")
    waist_cm: Optional[float] = None
    systolic_bp: Optional[Union[float, List[float]]] = Field(None, description="mmHg; one reading or several")
    diastolic_bp: Optional[Union[float, List[float]]] = Field(None, description="mmHg; one reading or several")
    resting_hr: Optional[float] = Field(None, description="Beats per minute")
    resting_hr_avg: Optional[float] = Field(None, description="Wearable alias of resting_hr")
    smoking_status: Optional[Literal["never", "former", "current"]] = None
    drinks_per_week: Optional[float] = None
    vigorous_min_week: Optional[float] = None
    moderate_min_week: Optional[float] = Field(None, description="Includes walking and cycling")
    sedentary_hours: Optional[float] = Field(None, description="Hours per day sitting")
    on_bp_meds: Optional[bool] = None
    on_cholesterol_meds: Optional[bool] = None
    on_diabetes_meds: Optional[bool] = None
    told_hypertension: Optional[bool] = None
    told_high_cholesterol: Optional[bool] = None
    told_diabetes: Optional[bool] = None

    # Clinic tier
    fasting_glucose: Optional[float] = Field(None, description="mg/dL")
    hba1c: Optional[float] = Field(None, description="%")
    hdl: Optional[float] = Field(None, description="mg/dL")
    ldl: Optional[float] = Field(None, description="mg/dL")
    total_cholesterol: Optional[float] = Field(None, description="mg/dL")
    triglycerides: Optional[float] = Field(None, description="mg/dL")

    # Extended tier
    alt: Optional[float] = Field(None, description="U/L")
    ast: Optional[float] = Field(None, description="U/L")
    ggt: Optional[float] = Field(None, description="U/L")
    creatinine: Optional[float] = Field(None, description="mg/dL")


# ============================================================================
# API Endpoints
# ============================================================================

@app.get("/")
def root():
    return {
        "status": "online",
        "service": "CAREVORA AI/ML Intelligence Microservice",
        "models": {
            "facial": "Trained PyTorch FER-2013 CNN Model",
            "vocal": "Trained Scikit-Learn Vocal Emotion Classifier (CREMA-D Grounded, 94.9% Acc)",
            "high_risk": f"Colab Heterogeneous Ensemble (2xLightGBM, LogReg, HistGB; threshold {ralpa.high_risk_threshold})",
            "trajectory": f"Colab Ensemble (2xLightGBM, LogReg; classes: {ralpa.trajectory_classes}) + RALPA Engine",
            "cognitive": "ACRF Engine & Random Forest Model (Trained on Synthetic Data - Experimental)",
            "metabolic": ("Logistic regression risk tiers (diabetes, cardiovascular disease, fatty liver; "
                          "NHANES 2013-2018)" if metabolic_predictor else "unavailable")
        }
    }


@app.get("/api/ml/model-metrics")
def get_model_metrics():
    """
    Returns empirical train & test accuracy, precision, recall, and F1-score
    evaluated on the FER-2013 benchmark dataset.
    """
    metrics_path = os.path.join(os.path.dirname(__file__), "model_metrics.json")
    if os.path.exists(metrics_path):
        with open(metrics_path, "r") as f:
            return {"success": True, "data": json.load(f)}
    return {"success": False, "message": "Metrics not found"}


@app.post("/api/ml/analyze-photo")
async def analyze_photo(file: UploadFile = File(...)):
    """
    Endpoint to receive a live captured photo from mobile/web camera,
    process it through trained PyTorch FER model, and return facial affect analysis.
    Explicitly reports success, no_face, unavailable, or error states.
    """
    contents = await file.read()
    res = analyze_facial_affect(image_bytes=contents)
    is_success = res.get("status") == "success"
    return {
        "success": is_success,
        "status": res.get("status", "error"),
        "filename": file.filename,
        "analysis": res
    }


@app.post("/api/ml/analyze-audio")
async def analyze_audio(file: UploadFile = File(...)):
    """
    Endpoint for acoustic speech feature extraction from recorded audio file/bytes.
    """
    contents = await file.read()
    res = analyze_vocal_affect(audio_bytes=contents)
    return {
        "success": True,
        "filename": file.filename,
        "analysis": res
    }


class VocalCuesRequest(BaseModel):
    spoken_text: Optional[str] = None
    pitch_modulation: Optional[float] = None
    rhythm_calmness: Optional[float] = None
    features: Optional[List[float]] = None
    simulated_cues: Optional[Dict[str, Any]] = None


@app.post("/api/ml/analyze-audio-json")
def analyze_audio_json(req: VocalCuesRequest):
    """
    Endpoint for speech text sentiment and acoustic cues evaluation using trained vocal model.
    """
    cues = dict(req.simulated_cues or {})
    if req.spoken_text:
        cues["spoken_text"] = req.spoken_text
    if req.pitch_modulation is not None:
        cues["pitch_modulation"] = req.pitch_modulation
    if req.rhythm_calmness is not None:
        cues["rhythm_calmness"] = req.rhythm_calmness
    res = analyze_vocal_affect(simulated_cues=cues, features=req.features)
    return {
        "success": True,
        "analysis": res
    }


@app.post("/api/ml/predict-ralpa")
def predict_ralpa_progression(req: MultimodalAssessmentRequest):
    # 1. Vision Emotion Inference
    face_score = None
    if req.facial_cues and isinstance(req.facial_cues, dict):
        face_score = req.facial_cues.get('affect_score') or req.facial_cues.get('facial_score')
    if face_score is None and req.raw_features and isinstance(req.raw_features, dict):
        face_score = req.raw_features.get('facial_score')
    
    face_res = analyze_facial_affect(simulated_cues=req.facial_cues) if req.facial_cues else {}
    if face_score is None:
        face_score = face_res.get('affect_score', 80.0)

    # 2. Audio Acoustic Inference
    vocal_score = None
    if req.vocal_cues and isinstance(req.vocal_cues, dict):
        vocal_score = req.vocal_cues.get('vocal_wellness_score') or req.vocal_cues.get('vocal_score')
    if vocal_score is None and req.raw_features and isinstance(req.raw_features, dict):
        vocal_score = req.raw_features.get('vocal_score')
        
    audio_res = analyze_vocal_affect(simulated_cues=req.vocal_cues) if req.vocal_cues else {}
    if vocal_score is None:
        vocal_score = audio_res.get('vocal_wellness_score', 80.0)

    # 3. Multimodal Latent Fusion & RALPA Trajectory Progression
    scores = {
        'questionnaire': req.questionnaire_score,
        'facial': float(face_score),
        'vocal': float(vocal_score),
        'social': req.social_score
    }

    prediction = ralpa.predict_progression(
        resident_id=req.resident_id,
        current_scores=scores,
        history_scores=req.history_scores,
        score_domain=req.score_domain or "wellness",
        raw_features=req.raw_features
    )

    return {
        "success": True,
        "data": {
            **prediction,
            "modality_breakdown": {
                "facial": face_res,
                "vocal": audio_res
            }
        }
    }


@app.post(
    "/api/ml/predict-cognitive",
    response_model=CognitiveAssessmentResponse,
    summary="Evaluate cognitive wellness using fixed ACRF weights and verify ML model availability",
    tags=["Cognitive Wellness"]
)
def predict_cognitive(req: CognitiveAssessmentRequest):
    """
    Evaluates cognitive wellness across the five designated categories:
    - memory (weight 0.25)
    - attention (weight 0.20)
    - orientation (weight 0.20)
    - recall (weight 0.20)
    - reasoning (weight 0.15)
    
    Returns the weighted ACRF score, category contributions, and transparent
    machine-learning status. Non-diagnostic.
    """
    if req.scores is None:
        raise HTTPException(
            status_code=422,
            detail="Category scores must be provided."
        )

    scores_dict = {
        "memory": req.scores.memory,
        "attention": req.scores.attention,
        "orientation": req.scores.orientation,
        "recall": req.scores.recall,
        "reasoning": req.scores.reasoning,
    }

    try:
        result = cognitive_engine.evaluate(
            scores_dict,
            resident_id=req.resident_id,
            age=req.age,
            education_years=req.education_years,
            accuracies=req.accuracies,
            response_times=req.response_times,
            assessment_number=req.assessment_number,
            history=req.history,
        )
    except CognitiveValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return {
        "success": True,
        "data": result
    }


def _require_metabolic_predictor() -> RiskPredictor:
    if metabolic_predictor is None:
        raise HTTPException(status_code=503, detail=metabolic_load_error)
    return metabolic_predictor


@app.post("/api/ml/predict-metabolic", tags=["Metabolic Health"],
          summary="Metabolic risk tiers (low / watch / high) with top reasons. Non-diagnostic.")
def predict_metabolic(req: MetabolicRiskRequest):
    """
    Estimates current-status risk of diabetes, cardiovascular disease and fatty liver.
    Uses the highest input tier whose inputs are complete (home, clinic, extended), and returns
    for each outcome the tier, probability, a plain-language range, the top three reasons,
    suggestions and the inputs that would improve the estimate.
    """
    predictor = _require_metabolic_predictor()
    payload = req.model_dump(exclude_none=True)
    payload.pop("resident_id", None)
    result = predictor.predict_risk(payload)
    return {"success": True, "data": {"resident_id": req.resident_id, **result}}


@app.get("/api/ml/metabolic/model-info", tags=["Metabolic Health"],
         summary="Metabolic model versions, required inputs, thresholds and test performance")
def metabolic_model_info():
    predictor = _require_metabolic_predictor()
    return {"success": True, "data": predictor.manifest}


if __name__ == "__main__":
    import uvicorn  # pyrefly: ignore [missing-import] # type: ignore
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
