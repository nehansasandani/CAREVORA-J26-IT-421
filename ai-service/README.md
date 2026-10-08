# Carevora AI service

## Facial emotion training

The FER-2013 clean/de-duplicated dataset is used by the reproducible training
scripts in `src/models/`.

### Corrected CNN baseline

Run the corrected baseline for any supported seed from the `ai-service`
directory:

```powershell
$env:SEED="42"
python src/models/train_cnn_clean.py
```

The script uses a reproducible shuffled training/validation split, calculates
class weights from the training subset only, evaluates once on the held-out
test set, and writes the model and metrics under the seed-specific output
directories.

### Selected improved CNN

The improved model is trained with:

```powershell
$env:SEED="42"
python src/models/train_improved_cnn_clean.py
```

Use `SEED=42`, `SEED=43`, or `SEED=44` to reproduce the committed runs.

### Research artifacts

- `results/facial_emotion/clean_baselines/cnn_seed*` contains corrected
  baseline metrics, reports, class weights, training histories, and plots.
- `results/facial_emotion/clean_baselines/improved_cnn_seed*` contains the
  selected improved-CNN metrics, reports, training histories, and plots.
- `results/facial_emotion/old_buggy_baseline/` preserves the earlier baseline
  results for transparent comparison with the corrected split.
- `src/models/clean_seed/` contains the selected seed-specific `.keras`
  checkpoints.

The dependency versions required by these scripts are listed in
`requirements.txt`.

## Voice emotion training

The CREMA-D voice pipeline uses actor-independent train, validation, and test
splits with log-Mel spectrogram features. The reproducible scripts are in
`src/voice/`, and the seed-specific CNN checkpoints and research summaries are
stored under `src/models/voice/` and `results/voice_emotion/`.

Feature arrays under `data/voice_features/` are tracked with Git LFS because
the generated NumPy files are larger than GitHub's regular-file limit.