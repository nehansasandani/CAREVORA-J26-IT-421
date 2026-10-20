# Emotional wellness risk models & Vocal Affect Models

| File | Task | Output |
|---|---|---|
| `carevora_vocal_model.joblib` | `vocal_emotion_label` (6 classes: `ANG`, `DIS`, `FEA`, `HAP`, `NEU`, `SAD`) | dict: `model` (StandardScaler + calibrated classifier pipeline), `feature_names` (30 PCA components: `pc1` to `pc30`), `classes`, `metrics` (Test Accuracy: **94.94%**, Macro F1: **94.94%**) -> calibrated probability distribution & weighted affective valence |
| `carevora_high_risk_model.joblib` | `high_risk_label` (binary) | dict: `models` (4: 2xLightGBM, LogReg pipeline, HistGB), `features` (149), `threshold` (0.31) -> average `predict_proba(...)[:,1]` of the 4 models, high risk if >= threshold |
| `carevora_trajectory_model.joblib` | `trajectory_label` (3 classes) | dict: `models` (3: 2xLightGBM, LogReg pipeline), `features` (149), `classes` -> average `predict_proba`, argmax -> class |

- **Vocal Model Training Source**: `carevora-ai-service/data/vocal/train.csv` (25,200 samples across 210 speakers, class separation factor SEP=3.0, grounded in CREMA-D normative acoustic parameters).
- **Service Integration**: Loaded directly by [audio_analyzer.py](file:///c:/Users/HP/Downloads/CAREVORA-J26-IT-421-main%20%281%29/CAREVORA-J26-IT-421-main/carevora-ai-service/audio_analyzer.py) and called via `POST /api/ml/analyze-audio` or multimodal RALPA fusion pipeline.
- Synthetic training note: Accuracy reflects the synthetic simulation benchmark setting; not a diagnostic clinical speech classifier.
