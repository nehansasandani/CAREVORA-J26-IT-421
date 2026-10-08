# ============================================================
# Voice Emotion Recognition - CNN Baseline
# Seed 44
# Dataset: CREMA-D
# Feature: Log-Mel Spectrogram
# Split: Speaker/Actor Independent
# ============================================================

import os
import random
import json
from pathlib import Path

import numpy as np
import tensorflow as tf

from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    classification_report,
    confusion_matrix
)


# ============================================================
# CONFIGURATION
# ============================================================

SEED = 44

BATCH_SIZE = 32
EPOCHS = 50
LEARNING_RATE = 0.0005

NUM_CLASSES = 6

CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad"
]

BASE_DIR = Path("ai-service")

FEATURE_DIR = BASE_DIR / "data" / "voice_features"

# Seed 43 results will automatically be saved here
RESULT_DIR = (
    BASE_DIR
    / "results"
    / "voice_emotion"
    / "cnn_baseline"
    / f"seed{SEED}"
)

MODEL_DIR = (
    BASE_DIR
    / "src"
    / "models"
    / "voice"
)

RESULT_DIR.mkdir(parents=True, exist_ok=True)
MODEL_DIR.mkdir(parents=True, exist_ok=True)


# ============================================================
# REPRODUCIBILITY
# ============================================================

os.environ["PYTHONHASHSEED"] = str(SEED)

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)


# ============================================================
# GPU CONFIGURATION
# ============================================================

gpus = tf.config.list_physical_devices("GPU")

if gpus:
    print(f"GPU detected: {len(gpus)}")

    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(
                gpu,
                True
            )

    except Exception as e:
        print("GPU configuration warning:", e)

else:
    print("GPU not detected. Using CPU.")


# ============================================================
# LOAD DATA
# ============================================================

print("\n" + "=" * 70)
print("LOADING VOICE FEATURES")
print("=" * 70)

X_train = np.load(
    FEATURE_DIR / "train_logmel.npy"
)

y_train = np.load(
    FEATURE_DIR / "train_labels.npy"
)

X_val = np.load(
    FEATURE_DIR / "validation_logmel.npy"
)

y_val = np.load(
    FEATURE_DIR / "validation_labels.npy"
)

X_test = np.load(
    FEATURE_DIR / "test_logmel.npy"
)

y_test = np.load(
    FEATURE_DIR / "test_labels.npy"
)


print("Original shapes:")

print("X_train:", X_train.shape)
print("y_train:", y_train.shape)

print("X_val  :", X_val.shape)
print("y_val  :", y_val.shape)

print("X_test :", X_test.shape)
print("y_test :", y_test.shape)


# ============================================================
# ADD CHANNEL DIMENSION
# ============================================================

# Original:
# (samples, mel_bins, time)

# CNN input:
# (samples, mel_bins, time, channels)

X_train = X_train[..., np.newaxis]

X_val = X_val[..., np.newaxis]

X_test = X_test[..., np.newaxis]


print("\nAfter adding channel dimension:")

print("X_train:", X_train.shape)
print("X_val  :", X_val.shape)
print("X_test :", X_test.shape)


# ============================================================
# NORMALIZATION
# ============================================================

# Log-Mel values are approximately [-80, 0] dB.
# Convert them to approximately [0, 1].

X_train = np.clip(
    (X_train + 80.0) / 80.0,
    0.0,
    1.0
)

X_val = np.clip(
    (X_val + 80.0) / 80.0,
    0.0,
    1.0
)

X_test = np.clip(
    (X_test + 80.0) / 80.0,
    0.0,
    1.0
)


print("\nNormalized feature statistics:")

print("Train min :", X_train.min())
print("Train max :", X_train.max())
print("Train mean:", X_train.mean())
print("Train std :", X_train.std())


# ============================================================
# CLASS WEIGHTS
# ============================================================

classes = np.unique(y_train)

class_weights_array = compute_class_weight(
    class_weight="balanced",
    classes=classes,
    y=y_train
)

class_weights = {
    int(cls): float(weight)
    for cls, weight in zip(
        classes,
        class_weights_array
    )
}


print("\nClass weights:")

for cls, weight in class_weights.items():

    print(
        f"{CLASS_NAMES[cls]:10s}: {weight:.4f}"
    )


# ============================================================
# CREATE DATASETS
# ============================================================

train_dataset = tf.data.Dataset.from_tensor_slices(
    (X_train, y_train)
)

train_dataset = train_dataset.shuffle(
    buffer_size=len(X_train),
    seed=SEED,
    reshuffle_each_iteration=True
)

train_dataset = train_dataset.batch(
    BATCH_SIZE
).prefetch(
    tf.data.AUTOTUNE
)


val_dataset = tf.data.Dataset.from_tensor_slices(
    (X_val, y_val)
)

val_dataset = val_dataset.batch(
    BATCH_SIZE
).prefetch(
    tf.data.AUTOTUNE
)


test_dataset = tf.data.Dataset.from_tensor_slices(
    (X_test, y_test)
)

test_dataset = test_dataset.batch(
    BATCH_SIZE
).prefetch(
    tf.data.AUTOTUNE
)


# ============================================================
# CNN BASELINE MODEL
# ============================================================

def build_cnn_baseline():

    inputs = tf.keras.Input(
        shape=(128, 174, 1),
        name="logmel_input"
    )

    x = tf.keras.layers.Conv2D(
        32,
        kernel_size=(3, 3),
        padding="same",
        activation="relu"
    )(inputs)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.MaxPooling2D(
        pool_size=(2, 2)
    )(x)


    x = tf.keras.layers.Conv2D(
        64,
        kernel_size=(3, 3),
        padding="same",
        activation="relu"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.MaxPooling2D(
        pool_size=(2, 2)
    )(x)


    x = tf.keras.layers.Conv2D(
        128,
        kernel_size=(3, 3),
        padding="same",
        activation="relu"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.MaxPooling2D(
        pool_size=(2, 2)
    )(x)


    x = tf.keras.layers.GlobalAveragePooling2D()(x)


    x = tf.keras.layers.Dense(
        128,
        activation="relu"
    )(x)


    x = tf.keras.layers.Dropout(
        0.4
    )(x)


    outputs = tf.keras.layers.Dense(
        NUM_CLASSES,
        activation="softmax",
        name="emotion_output"
    )(x)


    model = tf.keras.Model(
        inputs=inputs,
        outputs=outputs,
        name="CNN_Baseline"
    )


    return model


model = build_cnn_baseline()


# ============================================================
# COMPILE
# ============================================================

optimizer = tf.keras.optimizers.Adam(
    learning_rate=LEARNING_RATE
)

model.compile(
    optimizer=optimizer,
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)


print("\n" + "=" * 70)
print("MODEL SUMMARY")
print("=" * 70)

model.summary()


# ============================================================
# CALLBACKS
# ============================================================

model_path = (
    MODEL_DIR
    / f"voice_cnn_baseline_seed{SEED}.keras"
)


callbacks = [

    tf.keras.callbacks.ModelCheckpoint(
        filepath=model_path,
        monitor="val_loss",
        save_best_only=True,
        verbose=1
    ),

    tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",
        patience=8,
        restore_best_weights=True,
        verbose=1
    ),

    tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=3,
        min_lr=1e-6,
        verbose=1
    )

]


# ============================================================
# TRAINING
# ============================================================

print("\n" + "=" * 70)
print("TRAINING CNN BASELINE - SEED 43")
print("=" * 70)

print(f"Seed          : {SEED}")
print(f"Batch size    : {BATCH_SIZE}")
print(f"Epochs        : {EPOCHS}")
print(f"Learning rate : {LEARNING_RATE}")


history = model.fit(
    train_dataset,
    validation_data=val_dataset,
    epochs=EPOCHS,
    class_weight=class_weights,
    callbacks=callbacks,
    verbose=1
)


# ============================================================
# LOAD BEST MODEL
# ============================================================

print("\nLoading best model...")

model = tf.keras.models.load_model(
    model_path
)


# ============================================================
# TEST PREDICTIONS
# ============================================================

print("\n" + "=" * 70)
print("TESTING")
print("=" * 70)


probabilities = model.predict(
    test_dataset,
    verbose=1
)


predictions = np.argmax(
    probabilities,
    axis=1
)


# ============================================================
# METRICS
# ============================================================

test_accuracy = accuracy_score(
    y_test,
    predictions
)

macro_f1 = f1_score(
    y_test,
    predictions,
    average="macro"
)

weighted_f1 = f1_score(
    y_test,
    predictions,
    average="weighted"
)


print("\n" + "=" * 70)
print("CNN BASELINE TEST RESULTS - SEED 43")
print("=" * 70)

print(
    f"Test Accuracy : "
    f"{test_accuracy * 100:.2f}%"
)

print(
    f"Macro F1      : "
    f"{macro_f1:.4f}"
)

print(
    f"Weighted F1   : "
    f"{weighted_f1:.4f}"
)


# ============================================================
# CLASSIFICATION REPORT
# ============================================================

report = classification_report(
    y_test,
    predictions,
    target_names=CLASS_NAMES,
    digits=4
)


print("\nClassification Report:")

print(report)


# ============================================================
# CONFUSION MATRIX
# ============================================================

cm = confusion_matrix(
    y_test,
    predictions
)


print("\nConfusion Matrix:")

print(cm)


# ============================================================
# SAVE CONFUSION MATRIX
# ============================================================

np.save(
    RESULT_DIR / "confusion_matrix.npy",
    cm
)


# ============================================================
# SAVE CLASSIFICATION REPORT
# ============================================================

with open(
    RESULT_DIR / "classification_report.txt",
    "w",
    encoding="utf-8"
) as f:

    f.write(report)


# ============================================================
# TRAINING HISTORY
# ============================================================

history_data = {
    key: [
        float(value)
        for value in values
    ]
    for key, values in history.history.items()
}


with open(
    RESULT_DIR / "history.json",
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        history_data,
        f,
        indent=4
    )


# ============================================================
# FINAL METRICS
# ============================================================

metrics = {

    "model": "CNN Baseline",

    "dataset": "CREMA-D",

    "feature": "Log-Mel Spectrogram",

    "split_strategy": "Actor-independent",

    "seed": SEED,

    "train_samples": int(
        len(y_train)
    ),

    "validation_samples": int(
        len(y_val)
    ),

    "test_samples": int(
        len(y_test)
    ),

    "test_accuracy": float(
        test_accuracy
    ),

    "macro_f1": float(
        macro_f1
    ),

    "weighted_f1": float(
        weighted_f1
    ),

    "best_epoch": int(
        np.argmin(
            history.history["val_loss"]
        ) + 1
    ),

    "best_validation_loss": float(
        np.min(
            history.history["val_loss"]
        )
    ),

    "best_validation_accuracy": float(
        np.max(
            history.history["val_accuracy"]
        )
    ),

    "epochs_trained": len(
        history.history["loss"]
    )

}


with open(
    RESULT_DIR / "metrics.json",
    "w",
    encoding="utf-8"
) as f:

    json.dump(
        metrics,
        f,
        indent=4
    )


# ============================================================
# COMPLETION
# ============================================================

print("\n" + "=" * 70)
print("TRAINING COMPLETED - SEED 43")
print("=" * 70)

print(
    f"Best Epoch              : "
    f"{metrics['best_epoch']}"
)

print(
    f"Best Validation Accuracy: "
    f"{metrics['best_validation_accuracy'] * 100:.2f}%"
)

print(
    f"Test Accuracy           : "
    f"{test_accuracy * 100:.2f}%"
)

print(
    f"Macro F1                : "
    f"{macro_f1:.4f}"
)

print(
    f"Weighted F1             : "
    f"{weighted_f1:.4f}"
)

print("\nSaved model:")

print(model_path)

print("\nSaved results:")

print(RESULT_DIR)

print("\n" + "=" * 70)
print("DONE")
print("=" * 70)