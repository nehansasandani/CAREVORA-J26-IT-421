import json
import os
import random
from pathlib import Path

import numpy as np
import tensorflow as tf
from sklearn.metrics import classification_report, confusion_matrix


# ============================================================
# CONFIG
# ============================================================

SEED = int(os.environ.get("SEED", "42"))

IMG_SIZE = 96
BATCH_SIZE = 32

PHASE1_EPOCHS = 15
PHASE2_EPOCHS = 30

LEARNING_RATE = 0.0005
WEIGHT_DECAY = 0.0001

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


# ============================================================
# PATHS
# ============================================================

AI_DIR = Path(__file__).resolve().parents[2]

DATA_DIR = (
    AI_DIR
    / "data"
    / "raw"
    / "fer2013_clean"
)

TRAIN_DIR = DATA_DIR / "train"
TEST_DIR = DATA_DIR / "test"

MODEL_DIR = (
    AI_DIR
    / "src"
    / "models"
    / "clean_seed"
    / f"seed{SEED}"
)

RESULT_DIR = (
    AI_DIR
    / "results"
    / "facial_emotion"
    / "transfer_clean"
    / f"seed{SEED}"
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
# REPRODUCIBILITY
# ============================================================

os.environ["PYTHONHASHSEED"] = str(SEED)

random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)


print("=" * 75)
print("CAREVORA - CLEAN EFFICIENTNETB0 TRAINING")
print("=" * 75)

print(f"Seed       : {SEED}")
print(f"Train dir  : {TRAIN_DIR}")
print(f"Test dir   : {TEST_DIR}")


# ============================================================
# DATASET
# ============================================================

if not TRAIN_DIR.exists():
    raise FileNotFoundError(
        f"Clean train dataset not found:\n{TRAIN_DIR}"
    )

if not TEST_DIR.exists():
    raise FileNotFoundError(
        f"Clean test dataset not found:\n{TEST_DIR}"
    )


train_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    labels="inferred",
    label_mode="int",
    class_names=CLASS_NAMES,
    color_mode="rgb",
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    shuffle=True,
    seed=SEED,
    validation_split=0.15,
    subset="training",
)

val_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR,
    labels="inferred",
    label_mode="int",
    class_names=CLASS_NAMES,
    color_mode="rgb",
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    shuffle=True,
    seed=SEED,
    validation_split=0.15,
    subset="validation",
)

test_ds = tf.keras.utils.image_dataset_from_directory(
    TEST_DIR,
    labels="inferred",
    label_mode="int",
    class_names=CLASS_NAMES,
    color_mode="rgb",
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    shuffle=False,
)


# ============================================================
# NORMALIZATION
# ============================================================

# EfficientNetB0 in this Keras version includes its own
# preprocessing/rescaling behavior, so keep raw 0..255 values.

AUTOTUNE = tf.data.AUTOTUNE

train_ds = train_ds.prefetch(AUTOTUNE)
val_ds = val_ds.prefetch(AUTOTUNE)
test_ds = test_ds.prefetch(AUTOTUNE)


# ============================================================
# DATA AUGMENTATION
# ============================================================

augmentation = tf.keras.Sequential(
    [
        tf.keras.layers.RandomFlip("horizontal"),
        tf.keras.layers.RandomRotation(0.05),
        tf.keras.layers.RandomZoom(0.08),
        tf.keras.layers.RandomTranslation(
            height_factor=0.05,
            width_factor=0.05
        ),
    ],
    name="augmentation",
)


# ============================================================
# MODEL
# ============================================================

print("\nBuilding EfficientNetB0...")

base_model = tf.keras.applications.EfficientNetB0(
    include_top=False,
    weights="imagenet",
    input_shape=(IMG_SIZE, IMG_SIZE, 3),
)

base_model.trainable = False


inputs = tf.keras.Input(
    shape=(IMG_SIZE, IMG_SIZE, 3)
)

x = augmentation(inputs)

x = base_model(
    x,
    training=False
)

x = tf.keras.layers.GlobalAveragePooling2D()(x)

x = tf.keras.layers.BatchNormalization()(x)

x = tf.keras.layers.Dense(
    256,
    activation="relu",
    kernel_regularizer=tf.keras.regularizers.l2(1e-4),
)(x)

x = tf.keras.layers.Dropout(0.40)(x)

outputs = tf.keras.layers.Dense(
    NUM_CLASSES,
    activation="softmax"
)(x)

model = tf.keras.Model(
    inputs,
    outputs
)


# ============================================================
# COMPILE PHASE 1
# ============================================================

model.compile(
    optimizer=tf.keras.optimizers.AdamW(
        learning_rate=LEARNING_RATE,
        weight_decay=WEIGHT_DECAY,
    ),
    loss=tf.keras.losses.SparseCategoricalCrossentropy(),
    metrics=["accuracy"],
)


# ============================================================
# CALLBACKS
# ============================================================

best_model_path = (
    MODEL_DIR
    / "transfer_emotion_clean.keras"
)

callbacks = [

    tf.keras.callbacks.ModelCheckpoint(
        str(best_model_path),
        monitor="val_accuracy",
        mode="max",
        save_best_only=True,
        verbose=1,
    ),

    tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",
        patience=7,
        restore_best_weights=True,
        verbose=1,
    ),

    tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=3,
        min_lr=1e-6,
        verbose=1,
    ),

    tf.keras.callbacks.CSVLogger(
        str(
            RESULT_DIR
            / "training_log.csv"
        )
    ),
]


# ============================================================
# PHASE 1
# ============================================================

print("\n" + "=" * 75)
print("PHASE 1 - FROZEN EFFICIENTNETB0")
print("=" * 75)

history1 = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=PHASE1_EPOCHS,
    callbacks=callbacks,
)


# ============================================================
# PHASE 2 - FINE TUNING
# ============================================================

print("\n" + "=" * 75)
print("PHASE 2 - FINE TUNING")
print("=" * 75)

base_model.trainable = True

# Freeze all but upper 80 layers.
fine_tune_at = max(
    0,
    len(base_model.layers) - 80
)

for layer in base_model.layers[:fine_tune_at]:
    layer.trainable = False

# Keep BatchNorm frozen during fine-tuning.
for layer in base_model.layers:
    if isinstance(
        layer,
        tf.keras.layers.BatchNormalization
    ):
        layer.trainable = False


model.compile(
    optimizer=tf.keras.optimizers.AdamW(
        learning_rate=LEARNING_RATE * 0.1,
        weight_decay=WEIGHT_DECAY,
    ),
    loss=tf.keras.losses.SparseCategoricalCrossentropy(),
    metrics=["accuracy"],
)


history2 = model.fit(
    train_ds,
    validation_data=val_ds,
    initial_epoch=PHASE1_EPOCHS,
    epochs=PHASE1_EPOCHS + PHASE2_EPOCHS,
    callbacks=callbacks,
)


# ============================================================
# LOAD BEST MODEL
# ============================================================

print("\nLoading best checkpoint...")

best_model = tf.keras.models.load_model(
    str(best_model_path)
)


# ============================================================
# TEST EVALUATION
# ============================================================

print("\n" + "=" * 75)
print("CLEAN TEST EVALUATION")
print("=" * 75)

test_loss, test_accuracy = best_model.evaluate(
    test_ds,
    verbose=1,
)


# ============================================================
# PREDICTIONS
# ============================================================

y_true = np.concatenate(
    [
        y.numpy()
        for _, y in test_ds
    ]
)

probabilities = best_model.predict(
    test_ds,
    verbose=1
)

y_pred = probabilities.argmax(
    axis=1
)


# ============================================================
# REPORT
# ============================================================

report = classification_report(
    y_true,
    y_pred,
    labels=list(range(NUM_CLASSES)),
    target_names=CLASS_NAMES,
    digits=4,
    zero_division=0,
)


print("\nClassification Report")
print(report)

cm = confusion_matrix(
    y_true,
    y_pred,
)


# ============================================================
# SAVE RESULTS
# ============================================================

with open(
    RESULT_DIR / "classification_report.txt",
    "w",
    encoding="utf-8",
) as f:

    f.write(report)


np.save(
    RESULT_DIR / "confusion_matrix.npy",
    cm,
)


metrics = {

    "seed": SEED,

    "clean_test_images": int(
        len(y_true)
    ),

    "test_loss": float(
        test_loss
    ),

    "test_accuracy": float(
        test_accuracy
    ),

    "model": "EfficientNetB0",

    "dataset": "FER-2013 clean",

    "validation_split": 0.15,

    "phase1_epochs": PHASE1_EPOCHS,

    "phase2_epochs": PHASE2_EPOCHS,

    "best_model": str(
        best_model_path
    ),
}


with open(
    RESULT_DIR / "metrics.json",
    "w",
    encoding="utf-8",
) as f:

    json.dump(
        metrics,
        f,
        indent=4
    )


print("\n" + "=" * 75)
print("TRAINING COMPLETED")
print("=" * 75)

print(
    f"Seed            : {SEED}"
)

print(
    f"Clean test acc  : {test_accuracy * 100:.2f}%"
)

print(
    f"Best model      : {best_model_path}"
)

print(
    f"Results         : {RESULT_DIR}"
)

print("=" * 75)