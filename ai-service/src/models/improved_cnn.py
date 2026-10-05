import os
import glob
import numpy as np
import tensorflow as tf
import matplotlib.pyplot as plt

from sklearn.model_selection import train_test_split
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

SEED = 42
tf.keras.utils.set_random_seed(SEED)

IMAGE_SIZE = (48, 48)
BATCH_SIZE = 32
EPOCHS = 50

NUM_CLASSES = 7

CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise"
]

BASE_DIR = "ai-service"
DATA_DIR = os.path.join(
    BASE_DIR,
    "data",
    "raw",
    "fer2013"
)

TRAIN_DIR = os.path.join(DATA_DIR, "train")
TEST_DIR = os.path.join(DATA_DIR, "test")

RESULT_DIR = os.path.join(
    BASE_DIR,
    "results",
    "facial_emotion",
    "improved_cnn"
)

MODEL_PATH = os.path.join(
    BASE_DIR,
    "src",
    "models",
    "improved_cnn.keras"
)

os.makedirs(RESULT_DIR, exist_ok=True)


# ============================================================
# COLLECT IMAGE PATHS
# ============================================================

def collect_image_paths():

    image_paths = []
    labels = []

    for label_index, class_name in enumerate(CLASS_NAMES):

        class_dir = os.path.join(TRAIN_DIR, class_name)

        files = []

        for extension in ["*.jpg", "*.jpeg", "*.png"]:
            files.extend(
                glob.glob(
                    os.path.join(class_dir, extension)
                )
            )

        for file_path in files:
            image_paths.append(file_path)
            labels.append(label_index)

    return np.array(image_paths), np.array(labels)


# ============================================================
# LOAD IMAGE
# ============================================================

def load_image(path, label):

    image = tf.io.read_file(path)

    image = tf.image.decode_image(
        image,
        channels=1,
        expand_animations=False
    )

    image = tf.image.resize(
        image,
        IMAGE_SIZE
    )

    image = tf.cast(image, tf.float32) / 255.0

    image.set_shape(
        [IMAGE_SIZE[0], IMAGE_SIZE[1], 1]
    )

    return image, label


# ============================================================
# DATA AUGMENTATION
# ============================================================

data_augmentation = tf.keras.Sequential(
    [
        tf.keras.layers.RandomFlip(
            mode="horizontal"
        ),

        tf.keras.layers.RandomRotation(
            factor=0.05
        ),

        tf.keras.layers.RandomZoom(
            height_factor=0.08,
            width_factor=0.08
        ),

        tf.keras.layers.RandomTranslation(
            height_factor=0.05,
            width_factor=0.05
        ),
    ],
    name="data_augmentation"
)


# ============================================================
# CREATE DATASET
# ============================================================

def create_dataset(paths, labels, training=False):

    dataset = tf.data.Dataset.from_tensor_slices(
        (paths, labels)
    )

    if training:
        dataset = dataset.shuffle(
            buffer_size=len(paths),
            seed=SEED,
            reshuffle_each_iteration=True
        )

    dataset = dataset.map(
        load_image,
        num_parallel_calls=tf.data.AUTOTUNE
    )

    if training:

        dataset = dataset.map(
            lambda x, y: (
                data_augmentation(x, training=True),
                y
            ),
            num_parallel_calls=tf.data.AUTOTUNE
        )

    dataset = dataset.batch(
        BATCH_SIZE
    )

    dataset = dataset.prefetch(
        tf.data.AUTOTUNE
    )

    return dataset


# ============================================================
# BUILD IMPROVED CNN
# ============================================================

def build_model():

    inputs = tf.keras.Input(
        shape=(48, 48, 1)
    )

    # --------------------------------------------------------
    # Block 1
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        32,
        (3, 3),
        padding="same",
        use_bias=False
    )(inputs)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.Activation(
        "relu"
    )(x)

    x = tf.keras.layers.Conv2D(
        32,
        (3, 3),
        padding="same",
        use_bias=False
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.Activation(
        "relu"
    )(x)

    x = tf.keras.layers.MaxPooling2D(
        (2, 2)
    )(x)

    x = tf.keras.layers.Dropout(
        0.20
    )(x)

    # --------------------------------------------------------
    # Block 2
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        64,
        (3, 3),
        padding="same",
        use_bias=False
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.Activation(
        "relu"
    )(x)

    x = tf.keras.layers.Conv2D(
        64,
        (3, 3),
        padding="same",
        use_bias=False
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.Activation(
        "relu"
    )(x)

    x = tf.keras.layers.MaxPooling2D(
        (2, 2)
    )(x)

    x = tf.keras.layers.Dropout(
        0.25
    )(x)

    # --------------------------------------------------------
    # Block 3
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        128,
        (3, 3),
        padding="same",
        use_bias=False
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.Activation(
        "relu"
    )(x)

    x = tf.keras.layers.Conv2D(
        128,
        (3, 3),
        padding="same",
        use_bias=False
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.Activation(
        "relu"
    )(x)

    x = tf.keras.layers.MaxPooling2D(
        (2, 2)
    )(x)

    x = tf.keras.layers.Dropout(
        0.30
    )(x)

    # --------------------------------------------------------
    # Feature Representation
    # --------------------------------------------------------

    x = tf.keras.layers.GlobalAveragePooling2D()(x)

    x = tf.keras.layers.Dense(
        128,
        activation="relu"
    )(x)

    x = tf.keras.layers.Dropout(
        0.35
    )(x)

    outputs = tf.keras.layers.Dense(
        NUM_CLASSES,
        activation="softmax"
    )(x)

    model = tf.keras.Model(
        inputs,
        outputs,
        name="Improved_CNN"
    )

    return model


# ============================================================
# MAIN
# ============================================================

print("\n" + "=" * 70)
print("IMPROVED CNN - FER-2013")
print("=" * 70)

print("\nCollecting training images...")

all_paths, all_labels = collect_image_paths()

print(
    f"Total training images: {len(all_paths)}"
)


# ============================================================
# STRATIFIED TRAIN / VALIDATION SPLIT
# ============================================================

train_paths, val_paths, train_labels, val_labels = train_test_split(
    all_paths,
    all_labels,
    test_size=0.20,
    random_state=SEED,
    stratify=all_labels
)

print(
    f"Training images   : {len(train_paths)}"
)

print(
    f"Validation images : {len(val_paths)}"
)


# ============================================================
# CLASS WEIGHTS
# ============================================================

classes = np.unique(train_labels)

class_weights_array = compute_class_weight(
    class_weight="balanced",
    classes=classes,
    y=train_labels
)

class_weights = {
    int(cls): float(weight)
    for cls, weight in zip(
        classes,
        class_weights_array
    )
}

print("\nClass weights:")

for class_index, weight in class_weights.items():

    print(
        f"{CLASS_NAMES[class_index]:10s}: {weight:.3f}"
    )


# ============================================================
# DATASETS
# ============================================================

train_dataset = create_dataset(
    train_paths,
    train_labels,
    training=True
)

val_dataset = create_dataset(
    val_paths,
    val_labels,
    training=False
)


# ============================================================
# MODEL
# ============================================================

model = build_model()

model.summary()


# ============================================================
# OPTIMIZER
# ============================================================

optimizer = tf.keras.optimizers.AdamW(
    learning_rate=0.001,
    weight_decay=0.0001
)


model.compile(
    optimizer=optimizer,

    loss=tf.keras.losses.SparseCategoricalCrossentropy(),

    metrics=[
        tf.keras.metrics.SparseCategoricalAccuracy(
            name="accuracy"
        )
    ]
)


# ============================================================
# CALLBACKS
# ============================================================

checkpoint = tf.keras.callbacks.ModelCheckpoint(
    MODEL_PATH,
    monitor="val_loss",
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


# ============================================================
# TRAINING
# ============================================================

print("\n" + "=" * 70)
print("STARTING IMPROVED CNN TRAINING")
print("=" * 70)

history = model.fit(

    train_dataset,

    validation_data=val_dataset,

    epochs=EPOCHS,

    class_weight=class_weights,

    callbacks=[
        checkpoint,
        early_stopping,
        reduce_lr
    ],

    verbose=1
)


# ============================================================
# LOAD BEST MODEL
# ============================================================

print("\nLoading best model...")

model = tf.keras.models.load_model(
    MODEL_PATH
)


# ============================================================
# TEST DATA
# ============================================================

def collect_test_data():

    paths = []
    labels = []

    for label_index, class_name in enumerate(CLASS_NAMES):

        class_dir = os.path.join(
            TEST_DIR,
            class_name
        )

        files = []

        for extension in ["*.jpg", "*.jpeg", "*.png"]:
            files.extend(
                glob.glob(
                    os.path.join(
                        class_dir,
                        extension
                    )
                )
            )

        for file_path in files:

            paths.append(file_path)
            labels.append(label_index)

    return np.array(paths), np.array(labels)


test_paths, test_labels = collect_test_data()

print(
    f"\nUntouched test images: {len(test_paths)}"
)

test_dataset = create_dataset(
    test_paths,
    test_labels,
    training=False
)


# ============================================================
# TEST PREDICTIONS
# ============================================================

print("\nEvaluating on untouched test set...")

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

accuracy = accuracy_score(
    test_labels,
    predictions
)

precision = precision_score(
    test_labels,
    predictions,
    average="weighted",
    zero_division=0
)

recall = recall_score(
    test_labels,
    predictions,
    average="weighted",
    zero_division=0
)

weighted_f1 = f1_score(
    test_labels,
    predictions,
    average="weighted",
    zero_division=0
)

macro_f1 = f1_score(
    test_labels,
    predictions,
    average="macro",
    zero_division=0
)


print("\n" + "=" * 70)
print("FINAL IMPROVED CNN TEST RESULTS")
print("=" * 70)

print(
    f"Accuracy           : {accuracy * 100:.2f}%"
)

print(
    f"Weighted Precision : {precision * 100:.2f}%"
)

print(
    f"Weighted Recall    : {recall * 100:.2f}%"
)

print(
    f"Weighted F1        : {weighted_f1 * 100:.2f}%"
)

print(
    f"Macro F1           : {macro_f1 * 100:.2f}%"
)


# ============================================================
# CLASSIFICATION REPORT
# ============================================================

report = classification_report(
    test_labels,
    predictions,
    target_names=CLASS_NAMES,
    digits=4,
    zero_division=0
)

print("\nClassification Report:")
print(report)


# ============================================================
# SAVE METRICS
# ============================================================

metrics_file = os.path.join(
    RESULT_DIR,
    "test_metrics.txt"
)

with open(
    metrics_file,
    "w",
    encoding="utf-8"
) as f:

    f.write(
        "IMPROVED CNN - FER-2013\n"
    )

    f.write(
        "=" * 60 + "\n"
    )

    f.write(
        f"Accuracy: {accuracy:.4f}\n"
    )

    f.write(
        f"Weighted Precision: {precision:.4f}\n"
    )

    f.write(
        f"Weighted Recall: {recall:.4f}\n"
    )

    f.write(
        f"Weighted F1: {weighted_f1:.4f}\n"
    )

    f.write(
        f"Macro F1: {macro_f1:.4f}\n\n"
    )

    f.write(
        report
    )


# ============================================================
# CONFUSION MATRIX
# ============================================================

cm = confusion_matrix(
    test_labels,
    predictions
)

plt.figure(
    figsize=(9, 7)
)

plt.imshow(
    cm,
    interpolation="nearest"
)

plt.title(
    "Improved CNN - FER-2013 Confusion Matrix"
)

plt.colorbar()

plt.xticks(
    np.arange(NUM_CLASSES),
    CLASS_NAMES,
    rotation=45
)

plt.yticks(
    np.arange(NUM_CLASSES),
    CLASS_NAMES
)

plt.xlabel(
    "Predicted Label"
)

plt.ylabel(
    "True Label"
)

plt.tight_layout()

plt.savefig(
    os.path.join(
        RESULT_DIR,
        "confusion_matrix.png"
    ),
    dpi=300
)

plt.close()


# ============================================================
# TRAINING CURVES
# ============================================================

history_dict = history.history

plt.figure(
    figsize=(9, 6)
)

plt.plot(
    history_dict["accuracy"],
    label="Training Accuracy"
)

plt.plot(
    history_dict["val_accuracy"],
    label="Validation Accuracy"
)

plt.xlabel("Epoch")

plt.ylabel("Accuracy")

plt.title(
    "Improved CNN Accuracy"
)

plt.legend()

plt.grid(True)

plt.tight_layout()

plt.savefig(
    os.path.join(
        RESULT_DIR,
        "accuracy_curve.png"
    ),
    dpi=300
)

plt.close()


plt.figure(
    figsize=(9, 6)
)

plt.plot(
    history_dict["loss"],
    label="Training Loss"
)

plt.plot(
    history_dict["val_loss"],
    label="Validation Loss"
)

plt.xlabel("Epoch")

plt.ylabel("Loss")

plt.title(
    "Improved CNN Loss"
)

plt.legend()

plt.grid(True)

plt.tight_layout()

plt.savefig(
    os.path.join(
        RESULT_DIR,
        "loss_curve.png"
    ),
    dpi=300
)

plt.close()


# ============================================================
# BEST EPOCH INFORMATION
# ============================================================

best_epoch = np.argmin(
    history_dict["val_loss"]
) + 1

best_val_loss = min(
    history_dict["val_loss"]
)

best_val_accuracy = history_dict[
    "val_accuracy"
][best_epoch - 1]

train_accuracy_at_best = history_dict[
    "accuracy"
][best_epoch - 1]

train_val_gap = (
    train_accuracy_at_best -
    best_val_accuracy
)


print("\n" + "=" * 70)
print("TRAINING ANALYSIS")
print("=" * 70)

print(
    f"Best Epoch             : {best_epoch}"
)

print(
    f"Best Validation Loss   : {best_val_loss:.4f}"
)

print(
    f"Train Accuracy         : "
    f"{train_accuracy_at_best * 100:.2f}%"
)

print(
    f"Validation Accuracy    : "
    f"{best_val_accuracy * 100:.2f}%"
)

print(
    f"Train-Val Gap          : "
    f"{train_val_gap * 100:.2f} percentage points"
)


print("\nSaved files:")

print(
    f"Best model : {MODEL_PATH}"
)

print(
    f"Results    : {RESULT_DIR}"
)

print("=" * 70)