import os
import numpy as np
import tensorflow as tf

from sklearn.model_selection import train_test_split


# ============================================================
# CONFIGURATION
# ============================================================

DATASET_PATH = "ai-service/data/raw/fer2013"

IMG_SIZE = (48, 48)
BATCH_SIZE = 32
VALIDATION_SIZE = 0.20
RANDOM_SEED = 42

CLASSES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise"
]


# ============================================================
# LOAD IMAGE PATHS AND LABELS
# ============================================================

def collect_image_paths():

    image_paths = []
    labels = []

    train_path = os.path.join(DATASET_PATH, "train")

    for label, emotion in enumerate(CLASSES):

        emotion_path = os.path.join(train_path, emotion)

        if not os.path.exists(emotion_path):
            raise FileNotFoundError(
                f"Dataset folder not found: {emotion_path}"
            )

        for filename in os.listdir(emotion_path):

            if filename.lower().endswith(
                (".jpg", ".jpeg", ".png")
            ):

                image_paths.append(
                    os.path.join(emotion_path, filename)
                )

                labels.append(label)

    return np.array(image_paths), np.array(labels)


# ============================================================
# IMAGE PREPROCESSING
# ============================================================

def load_and_preprocess_image(image_path, label):

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

    # Convert pixel values from [0, 255] to [0, 1]
    image = tf.cast(image, tf.float32) / 255.0

    return image, label


# ============================================================
# CREATE DATASETS
# ============================================================

def create_dataset(image_paths, labels, training=False):

    dataset = tf.data.Dataset.from_tensor_slices(
        (image_paths, labels)
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

    dataset = dataset.batch(BATCH_SIZE)

    dataset = dataset.prefetch(
        tf.data.AUTOTUNE
    )

    return dataset


# ============================================================
# MAIN
# ============================================================

def main():

    print("\n" + "=" * 60)
    print("FER-2013 PREPROCESSING")
    print("=" * 60)

    # --------------------------------------------------------
    # Collect images
    # --------------------------------------------------------

    image_paths, labels = collect_image_paths()

    print(f"\nTotal training images: {len(image_paths)}")

    # --------------------------------------------------------
    # Stratified train-validation split
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

    print(f"Training images     : {len(train_paths)}")
    print(f"Validation images   : {len(val_paths)}")

    # --------------------------------------------------------
    # Class distribution
    # --------------------------------------------------------

    print("\nClass distribution:")
    print("-" * 60)

    for index, emotion in enumerate(CLASSES):

        train_count = np.sum(
            train_labels == index
        )

        val_count = np.sum(
            val_labels == index
        )

        print(
            f"{emotion:10s} | "
            f"Train: {train_count:5d} | "
            f"Validation: {val_count:5d}"
        )

    # --------------------------------------------------------
    # Create TensorFlow datasets
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
    # Check one batch
    # --------------------------------------------------------

    images, batch_labels = next(
        iter(train_dataset)
    )

    print("\nBatch verification:")
    print(f"Image shape : {images.shape}")
    print(f"Label shape : {batch_labels.shape}")
    print(
        f"Pixel range: "
        f"{tf.reduce_min(images).numpy():.4f} - "
        f"{tf.reduce_max(images).numpy():.4f}"
    )

    # --------------------------------------------------------
    # Final information
    # --------------------------------------------------------

    print("\nPreprocessing completed successfully.")

    print("\nDataset:")
    print(f"  Image size       : {IMG_SIZE}")
    print("  Channels         : 1 (grayscale)")
    print("  Normalization    : [0, 1]")
    print(f"  Batch size       : {BATCH_SIZE}")
    print(f"  Validation split : {VALIDATION_SIZE * 100:.0f}%")
    print("  Split strategy   : Stratified")

    print("\n" + "=" * 60)


if __name__ == "__main__":
    main()