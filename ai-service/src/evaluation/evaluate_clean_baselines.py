import os
from pathlib import Path

import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt

from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
)


# ============================================================
# PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parents[2]

CLEAN_TEST_DIR = (
    BASE_DIR
    / "data"
    / "raw"
    / "fer2013_clean"
    / "test"
)

MODEL_DIR = (
    BASE_DIR
    / "src"
    / "models"
)

RESULT_DIR = (
    BASE_DIR
    / "results"
    / "facial_emotion"
    / "clean_baselines"
)

RESULT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


# ============================================================
# CONFIGURATION
# ============================================================

IMG_SIZE = 48
BATCH_SIZE = 64

CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise",
]


MODEL_PATHS = {
    "CNN_Baseline": MODEL_DIR / "cnn_baseline.keras",
    "Improved_CNN": MODEL_DIR / "improved_cnn.keras",
}


# ============================================================
# HEADER
# ============================================================

print("=" * 70)
print("CAREVORA - CLEAN BASELINE EVALUATION")
print("=" * 70)

print(f"Clean test directory : {CLEAN_TEST_DIR}")
print(f"Image size           : {IMG_SIZE}x{IMG_SIZE}")
print(f"Color mode           : grayscale")
print(f"Classes              : {CLASS_NAMES}")


# ============================================================
# CHECK PATHS
# ============================================================

if not CLEAN_TEST_DIR.exists():
    raise FileNotFoundError(
        f"Clean test directory not found:\n{CLEAN_TEST_DIR}"
    )

for model_name, model_path in MODEL_PATHS.items():

    if not model_path.exists():
        raise FileNotFoundError(
            f"{model_name} model not found:\n{model_path}"
        )


# ============================================================
# LOAD CLEAN TEST DATASET
# ============================================================

print("\nLoading clean test dataset...")

test_ds = tf.keras.utils.image_dataset_from_directory(
    CLEAN_TEST_DIR,

    labels="inferred",

    label_mode="int",

    class_names=CLASS_NAMES,

    color_mode="grayscale",

    image_size=(
        IMG_SIZE,
        IMG_SIZE
    ),

    batch_size=BATCH_SIZE,

    shuffle=False,
)


# ============================================================
# NORMALIZATION
# ============================================================

def normalize_images(images, labels):

    images = tf.cast(
        images,
        tf.float32
    ) / 255.0

    return images, labels


test_ds = test_ds.map(
    normalize_images,
    num_parallel_calls=tf.data.AUTOTUNE
)

test_ds = test_ds.prefetch(
    tf.data.AUTOTUNE
)


# ============================================================
# GET TRUE LABELS
# ============================================================

print("\nExtracting true labels...")

y_true = np.concatenate(
    [
        labels.numpy()
        for _, labels in test_ds
    ]
)


print(f"Clean test images : {len(y_true)}")


# ============================================================
# EVALUATION FUNCTION
# ============================================================

def evaluate_model(
    model_name,
    model_path
):

    print("\n")
    print("=" * 70)
    print(f"EVALUATING: {model_name}")
    print("=" * 70)

    print(f"\nLoading model:")
    print(model_path)

    model = tf.keras.models.load_model(
        model_path,
        compile=False
    )

    print(
        f"\nModel input shape: {model.input_shape}"
    )

    # --------------------------------------------------------
    # Verify expected input shape
    # --------------------------------------------------------

    expected_shape = (
        None,
        IMG_SIZE,
        IMG_SIZE,
        1
    )

    if model.input_shape != expected_shape:

        raise ValueError(
            f"{model_name} has unexpected input shape.\n"
            f"Expected: {expected_shape}\n"
            f"Found:    {model.input_shape}"
        )

    # --------------------------------------------------------
    # Compile only for loss calculation
    # --------------------------------------------------------

    model.compile(
        optimizer="adam",
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )

    # --------------------------------------------------------
    # Evaluate
    # --------------------------------------------------------

    print("\nRunning model evaluation...")

    loss, accuracy = model.evaluate(
        test_ds,
        verbose=1
    )

    # --------------------------------------------------------
    # Predictions
    # --------------------------------------------------------

    print("\nGenerating predictions...")

    probabilities = model.predict(
        test_ds,
        verbose=1
    )

    y_pred = np.argmax(
        probabilities,
        axis=1
    )

    # --------------------------------------------------------
    # Metrics
    # --------------------------------------------------------

    accuracy_score_value = accuracy_score(
        y_true,
        y_pred
    )

    macro_precision = precision_score(
        y_true,
        y_pred,
        average="macro",
        zero_division=0
    )

    macro_recall = recall_score(
        y_true,
        y_pred,
        average="macro",
        zero_division=0
    )

    macro_f1 = f1_score(
        y_true,
        y_pred,
        average="macro",
        zero_division=0
    )

    weighted_f1 = f1_score(
        y_true,
        y_pred,
        average="weighted",
        zero_division=0
    )

    # --------------------------------------------------------
    # Print results
    # --------------------------------------------------------

    print("\n")
    print("-" * 70)
    print(f"{model_name} - CLEAN TEST RESULTS")
    print("-" * 70)

    print(
        f"Test Loss           : {loss:.4f}"
    )

    print(
        f"Accuracy            : {accuracy_score_value * 100:.2f}%"
    )

    print(
        f"Macro Precision     : {macro_precision:.4f}"
    )

    print(
        f"Macro Recall        : {macro_recall:.4f}"
    )

    print(
        f"Macro F1            : {macro_f1:.4f}"
    )

    print(
        f"Weighted F1         : {weighted_f1:.4f}"
    )

    # --------------------------------------------------------
    # Classification report
    # --------------------------------------------------------

    report = classification_report(
        y_true,
        y_pred,
        target_names=CLASS_NAMES,
        digits=4,
        zero_division=0
    )

    print("\nClassification Report:")
    print(report)

    # --------------------------------------------------------
    # Save classification report
    # --------------------------------------------------------

    report_path = (
        RESULT_DIR
        / f"{model_name.lower()}_classification_report.txt"
    )

    with open(
        report_path,
        "w",
        encoding="utf-8"
    ) as f:

        f.write(
            f"CAREVORA - {model_name}\n"
        )

        f.write(
            "Clean FER-2013 Test Evaluation\n"
        )

        f.write(
            f"Test images: {len(y_true)}\n\n"
        )

        f.write(
            f"Loss: {loss:.4f}\n"
        )

        f.write(
            f"Accuracy: {accuracy_score_value:.4f}\n"
        )

        f.write(
            f"Macro Precision: {macro_precision:.4f}\n"
        )

        f.write(
            f"Macro Recall: {macro_recall:.4f}\n"
        )

        f.write(
            f"Macro F1: {macro_f1:.4f}\n"
        )

        f.write(
            f"Weighted F1: {weighted_f1:.4f}\n\n"
        )

        f.write(
            report
        )

    # --------------------------------------------------------
    # Confusion matrix
    # --------------------------------------------------------

    cm = confusion_matrix(
        y_true,
        y_pred
    )

    plt.figure(
        figsize=(8, 7)
    )

    plt.imshow(
        cm,
        interpolation="nearest"
    )

    plt.title(
        f"{model_name} - Clean Test Confusion Matrix"
    )

    plt.colorbar()

    plt.xticks(
        range(len(CLASS_NAMES)),
        CLASS_NAMES,
        rotation=45
    )

    plt.yticks(
        range(len(CLASS_NAMES)),
        CLASS_NAMES
    )

    plt.xlabel(
        "Predicted Label"
    )

    plt.ylabel(
        "True Label"
    )

    # Add numbers to cells
    for i in range(len(CLASS_NAMES)):

        for j in range(len(CLASS_NAMES)):

            plt.text(
                j,
                i,
                cm[i, j],
                ha="center",
                va="center"
            )

    plt.tight_layout()

    cm_path = (
        RESULT_DIR
        / f"{model_name.lower()}_confusion_matrix.png"
    )

    plt.savefig(
        cm_path,
        dpi=300,
        bbox_inches="tight"
    )

    plt.close()

    # --------------------------------------------------------
    # Return metrics
    # --------------------------------------------------------

    return {
        "model": model_name,
        "test_images": int(len(y_true)),
        "loss": float(loss),
        "accuracy": float(accuracy_score_value),
        "macro_precision": float(macro_precision),
        "macro_recall": float(macro_recall),
        "macro_f1": float(macro_f1),
        "weighted_f1": float(weighted_f1),
        "report_path": str(report_path),
        "confusion_matrix_path": str(cm_path),
    }


# ============================================================
# RUN BOTH MODELS
# ============================================================

cnn_results = evaluate_model(
    "CNN_Baseline",
    MODEL_PATHS["CNN_Baseline"]
)

improved_results = evaluate_model(
    "Improved_CNN",
    MODEL_PATHS["Improved_CNN"]
)


# ============================================================
# FINAL COMPARISON
# ============================================================

print("\n")
print("=" * 70)
print("FINAL CLEAN TEST COMPARISON")
print("=" * 70)

print(
    f"{'Model':<20}"
    f"{'Accuracy':>12}"
    f"{'Macro F1':>12}"
    f"{'Weighted F1':>15}"
)

print("-" * 70)

for result in [
    cnn_results,
    improved_results
]:

    print(
        f"{result['model']:<20}"
        f"{result['accuracy'] * 100:>11.2f}%"
        f"{result['macro_f1']:>12.4f}"
        f"{result['weighted_f1']:>15.4f}"
    )

print("=" * 70)

print("\nResults saved to:")
print(RESULT_DIR)