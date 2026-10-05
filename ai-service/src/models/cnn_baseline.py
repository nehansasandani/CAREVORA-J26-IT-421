import os
import numpy as np
import tensorflow as tf

from sklearn.model_selection import train_test_split
from sklearn.utils.class_weight import compute_class_weight
from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    precision_score,
    recall_score,
    f1_score,
    accuracy_score
)

import matplotlib.pyplot as plt


# ============================================================
# CONFIGURATION
# ============================================================

DATASET_PATH = "ai-service/data/raw/fer2013"

RESULTS_PATH = "ai-service/results/facial_emotion/cnn_baseline"
MODEL_PATH = "ai-service/src/models/cnn_baseline.keras"

IMG_SIZE = (48, 48)
BATCH_SIZE = 32

VALIDATION_SIZE = 0.20
RANDOM_SEED = 42

EPOCHS = 30

CLASSES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise"
]

NUM_CLASSES = len(CLASSES)


# ============================================================
# REPRODUCIBILITY
# ============================================================

tf.keras.utils.set_random_seed(RANDOM_SEED)


# ============================================================
# COLLECT IMAGE PATHS
# ============================================================

def collect_image_paths():

    image_paths = []
    labels = []

    train_path = os.path.join(
        DATASET_PATH,
        "train"
    )

    for label, emotion in enumerate(CLASSES):

        emotion_path = os.path.join(
            train_path,
            emotion
        )

        if not os.path.exists(emotion_path):
            raise FileNotFoundError(
                f"Dataset folder not found: {emotion_path}"
            )

        for filename in os.listdir(emotion_path):

            if filename.lower().endswith(
                (".jpg", ".jpeg", ".png")
            ):

                image_paths.append(
                    os.path.join(
                        emotion_path,
                        filename
                    )
                )

                labels.append(label)

    return (
        np.array(image_paths),
        np.array(labels)
    )


# ============================================================
# IMAGE PREPROCESSING
# ============================================================

def load_and_preprocess_image(
    image_path,
    label
):

    image = tf.io.read_file(image_path)

    image = tf.image.decode_image(
        image,
        channels=1,
        expand_animations=False
    )

    image = tf.image.resize(
        image,
        IMG_SIZE
    )

    image = tf.cast(
        image,
        tf.float32
    ) / 255.0

    return image, label


# ============================================================
# DATASET CREATION
# ============================================================

def create_dataset(
    image_paths,
    labels,
    training=False
):

    dataset = tf.data.Dataset.from_tensor_slices(
        (
            image_paths,
            labels
        )
    )

    dataset = dataset.map(
        load_and_preprocess_image,
        num_parallel_calls=tf.data.AUTOTUNE
    )

    if training:

        dataset = dataset.shuffle(
            buffer_size=len(image_paths),
            seed=RANDOM_SEED
        )

    dataset = dataset.batch(
        BATCH_SIZE
    )

    dataset = dataset.prefetch(
        tf.data.AUTOTUNE
    )

    return dataset


# ============================================================
# CNN MODEL
# ============================================================

def build_cnn_model():

    inputs = tf.keras.Input(
        shape=(48, 48, 1),
        name="input_image"
    )

    # --------------------------------------------------------
    # Block 1
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        32,
        (3, 3),
        padding="same",
        activation=None
    )(inputs)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.ReLU()(x)

    x = tf.keras.layers.MaxPooling2D(
        (2, 2)
    )(x)

    x = tf.keras.layers.Dropout(
        0.25
    )(x)

    # --------------------------------------------------------
    # Block 2
    # --------------------------------------------------------

    x = tf.keras.layers.Conv2D(
        64,
        (3, 3),
        padding="same",
        activation=None
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.ReLU()(x)

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
        activation=None
    )(x)

    x = tf.keras.layers.BatchNormalization()(x)

    x = tf.keras.layers.ReLU()(x)

    x = tf.keras.layers.MaxPooling2D(
        (2, 2)
    )(x)

    x = tf.keras.layers.Dropout(
        0.30
    )(x)

    # --------------------------------------------------------
    # Classification head
    # --------------------------------------------------------

    x = tf.keras.layers.GlobalAveragePooling2D()(x)

    x = tf.keras.layers.Dense(
        128,
        activation="relu"
    )(x)

    x = tf.keras.layers.Dropout(
        0.40
    )(x)

    outputs = tf.keras.layers.Dense(
        NUM_CLASSES,
        activation="softmax",
        name="emotion_output"
    )(x)

    model = tf.keras.Model(
        inputs=inputs,
        outputs=outputs,
        name="FER2013_CNN_Baseline"
    )

    return model


# ============================================================
# CLASS WEIGHTS
# ============================================================

def calculate_class_weights(labels):

    classes = np.unique(labels)

    weights = compute_class_weight(
        class_weight="balanced",
        classes=classes,
        y=labels
    )

    class_weights = {
        int(class_id): float(weight)
        for class_id, weight
        in zip(classes, weights)
    }

    return class_weights


# ============================================================
# PLOT TRAINING HISTORY
# ============================================================

def plot_training_history(history):

    os.makedirs(
        RESULTS_PATH,
        exist_ok=True
    )

    # Accuracy
    plt.figure(figsize=(10, 6))

    plt.plot(
        history.history["accuracy"],
        label="Training Accuracy"
    )

    plt.plot(
        history.history["val_accuracy"],
        label="Validation Accuracy"
    )

    plt.title(
        "CNN Baseline - Accuracy"
    )

    plt.xlabel("Epoch")
    plt.ylabel("Accuracy")

    plt.legend()
    plt.grid(True)

    plt.tight_layout()

    plt.savefig(
        os.path.join(
            RESULTS_PATH,
            "accuracy_curve.png"
        ),
        dpi=300
    )

    plt.close()

    # Loss
    plt.figure(figsize=(10, 6))

    plt.plot(
        history.history["loss"],
        label="Training Loss"
    )

    plt.plot(
        history.history["val_loss"],
        label="Validation Loss"
    )

    plt.title(
        "CNN Baseline - Loss"
    )

    plt.xlabel("Epoch")
    plt.ylabel("Loss")

    plt.legend()
    plt.grid(True)

    plt.tight_layout()

    plt.savefig(
        os.path.join(
            RESULTS_PATH,
            "loss_curve.png"
        ),
        dpi=300
    )

    plt.close()


# ============================================================
# CONFUSION MATRIX
# ============================================================

def save_confusion_matrix(
    y_true,
    y_pred
):

    cm = confusion_matrix(
        y_true,
        y_pred
    )

    plt.figure(
        figsize=(9, 7)
    )

    plt.imshow(
        cm,
        interpolation="nearest"
    )

    plt.title(
        "CNN Baseline - Confusion Matrix"
    )

    plt.colorbar()

    tick_marks = np.arange(
        NUM_CLASSES
    )

    plt.xticks(
        tick_marks,
        CLASSES,
        rotation=45
    )

    plt.yticks(
        tick_marks,
        CLASSES
    )

    threshold = cm.max() / 2.0

    for i in range(NUM_CLASSES):

        for j in range(NUM_CLASSES):

            plt.text(
                j,
                i,
                str(cm[i, j]),
                horizontalalignment="center",
                color="white"
                if cm[i, j] > threshold
                else "black"
            )

    plt.ylabel(
        "True Emotion"
    )

    plt.xlabel(
        "Predicted Emotion"
    )

    plt.tight_layout()

    plt.savefig(
        os.path.join(
            RESULTS_PATH,
            "confusion_matrix.png"
        ),
        dpi=300
    )

    plt.close()


# ============================================================
# MAIN
# ============================================================

def main():

    print("\n" + "=" * 70)
    print("FER-2013 CNN BASELINE TRAINING")
    print("=" * 70)

    os.makedirs(
        RESULTS_PATH,
        exist_ok=True
    )

    # --------------------------------------------------------
    # Load paths
    # --------------------------------------------------------

    image_paths, labels = collect_image_paths()

    print(
        f"\nTotal training images: {len(image_paths)}"
    )

    # --------------------------------------------------------
    # Stratified split
    # --------------------------------------------------------

    train_paths, val_paths, train_labels, val_labels = (
        train_test_split(
            image_paths,
            labels,
            test_size=VALIDATION_SIZE,
            random_state=RANDOM_SEED,
            stratify=labels
        )
    )

    print(
        f"Training images    : {len(train_paths)}"
    )

    print(
        f"Validation images  : {len(val_paths)}"
    )

    # --------------------------------------------------------
    # Create datasets
    # --------------------------------------------------------

    train_dataset = create_dataset(
        train_paths,
        train_labels,
        training=True
    )

    validation_dataset = create_dataset(
        val_paths,
        val_labels,
        training=False
    )

    # --------------------------------------------------------
    # Class weights
    # --------------------------------------------------------

    class_weights = calculate_class_weights(
        train_labels
    )

    print("\nClass weights:")

    for class_id, weight in class_weights.items():

        print(
            f"{CLASSES[class_id]:10s}: "
            f"{weight:.4f}"
        )

    # --------------------------------------------------------
    # Build model
    # --------------------------------------------------------

    model = build_cnn_model()

    model.compile(
        optimizer=tf.keras.optimizers.Adam(
            learning_rate=0.001
        ),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )

    print("\nModel summary:")

    model.summary()

    # --------------------------------------------------------
    # Callbacks
    # --------------------------------------------------------

    early_stopping = tf.keras.callbacks.EarlyStopping(
        monitor="val_loss",
        patience=5,
        restore_best_weights=True,
        verbose=1
    )

    model_checkpoint = tf.keras.callbacks.ModelCheckpoint(
        MODEL_PATH,
        monitor="val_loss",
        save_best_only=True,
        verbose=1
    )

    reduce_lr = tf.keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=2,
        min_lr=1e-6,
        verbose=1
    )

    # --------------------------------------------------------
    # Training
    # --------------------------------------------------------

    print("\nStarting training...\n")

    history = model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=EPOCHS,
        class_weight=class_weights,
        callbacks=[
            early_stopping,
            model_checkpoint,
            reduce_lr
        ]
    )

    # --------------------------------------------------------
    # Save training curves
    # --------------------------------------------------------

    plot_training_history(
        history
    )

    # --------------------------------------------------------
    # Load best model
    # --------------------------------------------------------

    best_model = tf.keras.models.load_model(
        MODEL_PATH
    )

    # --------------------------------------------------------
    # Test dataset
    # --------------------------------------------------------

    test_paths = []
    test_labels = []

    test_path = os.path.join(
        DATASET_PATH,
        "test"
    )

    for label, emotion in enumerate(CLASSES):

        emotion_path = os.path.join(
            test_path,
            emotion
        )

        for filename in os.listdir(
            emotion_path
        ):

            if filename.lower().endswith(
                (".jpg", ".jpeg", ".png")
            ):

                test_paths.append(
                    os.path.join(
                        emotion_path,
                        filename
                    )
                )

                test_labels.append(
                    label
                )

    test_paths = np.array(
        test_paths
    )

    test_labels = np.array(
        test_labels
    )

    test_dataset = create_dataset(
        test_paths,
        test_labels,
        training=False
    )

    # --------------------------------------------------------
    # Predictions
    # --------------------------------------------------------

    print("\nEvaluating on untouched test set...")

    probabilities = best_model.predict(
        test_dataset,
        verbose=1
    )

    y_pred = np.argmax(
        probabilities,
        axis=1
    )

    y_true = test_labels

    # --------------------------------------------------------
    # Metrics
    # --------------------------------------------------------

    accuracy = accuracy_score(
        y_true,
        y_pred
    )

    precision = precision_score(
        y_true,
        y_pred,
        average="weighted",
        zero_division=0
    )

    recall = recall_score(
        y_true,
        y_pred,
        average="weighted",
        zero_division=0
    )

    f1 = f1_score(
        y_true,
        y_pred,
        average="weighted",
        zero_division=0
    )

    macro_f1 = f1_score(
        y_true,
        y_pred,
        average="macro",
        zero_division=0
    )

    # --------------------------------------------------------
    # Results
    # --------------------------------------------------------

    print("\n" + "=" * 70)
    print("FINAL CNN BASELINE TEST RESULTS")
    print("=" * 70)

    print(
        f"Accuracy          : {accuracy * 100:.2f}%"
    )

    print(
        f"Weighted Precision : {precision * 100:.2f}%"
    )

    print(
        f"Weighted Recall    : {recall * 100:.2f}%"
    )

    print(
        f"Weighted F1        : {f1 * 100:.2f}%"
    )

    print(
        f"Macro F1           : {macro_f1 * 100:.2f}%"
    )

    # --------------------------------------------------------
    # Classification report
    # --------------------------------------------------------

    report = classification_report(
        y_true,
        y_pred,
        target_names=CLASSES,
        zero_division=0
    )

    print("\nClassification Report:")
    print(report)

    with open(
        os.path.join(
            RESULTS_PATH,
            "classification_report.txt"
        ),
        "w"
    ) as file:

        file.write(report)

    # --------------------------------------------------------
    # Confusion matrix
    # --------------------------------------------------------

    save_confusion_matrix(
        y_true,
        y_pred
    )

    # --------------------------------------------------------
    # Save metrics
    # --------------------------------------------------------

    metrics_path = os.path.join(
        RESULTS_PATH,
        "test_metrics.txt"
    )

    with open(
        metrics_path,
        "w"
    ) as file:

        file.write(
            f"Accuracy: {accuracy:.6f}\n"
        )

        file.write(
            f"Weighted Precision: {precision:.6f}\n"
        )

        file.write(
            f"Weighted Recall: {recall:.6f}\n"
        )

        file.write(
            f"Weighted F1: {f1:.6f}\n"
        )

        file.write(
            f"Macro F1: {macro_f1:.6f}\n"
        )

    print("\nSaved files:")
    print(
        f"Best model          : {MODEL_PATH}"
    )

    print(
        f"Results directory   : {RESULTS_PATH}"
    )

    print("=" * 70)


if __name__ == "__main__":
    main()