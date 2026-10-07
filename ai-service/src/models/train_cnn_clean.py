# ============================================================
# CLEAN CNN BASELINE - FER-2013   (corrected version)
#
# Fixes compared with the previous version
#   1. Validation subset now uses shuffle=True (same as the training
#      subset). With shuffle=False Keras built the validation set from the
#      class-sorted file list (only sad/surprise, ~87% also in train).
#   2. The script now PROVES the split is correct at run time:
#      train/val overlap must be 0 and the validation class distribution
#      is printed. If the check fails the script stops.
#   3. Class weights are computed from the real training subset file list.
#   4. Test evaluation uses one predict() call over the test set.
#   5. Refuses to overwrite an existing result folder (set OVERWRITE=1
#      if you really want that).
#
# Model, optimizer, callbacks and hyper-parameters are UNCHANGED, so the
# baseline stays a fair "simple CNN" comparison model.
# ============================================================

import json
import os
import random
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.utils.class_weight import compute_class_weight
from tensorflow.keras import layers, models
from tensorflow.keras.callbacks import (
    CSVLogger,
    EarlyStopping,
    ModelCheckpoint,
    ReduceLROnPlateau,
)
from tensorflow.keras.optimizers import Adam

# ============================================================
# 1. REPRODUCIBILITY
# ============================================================

SEED = int(os.environ.get("SEED", "42"))
os.environ["PYTHONHASHSEED"] = str(SEED)
random.seed(SEED)
np.random.seed(SEED)
tf.random.set_seed(SEED)

print("=" * 70)
print("CLEAN CNN BASELINE - FER-2013 (corrected split)")
print("=" * 70)
print(f"Seed : {SEED}")

# ============================================================
# 2. PATHS
# ============================================================

BASE_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = BASE_DIR / "data" / "raw" / "fer2013_clean"
TRAIN_DIR = DATA_DIR / "train"
TEST_DIR = DATA_DIR / "test"

RESULT_DIR = BASE_DIR / "results" / "facial_emotion" / "clean_baselines" / f"cnn_seed{SEED}"
MODEL_DIR = BASE_DIR / "src" / "models" / "clean_seed" / f"seed{SEED}"

if (RESULT_DIR / "metrics.json").exists() and os.environ.get("OVERWRITE") != "1":
    raise SystemExit(
        f"\nResults already exist in:\n{RESULT_DIR}\n"
        "Move/rename that folder first (old results are from the buggy split),\n"
        "or run with  $env:OVERWRITE=\"1\"  to overwrite."
    )

RESULT_DIR.mkdir(parents=True, exist_ok=True)
MODEL_DIR.mkdir(parents=True, exist_ok=True)

# ============================================================
# 3. CONFIGURATION (unchanged)
# ============================================================

CLASS_NAMES = ["angry", "disgust", "fear", "happy", "neutral", "sad", "surprise"]
NUM_CLASSES = len(CLASS_NAMES)

IMG_SIZE = 48
BATCH_SIZE = 32
VALIDATION_SPLIT = 0.15
EPOCHS = int(os.environ.get("EPOCHS", "30"))
LEARNING_RATE = 0.001

DROPOUT_1 = 0.25
DROPOUT_2 = 0.25
DROPOUT_3 = 0.30
DENSE_DROPOUT = 0.40

# ============================================================
# 4. DATASET CHECK
# ============================================================

print("\nChecking dataset structure...")
for d in (TRAIN_DIR, TEST_DIR):
    if not d.exists():
        raise FileNotFoundError(f"Directory not found:\n{d}")
for class_name in CLASS_NAMES:
    for d in (TRAIN_DIR / class_name, TEST_DIR / class_name):
        if not d.exists():
            raise FileNotFoundError(f"Missing class folder:\n{d}")
print("Dataset structure check: PASSED")

print("\nClean training dataset distribution:")
train_counts_original = []
for class_name in CLASS_NAMES:
    n = len([f for f in (TRAIN_DIR / class_name).iterdir() if f.is_file()])
    train_counts_original.append(n)
    print(f"{class_name:10s}: {n}")
train_counts_original = np.array(train_counts_original, dtype=np.int64)
print(f"\nTotal clean training images: {train_counts_original.sum()}")

# ============================================================
# 5. TRAIN / VALIDATION / TEST DATASETS
# ============================================================
# IMPORTANT: train and validation use the SAME seed, the SAME
# validation_split and BOTH shuffle=True, so Keras builds the two
# subsets from the same shuffled file list (disjoint subsets).
# ============================================================

COMMON = dict(
    labels="inferred",
    label_mode="int",
    class_names=CLASS_NAMES,
    color_mode="grayscale",
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    validation_split=VALIDATION_SPLIT,
    seed=SEED,
    shuffle=True,
)

print("\nLoading clean training dataset...")
train_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR, subset="training", **COMMON
)

print("\nLoading clean validation dataset...")
val_ds = tf.keras.utils.image_dataset_from_directory(
    TRAIN_DIR, subset="validation", **COMMON
)

print("\nLoading clean test dataset...")
test_ds = tf.keras.utils.image_dataset_from_directory(
    TEST_DIR,
    labels="inferred",
    label_mode="int",
    class_names=CLASS_NAMES,
    color_mode="grayscale",
    image_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    shuffle=False,
)

# ------------------------------------------------------------
# SPLIT SELF-CHECK (must happen BEFORE .map(), which drops file_paths)
# ------------------------------------------------------------

train_paths = list(train_ds.file_paths)
val_paths = list(val_ds.file_paths)
overlap = len(set(train_paths) & set(val_paths))


def labels_from_paths(paths):
    return np.array([CLASS_NAMES.index(Path(p).parent.name) for p in paths], dtype=np.int64)


training_labels = labels_from_paths(train_paths)
validation_labels = labels_from_paths(val_paths)

print("\n" + "=" * 70)
print("SPLIT SELF-CHECK")
print("=" * 70)
print(f"Train subset images : {len(train_paths)}")
print(f"Val subset images   : {len(val_paths)}")
print(f"Train/Val overlap   : {overlap}")
print(f"{'class':10s} {'train':>7s} {'val':>6s} {'val share':>10s}")
for i, name in enumerate(CLASS_NAMES):
    t = int((training_labels == i).sum())
    v = int((validation_labels == i).sum())
    print(f"{name:10s} {t:7d} {v:6d} {v / max(t + v, 1) * 100:9.1f}%")

if overlap != 0:
    raise RuntimeError("Train and validation subsets overlap - split is broken. Stopping.")
if len(set(validation_labels.tolist())) != NUM_CLASSES:
    raise RuntimeError("Validation subset does not contain all classes - split is broken. Stopping.")
print("Split self-check: PASSED")

# ============================================================
# 6. NORMALIZATION + PREFETCH
# ============================================================

AUTOTUNE = tf.data.AUTOTUNE


def normalize_images(images, labels):
    return tf.cast(images, tf.float32) / 255.0, labels


train_ds = train_ds.map(normalize_images, num_parallel_calls=AUTOTUNE).prefetch(AUTOTUNE)
val_ds = val_ds.map(normalize_images, num_parallel_calls=AUTOTUNE).prefetch(AUTOTUNE)
test_ds = test_ds.map(normalize_images, num_parallel_calls=AUTOTUNE).prefetch(AUTOTUNE)

# ============================================================
# 7. CLASS WEIGHTS (from the real training subset)
# ============================================================

print("\nCalculating class weights from training subset...")
class_weights_array = compute_class_weight(
    class_weight="balanced", classes=np.arange(NUM_CLASSES), y=training_labels
)
class_weights = {i: float(w) for i, w in enumerate(class_weights_array)}

print("\nClass weights:")
for i, name in enumerate(CLASS_NAMES):
    print(f"{name:10s}: {class_weights[i]:.4f}")
print(f"\nTraining subset images used for class weights: {len(training_labels)}")

# ============================================================
# 8. MODEL (unchanged architecture)
# ============================================================

print("\nBuilding CNN Baseline model...")

model = models.Sequential(
    [
        layers.Input(shape=(IMG_SIZE, IMG_SIZE, 1), name="input_image"),

        layers.Conv2D(32, (3, 3), padding="same", name="conv2d"),
        layers.BatchNormalization(name="batch_normalization"),
        layers.ReLU(name="re_lu"),
        layers.MaxPooling2D((2, 2), name="max_pooling2d"),
        layers.Dropout(DROPOUT_1, name="dropout"),

        layers.Conv2D(64, (3, 3), padding="same", name="conv2d_1"),
        layers.BatchNormalization(name="batch_normalization_1"),
        layers.ReLU(name="re_lu_1"),
        layers.MaxPooling2D((2, 2), name="max_pooling2d_1"),
        layers.Dropout(DROPOUT_2, name="dropout_1"),

        layers.Conv2D(128, (3, 3), padding="same", name="conv2d_2"),
        layers.BatchNormalization(name="batch_normalization_2"),
        layers.ReLU(name="re_lu_2"),
        layers.MaxPooling2D((2, 2), name="max_pooling2d_2"),
        layers.Dropout(DROPOUT_3, name="dropout_2"),

        layers.GlobalAveragePooling2D(name="global_average_pooling2d"),
        layers.Dense(128, activation="relu", name="dense"),
        layers.Dropout(DENSE_DROPOUT, name="dropout_3"),
        layers.Dense(NUM_CLASSES, activation="softmax", name="predictions"),
    ],
    name="CNN_Baseline",
)

print("\nModel summary:")
model.summary()

model.compile(
    optimizer=Adam(learning_rate=LEARNING_RATE),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)

# ============================================================
# 9. CALLBACKS (unchanged)
# ============================================================

MODEL_PATH = MODEL_DIR / "cnn_baseline_clean.keras"

callbacks = [
    ModelCheckpoint(filepath=str(MODEL_PATH), monitor="val_loss",
                    save_best_only=True, mode="min", verbose=1),
    EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True,
                  mode="min", verbose=1),
    ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=2,
                      min_lr=1e-6, mode="min", verbose=1),
    CSVLogger(str(RESULT_DIR / "training_history.csv")),
]

# ============================================================
# 10. TRAIN
# ============================================================

print("\n" + "=" * 70)
print("STARTING CLEAN CNN BASELINE TRAINING")
print("=" * 70)
print(f"Seed              : {SEED}")
print(f"Image size        : {IMG_SIZE} x {IMG_SIZE}")
print(f"Batch size        : {BATCH_SIZE}")
print(f"Validation split  : {VALIDATION_SPLIT}")
print(f"Learning rate     : {LEARNING_RATE}")
print(f"Epochs configured : {EPOCHS}")
print("=" * 70)

history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS,
    class_weight=class_weights,
    callbacks=callbacks,
    verbose=1,
)

# ============================================================
# 11. FINAL CLEAN TEST EVALUATION
# ============================================================

print("\nLoading best saved model...")
best_model = tf.keras.models.load_model(MODEL_PATH)

print("\n" + "=" * 70)
print("FINAL CLEAN TEST EVALUATION")
print("=" * 70)

y_true = np.concatenate([labels.numpy() for _, labels in test_ds])
y_prob = best_model.predict(test_ds, verbose=0)
y_pred = np.argmax(y_prob, axis=1)

accuracy = accuracy_score(y_true, y_pred)
macro_precision = precision_score(y_true, y_pred, average="macro", zero_division=0)
macro_recall = recall_score(y_true, y_pred, average="macro", zero_division=0)
macro_f1 = f1_score(y_true, y_pred, average="macro", zero_division=0)
weighted_precision = precision_score(y_true, y_pred, average="weighted", zero_division=0)
weighted_recall = recall_score(y_true, y_pred, average="weighted", zero_division=0)
weighted_f1 = f1_score(y_true, y_pred, average="weighted", zero_division=0)

report = classification_report(
    y_true, y_pred, labels=np.arange(NUM_CLASSES),
    target_names=CLASS_NAMES, digits=4, zero_division=0,
)

print("\nClassification Report:")
print(report)

print("=" * 70)
print("CLEAN CNN BASELINE RESULTS")
print("=" * 70)
print(f"Seed              : {SEED}")
print(f"Test images       : {len(y_true)}")
print(f"Accuracy          : {accuracy * 100:.2f}%")
print(f"Macro Precision   : {macro_precision:.4f}")
print(f"Macro Recall      : {macro_recall:.4f}")
print(f"Macro F1          : {macro_f1:.4f}")
print(f"Weighted F1       : {weighted_f1:.4f}")

# ============================================================
# 12. SAVE REPORT, PLOTS, METRICS
# ============================================================

with open(RESULT_DIR / "classification_report.txt", "w", encoding="utf-8") as f:
    f.write("CLEAN FER-2013 CNN BASELINE\n")
    f.write(f"Seed: {SEED}\nTest Images: {len(y_true)}\n\n")
    f.write(f"Accuracy: {accuracy:.6f}\n")
    f.write(f"Macro Precision: {macro_precision:.6f}\n")
    f.write(f"Macro Recall: {macro_recall:.6f}\n")
    f.write(f"Macro F1: {macro_f1:.6f}\n")
    f.write(f"Weighted Precision: {weighted_precision:.6f}\n")
    f.write(f"Weighted Recall: {weighted_recall:.6f}\n")
    f.write(f"Weighted F1: {weighted_f1:.6f}\n\n")
    f.write(report)

cm = confusion_matrix(y_true, y_pred, labels=np.arange(NUM_CLASSES))

plt.figure(figsize=(9, 8))
plt.imshow(cm, interpolation="nearest")
plt.title("Clean FER-2013 - CNN Baseline")
plt.colorbar()
ticks = np.arange(NUM_CLASSES)
plt.xticks(ticks, CLASS_NAMES, rotation=45)
plt.yticks(ticks, CLASS_NAMES)
threshold = cm.max() / 2.0
for i in range(cm.shape[0]):
    for j in range(cm.shape[1]):
        plt.text(j, i, str(cm[i, j]), horizontalalignment="center",
                 color="white" if cm[i, j] > threshold else "black")
plt.ylabel("True Label")
plt.xlabel("Predicted Label")
plt.tight_layout()
plt.savefig(RESULT_DIR / "confusion_matrix.png", dpi=300, bbox_inches="tight")
plt.close()

history_data = history.history

for key, val_key, title, fname in (
    ("accuracy", "val_accuracy", "Accuracy", "accuracy_curve.png"),
    ("loss", "val_loss", "Loss", "loss_curve.png"),
):
    plt.figure(figsize=(10, 6))
    plt.plot(history_data[key], label=f"Training {title}")
    plt.plot(history_data[val_key], label=f"Validation {title}")
    plt.xlabel("Epoch")
    plt.ylabel(title)
    plt.title(f"Clean CNN Baseline - {title}")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(RESULT_DIR / fname, dpi=300, bbox_inches="tight")
    plt.close()

best_epoch_loss = int(np.argmin(history_data["val_loss"])) + 1
best_val_loss = float(np.min(history_data["val_loss"]))
best_val_accuracy_epoch = int(np.argmax(history_data["val_accuracy"])) + 1
best_val_accuracy = float(np.max(history_data["val_accuracy"]))
final_train_accuracy = float(history_data["accuracy"][-1])
final_val_accuracy = float(history_data["val_accuracy"][-1])

metrics = {
    "model": "CNN Baseline",
    "dataset": "FER-2013 Clean",
    "seed": SEED,
    "split_method": "keras validation_split, both subsets shuffle=True (verified disjoint)",
    "train_images_original_clean": int(train_counts_original.sum()),
    "train_subset_images": len(train_paths),
    "val_subset_images": len(val_paths),
    "train_val_overlap": overlap,
    "test_images": int(len(y_true)),
    "image_size": IMG_SIZE,
    "batch_size": BATCH_SIZE,
    "validation_split": VALIDATION_SPLIT,
    "learning_rate": LEARNING_RATE,
    "epochs_configured": EPOCHS,
    "epochs_trained": len(history_data["loss"]),
    "best_epoch_by_val_loss": best_epoch_loss,
    "best_val_loss": best_val_loss,
    "best_epoch_by_val_accuracy": best_val_accuracy_epoch,
    "best_val_accuracy": best_val_accuracy,
    "final_train_accuracy": final_train_accuracy,
    "final_val_accuracy": final_val_accuracy,
    "test_accuracy": float(accuracy),
    "macro_precision": float(macro_precision),
    "macro_recall": float(macro_recall),
    "macro_f1": float(macro_f1),
    "weighted_precision": float(weighted_precision),
    "weighted_recall": float(weighted_recall),
    "weighted_f1": float(weighted_f1),
}

with open(RESULT_DIR / "metrics.json", "w", encoding="utf-8") as f:
    json.dump(metrics, f, indent=4)

np.save(RESULT_DIR / "confusion_matrix.npy", cm)

with open(RESULT_DIR / "class_weights.json", "w", encoding="utf-8") as f:
    json.dump({CLASS_NAMES[i]: float(w) for i, w in class_weights.items()}, f, indent=4)

# ============================================================
# 13. FINAL SUMMARY
# ============================================================

best_val_acc_at_best_loss = float(history_data["val_accuracy"][best_epoch_loss - 1])

print("\n" + "=" * 70)
print("CLEAN CNN BASELINE TRAINING COMPLETED")
print("=" * 70)
print(f"Seed                       : {SEED}")
print(f"Train/Val overlap          : {overlap}")
print(f"Clean test images          : {len(y_true)}")
print(f"Epochs trained             : {len(history_data['loss'])}")
print(f"Best epoch by val loss     : {best_epoch_loss}")
print(f"Best validation loss       : {best_val_loss:.4f}")
print(f"Val accuracy at best epoch : {best_val_acc_at_best_loss * 100:.2f}%")
print(f"Best epoch by val accuracy : {best_val_accuracy_epoch}")
print(f"Best validation accuracy   : {best_val_accuracy * 100:.2f}%")
print(f"Final train accuracy       : {final_train_accuracy * 100:.2f}%")
print(f"Final validation accuracy  : {final_val_accuracy * 100:.2f}%")
print(f"Clean test accuracy        : {accuracy * 100:.2f}%")
print(f"Clean test Macro F1        : {macro_f1:.4f}")
print(f"Clean test Weighted F1     : {weighted_f1:.4f}")
print("\nBest model saved to:")
print(MODEL_PATH)
print("\nResults saved to:")
print(RESULT_DIR)
print("=" * 70)
