"""
EfficientNetB0 Transfer Learning for FER-2013
Carevora - Facial Emotion Recognition

Classes:
0 - angry
1 - disgust
2 - fear
3 - happy
4 - neutral
5 - sad
6 - surprise

Training:
    Phase 1 -> Frozen ImageNet EfficientNetB0 backbone
    Phase 2 -> Fine-tune upper EfficientNetB0 layers

Evaluation:
    Official FER-2013 test set is kept completely separate.
"""

# ============================================================
# IMPORTS
# ============================================================

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

from tensorflow.keras.applications import EfficientNetB0

from tensorflow.keras.callbacks import (
    EarlyStopping,
    ModelCheckpoint,
    ReduceLROnPlateau,
    CSVLogger,
)

from tensorflow.keras.optimizers import AdamW


# ============================================================
# 1. REPRODUCIBILITY
# ============================================================

SEED = 42

random.seed(SEED)

np.random.seed(SEED)

tf.random.set_seed(SEED)


# ============================================================
# 2. PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parents[2]

DATA_DIR = (
    BASE_DIR
    / "data"
    / "raw"
    / "fer2013"
)

TRAIN_DIR = (
    DATA_DIR
    / "train"
)

TEST_DIR = (
    DATA_DIR
    / "test"
)

RESULT_DIR = (
    BASE_DIR
    / "results"
    / "facial_emotion"
    / "transfer_model"
)

MODEL_DIR = (
    BASE_DIR
    / "src"
    / "models"
)


RESULT_DIR.mkdir(
    parents=True,
    exist_ok=True
)

MODEL_DIR.mkdir(
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

NUM_CLASSES = len(
    CLASS_NAMES
)

IMG_SIZE = 96

BATCH_SIZE = 32

VALIDATION_SPLIT = 0.15

PHASE1_EPOCHS = 15

PHASE2_EPOCHS = 30

INITIAL_LR = 0.0005

FINE_TUNE_LR = 0.00005

WEIGHT_DECAY = 0.0001


# ============================================================
# 4. START
# ============================================================

print("=" * 70)

print(
    "EFFICIENTNETB0 TRANSFER LEARNING - FER-2013"
)

print("=" * 70)

print(
    f"TensorFlow version : {tf.__version__}"
)

print(
    f"Training directory : {TRAIN_DIR}"
)

print(
    f"Testing directory  : {TEST_DIR}"
)

print(
    f"Image size         : {IMG_SIZE} x {IMG_SIZE}"
)

print(
    f"Batch size         : {BATCH_SIZE}"
)


# ============================================================
# 5. DATASET CHECK
# ============================================================

print(
    "\nChecking dataset structure..."
)


if not TRAIN_DIR.exists():

    raise FileNotFoundError(
        f"Training directory not found:\n"
        f"{TRAIN_DIR}"
    )


if not TEST_DIR.exists():

    raise FileNotFoundError(
        f"Testing directory not found:\n"
        f"{TEST_DIR}"
    )


for class_name in CLASS_NAMES:

    train_class_dir = (
        TRAIN_DIR
        / class_name
    )

    test_class_dir = (
        TEST_DIR
        / class_name
    )


    if not train_class_dir.exists():

        raise FileNotFoundError(
            f"Missing training class:\n"
            f"{train_class_dir}"
        )


    if not test_class_dir.exists():

        raise FileNotFoundError(
            f"Missing testing class:\n"
            f"{test_class_dir}"
        )


print(
    "Dataset structure check: PASSED"
)


# ============================================================
# 6. COUNT TRAINING IMAGES
# ============================================================

print(
    "\nTraining dataset distribution:"
)


train_counts = []


for class_name in CLASS_NAMES:

    class_dir = (
        TRAIN_DIR
        / class_name
    )


    image_count = len(
        [
            file
            for file in class_dir.iterdir()
            if file.is_file()
        ]
    )


    train_counts.append(
        image_count
    )


    print(
        f"{class_name:10s}: "
        f"{image_count}"
    )


train_counts = np.array(
    train_counts,
    dtype=np.int64
)


# ============================================================
# 7. LOAD TRAINING DATA
# ============================================================

print(
    "\nLoading training dataset..."
)


train_ds = (
    tf.keras.utils
    .image_dataset_from_directory(

        TRAIN_DIR,

        labels="inferred",

        label_mode="int",

        class_names=CLASS_NAMES,

        color_mode="rgb",

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
)


# ============================================================
# 8. LOAD VALIDATION DATA
# ============================================================

print(
    "\nLoading validation dataset..."
)


val_ds = (
    tf.keras.utils
    .image_dataset_from_directory(

        TRAIN_DIR,

        labels="inferred",

        label_mode="int",

        class_names=CLASS_NAMES,

        color_mode="rgb",

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
)


# ============================================================
# 9. LOAD TEST DATA
# ============================================================

print(
    "\nLoading official FER-2013 test dataset..."
)


test_ds = (
    tf.keras.utils
    .image_dataset_from_directory(

        TEST_DIR,

        labels="inferred",

        label_mode="int",

        class_names=CLASS_NAMES,

        color_mode="rgb",

        image_size=(
            IMG_SIZE,
            IMG_SIZE
        ),

        batch_size=BATCH_SIZE,

        shuffle=False,
    )
)


# ============================================================
# 10. PREFETCH
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
# 11. CLASS WEIGHTS
# ============================================================

print(
    "\nCalculating class weights..."
)


class_indices = np.concatenate(

    [

        np.full(
            count,
            class_index
        )

        for class_index, count
        in enumerate(
            train_counts
        )

    ]

)


class_weights_array = (
    compute_class_weight(

        class_weight="balanced",

        classes=np.arange(
            NUM_CLASSES
        ),

        y=class_indices,
    )
)


# Use square-root weighting.
# This gives additional attention
# to minority classes without making
# the rare class weight excessively high.

class_weights_array = np.sqrt(
    class_weights_array
)


class_weights = {

    index: float(weight)

    for index, weight
    in enumerate(
        class_weights_array
    )

}


print(
    "\nClass weights:"
)


for index, class_name in enumerate(
    CLASS_NAMES
):

    print(

        f"{class_name:10s}: "
        f"{class_weights[index]:.4f}"

    )


# ============================================================
# 12. DATA AUGMENTATION
# ============================================================

data_augmentation = (
    tf.keras.Sequential(

        [

            layers.RandomFlip(
                "horizontal"
            ),

            layers.RandomRotation(
                0.05
            ),

            layers.RandomZoom(
                0.08
            ),

            layers.RandomTranslation(
                height_factor=0.05,
                width_factor=0.05,
            ),

        ],

        name="data_augmentation",

    )
)


# ============================================================
# 13. LOAD EFFICIENTNETB0
# ============================================================

print(
    "\nLoading EfficientNetB0 ImageNet weights..."
)


base_model = EfficientNetB0(

    include_top=False,

    weights="imagenet",

    input_shape=(
        IMG_SIZE,
        IMG_SIZE,
        3,
    ),

)


# ============================================================
# 14. FREEZE BACKBONE
# ============================================================

base_model.trainable = False


# ============================================================
# 15. BUILD MODEL
# ============================================================

inputs = layers.Input(

    shape=(
        IMG_SIZE,
        IMG_SIZE,
        3,
    ),

    name="input_image",
)


x = data_augmentation(
    inputs
)


x = base_model(
    x,
    training=False
)


x = (
    layers
    .GlobalAveragePooling2D(
        name="global_average_pooling"
    )
    (x)
)


x = (
    layers
    .BatchNormalization(
        name="feature_batch_norm"
    )
    (x)
)


x = layers.Dense(

    256,

    activation="relu",

    kernel_regularizer=(
        tf.keras
        .regularizers
        .l2(1e-4)
    ),

    name="dense_features",

)(x)


x = layers.Dropout(

    0.40,

    name="dropout",

)(x)


outputs = layers.Dense(

    NUM_CLASSES,

    activation="softmax",

    name="emotion_output",

)(x)


model = models.Model(

    inputs=inputs,

    outputs=outputs,

    name="EfficientNetB0_FER2013",

)


print(
    "\nModel created successfully."
)


# ============================================================
# 16. MODEL SUMMARY
# ============================================================

model.summary()


# ============================================================
# 17. PHASE 1 COMPILE
# ============================================================

print(
    "\nCompiling Phase 1..."
)


model.compile(

    optimizer=AdamW(

        learning_rate=INITIAL_LR,

        weight_decay=WEIGHT_DECAY,

    ),

    # IMPORTANT:
    # Keras version in this environment does not
    # support label_smoothing here.

    loss=(
        tf.keras
        .losses
        .SparseCategoricalCrossentropy()
    ),

    metrics=[
        "accuracy"
    ],

)


# ============================================================
# 18. PHASE 1 CALLBACKS
# ============================================================

phase1_checkpoint = (

    MODEL_DIR
    / "efficientnetb0_phase1.keras"

)


callbacks_phase1 = [

    ModelCheckpoint(

        filepath=str(
            phase1_checkpoint
        ),

        monitor="val_accuracy",

        mode="max",

        save_best_only=True,

        verbose=1,

    ),

    EarlyStopping(

        monitor="val_loss",

        patience=5,

        restore_best_weights=True,

        verbose=1,

    ),

    ReduceLROnPlateau(

        monitor="val_loss",

        factor=0.5,

        patience=2,

        min_lr=1e-7,

        verbose=1,

    ),

    CSVLogger(

        str(

            RESULT_DIR
            / "phase1_training.csv"

        )

    ),

]


# ============================================================
# 19. PHASE 1 TRAINING
# ============================================================

print("\n")

print("=" * 70)

print(
    "PHASE 1 - FROZEN IMAGENET BACKBONE"
)

print("=" * 70)


history1 = model.fit(

    train_ds,

    validation_data=val_ds,

    epochs=PHASE1_EPOCHS,

    class_weight=class_weights,

    callbacks=callbacks_phase1,

    verbose=1,

)


# ============================================================
# 20. LOAD BEST PHASE 1 MODEL
# ============================================================

if phase1_checkpoint.exists():

    print(
        "\nLoading best Phase 1 model..."
    )

    model = tf.keras.models.load_model(
        phase1_checkpoint
    )


# ============================================================
# 21. FIND EFFICIENTNET BASE MODEL
# ============================================================

print(
    "\nPreparing Phase 2 fine-tuning..."
)


base_model = None


for layer in model.layers:

    if isinstance(
        layer,
        tf.keras.Model
    ):

        if (
            "efficientnet"
            in layer.name.lower()
        ):

            base_model = layer

            break


if base_model is None:

    raise RuntimeError(
        "EfficientNetB0 base model "
        "could not be found."
    )


# ============================================================
# 22. UNFREEZE UPPER LAYERS
# ============================================================

base_model.trainable = True


fine_tune_from = max(

    0,

    len(base_model.layers) - 80

)


for layer_index, layer in enumerate(
    base_model.layers
):

    if layer_index < fine_tune_from:

        layer.trainable = False

    else:

        layer.trainable = True


# Keep Batch Normalization layers frozen.

for layer in base_model.layers:

    if isinstance(
        layer,
        layers.BatchNormalization
    ):

        layer.trainable = False


trainable_layers = sum(

    1

    for layer in base_model.layers

    if layer.trainable

)


print(
    f"Total EfficientNet layers : "
    f"{len(base_model.layers)}"
)


print(
    f"Trainable layers          : "
    f"{trainable_layers}"
)


# ============================================================
# 23. PHASE 2 COMPILE
# ============================================================

print(
    "\nCompiling Phase 2..."
)


model.compile(

    optimizer=AdamW(

        learning_rate=FINE_TUNE_LR,

        weight_decay=WEIGHT_DECAY,

    ),

    loss=(
        tf.keras
        .losses
        .SparseCategoricalCrossentropy()
    ),

    metrics=[
        "accuracy"
    ],

)


# ============================================================
# 24. PHASE 2 CALLBACKS
# ============================================================

phase2_checkpoint = (

    MODEL_DIR
    / "efficientnetb0_finetuned.keras"

)


callbacks_phase2 = [

    ModelCheckpoint(

        filepath=str(
            phase2_checkpoint
        ),

        monitor="val_accuracy",

        mode="max",

        save_best_only=True,

        verbose=1,

    ),

    EarlyStopping(

        monitor="val_loss",

        patience=7,

        restore_best_weights=True,

        verbose=1,

    ),

    ReduceLROnPlateau(

        monitor="val_loss",

        factor=0.5,

        patience=3,

        min_lr=1e-7,

        verbose=1,

    ),

    CSVLogger(

        str(

            RESULT_DIR
            / "phase2_training.csv"

        )

    ),

]


# ============================================================
# 25. PHASE 2 TRAINING
# ============================================================

history2 = model.fit(

    train_ds,

    validation_data=val_ds,

    initial_epoch=PHASE1_EPOCHS,

    epochs=(
        PHASE1_EPOCHS
        + PHASE2_EPOCHS
    ),

    class_weight=class_weights,

    callbacks=callbacks_phase2,

    verbose=1,

)


# ============================================================
# 26. LOAD BEST FINE-TUNED MODEL
# ============================================================

if phase2_checkpoint.exists():

    print(
        "\nLoading best fine-tuned model..."
    )

    model = tf.keras.models.load_model(
        phase2_checkpoint
    )


# ============================================================
# 27. SAVE FINAL MODEL
# ============================================================

final_model_path = (

    MODEL_DIR
    / "transfer_emotion.keras"

)


model.save(
    final_model_path
)


print(
    "\nFinal model saved:"
)


print(
    final_model_path
)


# ============================================================
# 28. FINAL TEST PREDICTIONS
# ============================================================

print("\n")

print("=" * 70)

print(
    "FINAL TEST EVALUATION"
)

print("=" * 70)


y_true = []

y_pred = []

y_prob = []


for images, labels in test_ds:

    probabilities = model.predict(

        images,

        verbose=0,

    )


    predictions = np.argmax(

        probabilities,

        axis=1,

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
# 29. METRICS
# ============================================================

accuracy = accuracy_score(

    y_true,

    y_pred,

)


weighted_precision = precision_score(

    y_true,

    y_pred,

    average="weighted",

    zero_division=0,

)


weighted_recall = recall_score(

    y_true,

    y_pred,

    average="weighted",

    zero_division=0,

)


weighted_f1 = f1_score(

    y_true,

    y_pred,

    average="weighted",

    zero_division=0,

)


macro_f1 = f1_score(

    y_true,

    y_pred,

    average="macro",

    zero_division=0,

)


print(
    "\nFINAL TEST RESULTS"
)

print(
    "-" * 60
)


print(

    f"Accuracy           : "
    f"{accuracy * 100:.2f}%"

)


print(

    f"Weighted Precision : "
    f"{weighted_precision * 100:.2f}%"

)


print(

    f"Weighted Recall    : "
    f"{weighted_recall * 100:.2f}%"

)


print(

    f"Weighted F1        : "
    f"{weighted_f1 * 100:.2f}%"

)


print(

    f"Macro F1           : "
    f"{macro_f1 * 100:.2f}%"

)


# ============================================================
# 30. CLASSIFICATION REPORT
# ============================================================

report = classification_report(

    y_true,

    y_pred,

    target_names=CLASS_NAMES,

    digits=4,

    zero_division=0,

)


print("\n")

print("=" * 70)

print(
    "CLASSIFICATION REPORT"
)

print("=" * 70)

print(report)


report_path = (

    RESULT_DIR
    / "classification_report.txt"

)


with open(

    report_path,

    "w",

    encoding="utf-8",

) as file:

    file.write(

        "EfficientNetB0 Transfer Learning "
        "FER-2013 Results\n\n"

    )

    file.write(

        f"Accuracy: "
        f"{accuracy:.6f}\n"

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
        f"{weighted_f1:.6f}\n"

    )

    file.write(

        f"Macro F1: "
        f"{macro_f1:.6f}\n\n"

    )

    file.write(report)


# ============================================================
# 31. CONFUSION MATRIX
# ============================================================

cm = confusion_matrix(

    y_true,

    y_pred,

)


plt.figure(

    figsize=(9, 8)

)


plt.imshow(

    cm,

    interpolation="nearest",

)


plt.title(

    "EfficientNetB0 - FER-2013 "
    "Confusion Matrix"

)


plt.colorbar()


tick_marks = np.arange(
    NUM_CLASSES
)


plt.xticks(

    tick_marks,

    CLASS_NAMES,

    rotation=45,

)


plt.yticks(

    tick_marks,

    CLASS_NAMES,

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

            ),

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

    bbox_inches="tight",

)


plt.close()


# ============================================================
# 32. COMBINE TRAINING HISTORIES
# ============================================================

history = {}


all_history_keys = set(
    history1.history.keys()
).union(
    history2.history.keys()
)


for key in all_history_keys:

    values1 = history1.history.get(
        key,
        []
    )

    values2 = history2.history.get(
        key,
        []
    )

    history[key] = (
        values1 + values2
    )


# ============================================================
# 33. ACCURACY CURVE
# ============================================================

plt.figure(

    figsize=(10, 6)

)


plt.plot(

    history["accuracy"],

    label="Training Accuracy",

)


plt.plot(

    history["val_accuracy"],

    label="Validation Accuracy",

)


plt.axvline(

    x=PHASE1_EPOCHS - 1,

    linestyle="--",

    label="Fine-Tuning Start",

)


plt.xlabel(
    "Epoch"
)


plt.ylabel(
    "Accuracy"
)


plt.title(

    "EfficientNetB0 Training and "
    "Validation Accuracy"

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

    bbox_inches="tight",

)


plt.close()


# ============================================================
# 34. LOSS CURVE
# ============================================================

plt.figure(

    figsize=(10, 6)

)


plt.plot(

    history["loss"],

    label="Training Loss",

)


plt.plot(

    history["val_loss"],

    label="Validation Loss",

)


plt.axvline(

    x=PHASE1_EPOCHS - 1,

    linestyle="--",

    label="Fine-Tuning Start",

)


plt.xlabel(
    "Epoch"
)


plt.ylabel(
    "Loss"
)


plt.title(

    "EfficientNetB0 Training and "
    "Validation Loss"

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

    bbox_inches="tight",

)


plt.close()


# ============================================================
# 35. SAVE METRICS JSON
# ============================================================

metrics = {

    "model":
        "EfficientNetB0 Transfer Learning",

    "dataset":
        "FER-2013",

    "classes":
        CLASS_NAMES,

    "num_classes":
        NUM_CLASSES,

    "image_size":
        IMG_SIZE,

    "batch_size":
        BATCH_SIZE,

    "accuracy":
        float(accuracy),

    "weighted_precision":
        float(weighted_precision),

    "weighted_recall":
        float(weighted_recall),

    "weighted_f1":
        float(weighted_f1),

    "macro_f1":
        float(macro_f1),

    "train_images":
        int(
            np.sum(
                train_counts
            )
        ),

    "test_images":
        int(
            len(y_true)
        ),

}


metrics_path = (

    RESULT_DIR
    / "metrics.json"

)


with open(

    metrics_path,

    "w",

    encoding="utf-8",

) as file:

    json.dump(

        metrics,

        file,

        indent=4,

    )


# ============================================================
# 36. SAVE CONFUSION MATRIX
# ============================================================

np.save(

    RESULT_DIR
    / "confusion_matrix.npy",

    cm,

)


# ============================================================
# 37. FINAL SUMMARY
# ============================================================

print("\n")

print("=" * 70)

print(
    "TRAINING COMPLETED SUCCESSFULLY"
)

print("=" * 70)


print(

    f"Test Accuracy       : "
    f"{accuracy * 100:.2f}%"

)


print(

    f"Weighted Precision  : "
    f"{weighted_precision * 100:.2f}%"

)


print(

    f"Weighted Recall     : "
    f"{weighted_recall * 100:.2f}%"

)


print(

    f"Weighted F1         : "
    f"{weighted_f1 * 100:.2f}%"

)


print(

    f"Macro F1            : "
    f"{macro_f1 * 100:.2f}%"

)


print(
    "\nSaved files:"
)


print(

    f"Model              : "
    f"{final_model_path}"

)


print(

    f"Classification     : "
    f"{report_path}"

)


print(

    f"Confusion Matrix   : "
    f"{confusion_path}"

)


print(

    f"Accuracy Curve     : "
    f"{accuracy_curve_path}"

)


print(

    f"Loss Curve         : "
    f"{loss_curve_path}"

)


print(

    f"Metrics JSON       : "
    f"{metrics_path}"

)


print(
    "\nDone."
)