"""
Carevora - Clean FER-2013 CNN Baseline

Purpose:
    Retrain the original CNN Baseline using the de-duplicated
    FER-2013 training dataset.

Clean dataset:
    ai-service/data/raw/fer2013_clean/

Evaluation:
    Clean held-out test set only.

Classes:
    angry
    disgust
    fear
    happy
    neutral
    sad
    surprise
"""

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
    f1_score,
)

from tensorflow.keras import layers, models
from tensorflow.keras.callbacks import (
    EarlyStopping,
    ModelCheckpoint,
    ReduceLROnPlateau,
    CSVLogger,
)
from tensorflow.keras.optimizers import Adam


# ============================================================
# 1. REPRODUCIBILITY
# ============================================================

SEED = int(os.environ.get("SEED", "42"))

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)


# ============================================================
# 2. PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parents[2]

DATA_DIR = BASE_DIR / "data" / "raw" / "fer2013_clean"

TRAIN_DIR = DATA_DIR / "train"
TEST_DIR = DATA_DIR / "test"

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
    / f"cnn_seed{SEED}"
)

MODEL_DIR.mkdir(
    parents=True,
    exist_ok=True
)

RESULT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


# ============================================================
# 3. CONFIGURATION
# ============================================================

CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise",
]

NUM_CLASSES = len(CLASS_NAMES)

IMG_SIZE = 48

BATCH_SIZE = 32

VALIDATION_SPLIT = 0.15

EPOCHS = 30

LEARNING_RATE = 0.001

DROPOUT_1 = 0.25
DROPOUT_2 = 0.25
DROPOUT_3 = 0.30
DENSE_DROPOUT = 0.40


# ============================================================
# 4. START
# ============================================================

print("=" * 70)
print("CLEAN FER-2013 - CNN BASELINE")
print("=" * 70)

print(f"TensorFlow version : {tf.__version__}")
print(f"Seed               : {SEED}")
print(f"Training directory : {TRAIN_DIR}")
print(f"Testing directory  : {TEST_DIR}")
print(f"Image size         : {IMG_SIZE} x {IMG_SIZE}")
print(f"Batch size         : {BATCH_SIZE}")
print(f"Epochs             : {EPOCHS}")


# ============================================================
# 5. DATASET CHECK
# ============================================================

print("\nChecking clean dataset structure...")

if not TRAIN_DIR.exists():
    raise FileNotFoundError(
        f"Training directory not found:\n{TRAIN_DIR}"
    )

if not TEST_DIR.exists():
    raise FileNotFoundError(
        f"Testing directory not found:\n{TEST_DIR}"
    )


for class_name in CLASS_NAMES:

    train_class_dir = TRAIN_DIR / class_name
    test_class_dir = TEST_DIR / class_name

    if not train_class_dir.exists():
        raise FileNotFoundError(
            f"Missing training class:\n{train_class_dir}"
        )

    if not test_class_dir.exists():
        raise FileNotFoundError(
            f"Missing testing class:\n{test_class_dir}"
        )


print("Dataset structure check: PASSED")


# ============================================================
# 6. COUNT TRAINING IMAGES
# ============================================================

print("\nClean training dataset distribution:")

train_counts = []

for class_name in CLASS_NAMES:

    class_dir = TRAIN_DIR / class_name

    image_count = len(
        [
            file
            for file in class_dir.iterdir()
            if file.is_file()
        ]
    )

    train_counts.append(image_count)

    print(
        f"{class_name:10s}: "
        f"{image_count}"
    )


train_counts = np.array(
    train_counts,
    dtype=np.int64
)


# ============================================================
# 7. CREATE TRAINING DATASET
# ============================================================

print("\nLoading clean training dataset...")

train_ds = tf.keras.utils.image_dataset_from_directory(

    TRAIN_DIR,

    labels="inferred",

    label_mode="int",

    class_names=CLASS_NAMES,

    color_mode="grayscale",

    image_size=(
        IMG_SIZE,
        IMG_SIZE
    ),

    batch_size=BATCH_SIZE,

    validation_split=VALIDATION_SPLIT,

    subset="training",

    seed=SEED,

    shuffle=True,
)


# ============================================================
# 8. CREATE VALIDATION DATASET
# ============================================================

print("\nLoading clean validation dataset...")

val_ds = tf.keras.utils.image_dataset_from_directory(

    TRAIN_DIR,

    labels="inferred",

    label_mode="int",

    class_names=CLASS_NAMES,

    color_mode="grayscale",

    image_size=(
        IMG_SIZE,
        IMG_SIZE
    ),

    batch_size=BATCH_SIZE,

    validation_split=VALIDATION_SPLIT,

    subset="validation",

    seed=SEED,

    shuffle=False,
)


# ============================================================
# 9. CREATE CLEAN TEST DATASET
# ============================================================

print("\nLoading clean test dataset...")

test_ds = tf.keras.utils.image_dataset_from_directory(

    TEST_DIR,

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
# 10. NORMALIZATION
# ============================================================

def normalize_images(images, labels):

    images = tf.cast(
        images,
        tf.float32
    ) / 255.0

    return images, labels


train_ds = train_ds.map(
    normalize_images,
    num_parallel_calls=tf.data.AUTOTUNE
)

val_ds = val_ds.map(
    normalize_images,
    num_parallel_calls=tf.data.AUTOTUNE
)

test_ds = test_ds.map(
    normalize_images,
    num_parallel_calls=tf.data.AUTOTUNE
)


# ============================================================
# 11. PREFETCH
# ============================================================

AUTOTUNE = tf.data.AUTOTUNE

train_ds = train_ds.prefetch(
    AUTOTUNE
)

val_ds = val_ds.prefetch(
    AUTOTUNE
)

test_ds = test_ds.prefetch(
    AUTOTUNE
)


# ============================================================
# 12. CLASS WEIGHTS
# ============================================================

print("\nCalculating class weights...")

class_indices = np.concatenate(
    [
        np.full(
            count,
            class_index
        )
        for class_index, count
        in enumerate(train_counts)
    ]
)


class_weights_array = compute_class_weight(

    class_weight="balanced",

    classes=np.arange(
        NUM_CLASSES
    ),

    y=class_indices,
)


class_weights = {
    index: float(weight)
    for index, weight
    in enumerate(
        class_weights_array
    )
}


print("\nClass weights:")

for index, class_name in enumerate(
    CLASS_NAMES
):

    print(
        f"{class_name:10s}: "
        f"{class_weights[index]:.4f}"
    )


# ============================================================
# 13. BUILD CNN BASELINE
# ============================================================

print("\nBuilding CNN Baseline model...")


model = models.Sequential(

    [

        layers.Input(
            shape=(
                IMG_SIZE,
                IMG_SIZE,
                1
            ),
            name="input_image"
        ),


        # ----------------------------------------------------
        # CNN BLOCK 1
        # ----------------------------------------------------

        layers.Conv2D(
            32,
            (3, 3),
            padding="same",
            name="conv2d"
        ),

        layers.BatchNormalization(
            name="batch_normalization"
        ),

        layers.ReLU(
            name="re_lu"
        ),

        layers.MaxPooling2D(
            (2, 2),
            name="max_pooling2d"
        ),

        layers.Dropout(
            DROPOUT_1,
            name="dropout"
        ),


        # ----------------------------------------------------
        # CNN BLOCK 2
        # ----------------------------------------------------

        layers.Conv2D(
            64,
            (3, 3),
            padding="same",
            name="conv2d_1"
        ),

        layers.BatchNormalization(
            name="batch_normalization_1"
        ),

        layers.ReLU(
            name="re_lu_1"
        ),

        layers.MaxPooling2D(
            (2, 2),
            name="max_pooling2d_1"
        ),

        layers.Dropout(
            DROPOUT_2,
            name="dropout_1"
        ),


        # ----------------------------------------------------
        # CNN BLOCK 3
        # ----------------------------------------------------

        layers.Conv2D(
            128,
            (3, 3),
            padding="same",
            name="conv2d_2"
        ),

        layers.BatchNormalization(
            name="batch_normalization_2"
        ),

        layers.ReLU(
            name="re_lu_2"
        ),

        layers.MaxPooling2D(
            (2, 2),
            name="max_pooling2d_2"
        ),

        layers.Dropout(
            DROPOUT_3,
            name="dropout_2"
        ),


        # ----------------------------------------------------
        # GLOBAL AVERAGE POOLING
        # ----------------------------------------------------

        layers.GlobalAveragePooling2D(
            name="global_average_pooling2d"
        ),


        # ----------------------------------------------------
        # DENSE LAYER
        # ----------------------------------------------------

        layers.Dense(
            128,
            activation="relu",
            name="dense"
        ),

        layers.Dropout(
            DENSE_DROPOUT,
            name="dropout_3"
        ),


        # ----------------------------------------------------
        # OUTPUT
        # ----------------------------------------------------

        layers.Dense(
            NUM_CLASSES,
            activation="softmax",
            name="predictions"
        )

    ],

    name="CNN_Baseline"
)


# ============================================================
# 14. COMPILE MODEL
# ============================================================

model.compile(

    optimizer=Adam(
        learning_rate=LEARNING_RATE
    ),

    loss=(
        "sparse_categorical_crossentropy"
    ),

    metrics=[
        "accuracy"
    ],
)


print("\nModel summary:")

model.summary()


# ============================================================
# 15. CALLBACKS
# ============================================================

MODEL_PATH = (
    MODEL_DIR
    / "cnn_baseline_clean.keras"
)


CHECKPOINT = ModelCheckpoint(

    MODEL_PATH,

    monitor="val_loss",

    save_best_only=True,

    mode="min",

    verbose=1,
)


EARLY_STOPPING = EarlyStopping(

    monitor="val_loss",

    patience=5,

    restore_best_weights=True,

    mode="min",

    verbose=1,
)


REDUCE_LR = ReduceLROnPlateau(

    monitor="val_loss",

    factor=0.5,

    patience=2,

    min_lr=1e-6,

    mode="min",

    verbose=1,
)


CSV_LOGGER = CSVLogger(

    RESULT_DIR
    / "training_history.csv"
)


# ============================================================
# 16. TRAIN MODEL
# ============================================================

print("\n")
print("=" * 70)
print("STARTING CLEAN CNN BASELINE TRAINING")
print("=" * 70)


history = model.fit(

    train_ds,

    validation_data=val_ds,

    epochs=EPOCHS,

    class_weight=class_weights,

    callbacks=[
        CHECKPOINT,
        EARLY_STOPPING,
        REDUCE_LR,
        CSV_LOGGER,
    ],

    verbose=1,
)


# ============================================================
# 17. LOAD BEST MODEL
# ============================================================

print("\nLoading best saved model...")

best_model = tf.keras.models.load_model(
    MODEL_PATH
)


# ============================================================
# 18. FINAL TEST PREDICTION
# ============================================================

print("\n")
print("=" * 70)
print("FINAL CLEAN TEST EVALUATION")
print("=" * 70)


y_true = []

y_pred = []

y_prob = []


for images, labels in test_ds:

    probabilities = best_model.predict(
        images,
        verbose=0
    )

    predictions = np.argmax(
        probabilities,
        axis=1
    )

    y_true.extend(
        labels.numpy()
    )

    y_pred.extend(
        predictions
    )

    y_prob.extend(
        probabilities
    )


y_true = np.array(
    y_true
)

y_pred = np.array(
    y_pred
)

y_prob = np.array(
    y_prob
)


# ============================================================
# 19. METRICS
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

weighted_precision = precision_score(
    y_true,
    y_pred,
    average="weighted",
    zero_division=0
)

weighted_recall = recall_score(
    y_true,
    y_pred,
    average="weighted",
    zero_division=0
)

weighted_f1 = f1_score(
    y_true,
    y_pred,
    average="weighted",
    zero_division=0
)


# ============================================================
# 20. CLASSIFICATION REPORT
# ============================================================

report = classification_report(

    y_true,

    y_pred,

    target_names=CLASS_NAMES,

    digits=4,

    zero_division=0,
)


print("\nClassification Report:")
print(report)


print("=" * 70)
print("CLEAN CNN BASELINE RESULTS")
print("=" * 70)

print(
    f"Test images       : {len(y_true)}"
)

print(
    f"Accuracy          : "
    f"{accuracy * 100:.2f}%"
)

print(
    f"Macro Precision   : "
    f"{macro_precision:.4f}"
)

print(
    f"Macro Recall      : "
    f"{macro_recall:.4f}"
)

print(
    f"Macro F1          : "
    f"{macro_f1:.4f}"
)

print(
    f"Weighted F1       : "
    f"{weighted_f1:.4f}"
)


# ============================================================
# 21. SAVE CLASSIFICATION REPORT
# ============================================================

report_path = (
    RESULT_DIR
    / "classification_report.txt"
)


with open(
    report_path,
    "w",
    encoding="utf-8"
) as file:

    file.write(
        "CLEAN FER-2013 CNN BASELINE\n"
    )

    file.write(
        f"Seed: {SEED}\n"
    )

    file.write(
        f"Test Images: {len(y_true)}\n\n"
    )

    file.write(
        f"Accuracy: {accuracy:.6f}\n"
    )

    file.write(
        f"Macro Precision: "
        f"{macro_precision:.6f}\n"
    )

    file.write(
        f"Macro Recall: "
        f"{macro_recall:.6f}\n"
    )

    file.write(
        f"Macro F1: "
        f"{macro_f1:.6f}\n"
    )

    file.write(
        f"Weighted Precision: "
        f"{weighted_precision:.6f}\n"
    )

    file.write(
        f"Weighted Recall: "
        f"{weighted_recall:.6f}\n"
    )

    file.write(
        f"Weighted F1: "
        f"{weighted_f1:.6f}\n\n"
    )

    file.write(
        report
    )


# ============================================================
# 22. CONFUSION MATRIX
# ============================================================

cm = confusion_matrix(
    y_true,
    y_pred
)


plt.figure(
    figsize=(9, 8)
)

plt.imshow(
    cm,
    interpolation="nearest"
)

plt.title(
    "Clean FER-2013 - CNN Baseline"
)

plt.colorbar()

tick_marks = np.arange(
    NUM_CLASSES
)

plt.xticks(
    tick_marks,
    CLASS_NAMES,
    rotation=45
)

plt.yticks(
    tick_marks,
    CLASS_NAMES
)


threshold = cm.max() / 2.0


for i in range(
    cm.shape[0]
):

    for j in range(
        cm.shape[1]
    ):

        plt.text(
            j,
            i,
            str(cm[i, j]),
            horizontalalignment="center",
            color=(
                "white"
                if cm[i, j] > threshold
                else "black"
            )
        )


plt.ylabel(
    "True Label"
)

plt.xlabel(
    "Predicted Label"
)

plt.tight_layout()


confusion_path = (
    RESULT_DIR
    / "confusion_matrix.png"
)


plt.savefig(
    confusion_path,
    dpi=300,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# 23. TRAINING ACCURACY CURVE
# ============================================================

history_data = history.history


plt.figure(
    figsize=(10, 6)
)

plt.plot(
    history_data["accuracy"],
    label="Training Accuracy"
)

plt.plot(
    history_data["val_accuracy"],
    label="Validation Accuracy"
)

plt.xlabel(
    "Epoch"
)

plt.ylabel(
    "Accuracy"
)

plt.title(
    "Clean CNN Baseline - Accuracy"
)

plt.legend()

plt.grid(
    True,
    alpha=0.3
)

plt.tight_layout()


accuracy_curve_path = (
    RESULT_DIR
    / "accuracy_curve.png"
)


plt.savefig(
    accuracy_curve_path,
    dpi=300,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# 24. TRAINING LOSS CURVE
# ============================================================

plt.figure(
    figsize=(10, 6)
)

plt.plot(
    history_data["loss"],
    label="Training Loss"
)

plt.plot(
    history_data["val_loss"],
    label="Validation Loss"
)

plt.xlabel(
    "Epoch"
)

plt.ylabel(
    "Loss"
)

plt.title(
    "Clean CNN Baseline - Loss"
)

plt.legend()

plt.grid(
    True,
    alpha=0.3
)

plt.tight_layout()


loss_curve_path = (
    RESULT_DIR
    / "loss_curve.png"
)


plt.savefig(
    loss_curve_path,
    dpi=300,
    bbox_inches="tight"
)

plt.close()


# ============================================================
# 25. SAVE METRICS JSON
# ============================================================

metrics = {

    "model":
        "CNN Baseline",

    "dataset":
        "FER-2013 Clean",

    "seed":
        SEED,

    "train_images":
        int(np.sum(train_counts)),

    "test_images":
        int(len(y_true)),

    "image_size":
        IMG_SIZE,

    "batch_size":
        BATCH_SIZE,

    "accuracy":
        float(accuracy),

    "macro_precision":
        float(macro_precision),

    "macro_recall":
        float(macro_recall),

    "macro_f1":
        float(macro_f1),

    "weighted_precision":
        float(weighted_precision),

    "weighted_recall":
        float(weighted_recall),

    "weighted_f1":
        float(weighted_f1),

    "epochs_configured":
        EPOCHS,

    "epochs_trained":
        len(history_data["loss"]),

}


metrics_path = (
    RESULT_DIR
    / "metrics.json"
)


with open(
    metrics_path,
    "w",
    encoding="utf-8"
) as file:

    json.dump(
        metrics,
        file,
        indent=4
    )


# ============================================================
# 26. SAVE CONFUSION MATRIX NUMERICALLY
# ============================================================

np.save(
    RESULT_DIR
    / "confusion_matrix.npy",
    cm
)


# ============================================================
# 27. FINAL SUMMARY
# ============================================================

print("\n")
print("=" * 70)
print("CLEAN CNN BASELINE TRAINING COMPLETED")
print("=" * 70)

print(
    f"Seed              : {SEED}"
)

print(
    f"Clean test images : {len(y_true)}"
)

print(
    f"Accuracy          : "
    f"{accuracy * 100:.2f}%"
)

print(
    f"Macro F1          : "
    f"{macro_f1:.4f}"
)

print(
    f"Weighted F1       : "
    f"{weighted_f1:.4f}"
)

print("\nBest model saved to:")

print(
    MODEL_PATH
)

print("\nResults saved to:")

print(
    RESULT_DIR
)

print("=" * 70)