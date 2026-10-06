# ============================================================
# CLEAN IMPROVED CNN - FER-2013
# ============================================================

import os
import json
import random
from pathlib import Path

import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt

from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    accuracy_score,
    precision_score,
    recall_score,
    f1_score
)

# ============================================================
# CONFIGURATION
# ============================================================

SEED = int(os.environ.get("SEED", "42"))

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)

BASE_DIR = Path(__file__).resolve().parents[2]

TRAIN_DIR = BASE_DIR / "data" / "raw" / "fer2013_clean" / "train"
TEST_DIR = BASE_DIR / "data" / "raw" / "fer2013_clean" / "test"

MODEL_DIR = (
    BASE_DIR
    / "src"
    / "models"
    / "clean_seed"
    / f"seed{SEED}"
)

RESULT_DIR = (
    BASE_DIR
    / "results"
    / "facial_emotion"
    / "clean_baselines"
    / f"improved_cnn_seed{SEED}"
)

MODEL_DIR.mkdir(parents=True, exist_ok=True)
RESULT_DIR.mkdir(parents=True, exist_ok=True)

MODEL_PATH = MODEL_DIR / "improved_cnn_clean.keras"

IMG_SIZE = (48, 48)
BATCH_SIZE = 32
NUM_CLASSES = 7

VALIDATION_SPLIT = 0.15
EPOCHS = 50

CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise"
]

print("=" * 70)
print("CLEAN IMPROVED CNN - FER-2013")
print("=" * 70)

print(f"Seed              : {SEED}")
print(f"Training directory: {TRAIN_DIR}")
print(f"Test directory    : {TEST_DIR}")
print(f"Model output      : {MODEL_PATH}")
print()


# ============================================================
# CHECK DATASET
# ============================================================

if not TRAIN_DIR.exists():
    raise FileNotFoundError(
        f"Clean training directory not found:\n{TRAIN_DIR}"
    )

if not TEST_DIR.exists():
    raise FileNotFoundError(
        f"Clean test directory not found:\n{TEST_DIR}"
    )


# ============================================================
# LOAD CLEAN TRAINING DATA
# ============================================================

train_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    labels="inferred",
    label_mode="int",
    color_mode="grayscale",
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=True,
    seed=SEED,
    validation_split=VALIDATION_SPLIT,
    subset="training"
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    labels="inferred",
    label_mode="int",
    color_mode="grayscale",
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=True,
    seed=SEED,
    validation_split=VALIDATION_SPLIT,
    subset="validation"
)

test_ds = tf.keras.utils.image_dataset_from_directory(
    TEST_DIR,
    labels="inferred",
    label_mode="int",
    color_mode="grayscale",
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=False
)

print()
print("Class names:")
print(train_ds.class_names)

print()


# ============================================================
# NORMALIZATION + PERFORMANCE
# ============================================================

normalization = tf.keras.layers.Rescaling(1.0 / 255.0)

AUTOTUNE = tf.data.AUTOTUNE

train_ds = train_ds.map(
    lambda x, y: (normalization(x), y),
    num_parallel_calls=AUTOTUNE
)

val_ds = val_ds.map(
    lambda x, y: (normalization(x), y),
    num_parallel_calls=AUTOTUNE
)

test_ds = test_ds.map(
    lambda x, y: (normalization(x), y),
    num_parallel_calls=AUTOTUNE
)

train_ds = train_ds.prefetch(AUTOTUNE)
val_ds = val_ds.prefetch(AUTOTUNE)
test_ds = test_ds.prefetch(AUTOTUNE)


# ============================================================
# CLASS WEIGHTS
# ============================================================

print("=" * 70)
print("CALCULATING CLASS WEIGHTS")
print("=" * 70)

class_counts = {}

for class_name in CLASS_NAMES:
    class_dir = TRAIN_DIR / class_name

    if class_dir.exists():
        count = len([
            f for f in class_dir.iterdir()
            if f.is_file()
        ])
    else:
        count = 0

    class_counts[class_name] = count

print("\nClass distribution:")

for class_name, count in class_counts.items():
    print(f"{class_name:10s}: {count}")

labels_for_weights = []

for class_index, class_name in enumerate(CLASS_NAMES):
    count = class_counts[class_name]
    labels_for_weights.extend([class_index] * count)

labels_for_weights = np.array(labels_for_weights)

classes = np.arange(NUM_CLASSES)

class_weights_array = compute_class_weight(
    class_weight="balanced",
    classes=classes,
    y=labels_for_weights
)

# Use square-root weighting to avoid excessively
# large weights for the minority classes.
class_weights_array = np.sqrt(class_weights_array)

class_weights = {
    int(i): float(weight)
    for i, weight in enumerate(class_weights_array)
}

print("\nClass weights:")

for i, class_name in enumerate(CLASS_NAMES):
    print(
        f"{class_name:10s}: "
        f"{class_weights[i]:.4f}"
    )

print()


# ============================================================
# DATA AUGMENTATION
# ============================================================

data_augmentation = tf.keras.Sequential(
    [
        tf.keras.layers.RandomFlip(
            "horizontal"
        ),

        tf.keras.layers.RandomRotation(
            0.05
        ),

        tf.keras.layers.RandomZoom(
            0.08
        ),

        tf.keras.layers.RandomTranslation(
            height_factor=0.05,
            width_factor=0.05
        )
    ],
    name="data_augmentation"
)


# ============================================================
# BUILD IMPROVED CNN
# ============================================================

def build_improved_cnn():

    inputs = tf.keras.Input(
        shape=(48, 48, 1),
        name="input_image"
    )

    x = data_augmentation(inputs)

    # --------------------------------------------------------
    # BLOCK 1
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        32,
        (3, 3),
        padding="same",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)

    x = tf.keras.layers.Conv2D(
        32,
        (3, 3),
        padding="same",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)

    x = tf.keras.layers.MaxPooling2D(
        pool_size=(2, 2)
    )(x)

    x = tf.keras.layers.Dropout(0.20)(x)

    # --------------------------------------------------------
    # BLOCK 2
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        64,
        (3, 3),
        padding="same",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)

    x = tf.keras.layers.Conv2D(
        64,
        (3, 3),
        padding="same",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)

    x = tf.keras.layers.MaxPooling2D(
        pool_size=(2, 2)
    )(x)

    x = tf.keras.layers.Dropout(0.25)(x)

    # --------------------------------------------------------
    # BLOCK 3
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        128,
        (3, 3),
        padding="same",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)

    x = tf.keras.layers.Conv2D(
        128,
        (3, 3),
        padding="same",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.Activation("relu")(x)

    x = tf.keras.layers.MaxPooling2D(
        pool_size=(2, 2)
    )(x)

    x = tf.keras.layers.Dropout(0.30)(x)

    # --------------------------------------------------------
    # CLASSIFICATION HEAD
    # --------------------------------------------------------

    x = tf.keras.layers.GlobalAveragePooling2D()(x)

    x = tf.keras.layers.Dense(
        128,
        activation="relu",
        kernel_initializer="he_normal"
    )(x)

    x = tf.keras.layers.Dropout(0.35)(x)

    outputs = tf.keras.layers.Dense(
        NUM_CLASSES,
        activation="softmax",
        name="emotion_output"
    )(x)

    model = tf.keras.Model(
        inputs=inputs,
        outputs=outputs,
        name="improved_cnn_clean"
    )

    return model


model = build_improved_cnn()


# ============================================================
# COMPILE
# ============================================================

optimizer = tf.keras.optimizers.AdamW(
    learning_rate=0.001,
    weight_decay=0.0001
)

model.compile(
    optimizer=optimizer,
    loss=tf.keras.losses.SparseCategoricalCrossentropy(),
    metrics=["accuracy"]
)


# ============================================================
# MODEL SUMMARY
# ============================================================

print("=" * 70)
print("MODEL SUMMARY")
print("=" * 70)

model.summary()


# ============================================================
# CALLBACKS
# ============================================================

checkpoint = tf.keras.callbacks.ModelCheckpoint(
    filepath=str(MODEL_PATH),
    monitor="val_loss",
    mode="min",
    save_best_only=True,
    verbose=1
)

early_stopping = tf.keras.callbacks.EarlyStopping(
    monitor="val_loss",
    patience=7,
    restore_best_weights=True,
    verbose=1
)

reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
    monitor="val_loss",
    factor=0.5,
    patience=3,
    min_lr=1e-6,
    verbose=1
)

csv_logger = tf.keras.callbacks.CSVLogger(
    str(RESULT_DIR / "training_history.csv")
)


# ============================================================
# TRAIN
# ============================================================

print()
print("=" * 70)
print("STARTING CLEAN IMPROVED CNN TRAINING")
print("=" * 70)

history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS,
    class_weight=class_weights,
    callbacks=[
        checkpoint,
        early_stopping,
        reduce_lr,
        csv_logger
    ],
    verbose=1
)


# ============================================================
# LOAD BEST MODEL
# ============================================================

print()
print("Loading best saved model...")

best_model = tf.keras.models.load_model(
    MODEL_PATH,
    compile=False
)

best_model.compile(
    optimizer=tf.keras.optimizers.AdamW(
        learning_rate=0.001,
        weight_decay=0.0001
    ),
    loss=tf.keras.losses.SparseCategoricalCrossentropy(),
    metrics=["accuracy"]
)


# ============================================================
# TEST PREDICTIONS
# ============================================================

y_true = []
y_pred = []

for images, labels in test_ds:

    predictions = best_model.predict(
        images,
        verbose=0
    )

    predicted_labels = np.argmax(
        predictions,
        axis=1
    )

    y_true.extend(labels.numpy())
    y_pred.extend(predicted_labels)

y_true = np.array(y_true)
y_pred = np.array(y_pred)


# ============================================================
# METRICS
# ============================================================

accuracy = accuracy_score(
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


# ============================================================
# CLASSIFICATION REPORT
# ============================================================

report = classification_report(
    y_true,
    y_pred,
    target_names=CLASS_NAMES,
    digits=4,
    zero_division=0
)

print()
print("=" * 70)
print("FINAL CLEAN TEST EVALUATION")
print("=" * 70)

print()
print("Classification Report:")
print(report)

print("=" * 70)
print("CLEAN IMPROVED CNN RESULTS")
print("=" * 70)

print(f"Test images       : {len(y_true)}")
print(f"Accuracy          : {accuracy * 100:.2f}%")
print(f"Macro Precision   : {macro_precision:.4f}")
print(f"Macro Recall      : {macro_recall:.4f}")
print(f"Macro F1          : {macro_f1:.4f}")
print(f"Weighted F1       : {weighted_f1:.4f}")


# ============================================================
# CONFUSION MATRIX
# ============================================================

cm = confusion_matrix(
    y_true,
    y_pred
)

plt.figure(figsize=(9, 8))

plt.imshow(
    cm,
    interpolation="nearest"
)

plt.title(
    f"Improved CNN - Clean Test\nSeed {SEED}"
)

plt.colorbar()

plt.xticks(
    np.arange(NUM_CLASSES),
    CLASS_NAMES,
    rotation=45,
    ha="right"
)

plt.yticks(
    np.arange(NUM_CLASSES),
    CLASS_NAMES
)

plt.xlabel("Predicted Label")
plt.ylabel("True Label")

for i in range(NUM_CLASSES):
    for j in range(NUM_CLASSES):

        plt.text(
            j,
            i,
            cm[i, j],
            ha="center",
            va="center"
        )

plt.tight_layout()

plt.savefig(
    RESULT_DIR / "confusion_matrix.png",
    dpi=300,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# ACCURACY CURVE
# ============================================================

plt.figure(figsize=(8, 6))

plt.plot(
    history.history["accuracy"],
    label="Training Accuracy"
)

plt.plot(
    history.history["val_accuracy"],
    label="Validation Accuracy"
)

plt.xlabel("Epoch")
plt.ylabel("Accuracy")

plt.title(
    f"Improved CNN Accuracy - Seed {SEED}"
)

plt.legend()
plt.grid(True)

plt.tight_layout()

plt.savefig(
    RESULT_DIR / "accuracy_curve.png",
    dpi=300,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# LOSS CURVE
# ============================================================

plt.figure(figsize=(8, 6))

plt.plot(
    history.history["loss"],
    label="Training Loss"
)

plt.plot(
    history.history["val_loss"],
    label="Validation Loss"
)

plt.xlabel("Epoch")
plt.ylabel("Loss")

plt.title(
    f"Improved CNN Loss - Seed {SEED}"
)

plt.legend()
plt.grid(True)

plt.tight_layout()

plt.savefig(
    RESULT_DIR / "loss_curve.png",
    dpi=300,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# SAVE CLASSIFICATION REPORT
# ============================================================

with open(
    RESULT_DIR / "classification_report.txt",
    "w",
    encoding="utf-8"
) as f:

    f.write(
        "CLEAN IMPROVED CNN - FER-2013\n"
    )

    f.write(
        f"Seed: {SEED}\n"
    )

    f.write(
        f"Test images: {len(y_true)}\n\n"
    )

    f.write(report)

    f.write("\n\n")

    f.write(
        f"Accuracy: {accuracy:.6f}\n"
    )

    f.write(
        f"Macro Precision: {macro_precision:.6f}\n"
    )

    f.write(
        f"Macro Recall: {macro_recall:.6f}\n"
    )

    f.write(
        f"Macro F1: {macro_f1:.6f}\n"
    )

    f.write(
        f"Weighted F1: {weighted_f1:.6f}\n"
    )


# ============================================================
# SAVE METRICS JSON
# ============================================================

metrics = {
    "model": "Improved CNN",
    "dataset": "FER-2013 clean/de-duplicated",
    "seed": SEED,
    "test_images": int(len(y_true)),
    "accuracy": float(accuracy),
    "macro_precision": float(macro_precision),
    "macro_recall": float(macro_recall),
    "macro_f1": float(macro_f1),
    "weighted_f1": float(weighted_f1),
    "validation_split": VALIDATION_SPLIT,
    "epochs_requested": EPOCHS,
    "epochs_trained": len(
        history.history["loss"]
    ),
    "best_epoch": int(
        np.argmin(
            history.history["val_loss"]
        ) + 1
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
# FINAL OUTPUT
# ============================================================

print()
print("=" * 70)
print("CLEAN IMPROVED CNN TRAINING COMPLETED")
print("=" * 70)

print(f"Seed              : {SEED}")
print(f"Clean test images : {len(y_true)}")
print(f"Accuracy          : {accuracy * 100:.2f}%")
print(f"Macro F1          : {macro_f1:.4f}")
print(f"Weighted F1       : {weighted_f1:.4f}")

print()
print("Best model saved to:")
print(MODEL_PATH)

print()
print("Results saved to:")
print(RESULT_DIR)

print("=" * 70)