import os
import glob
import csv
import numpy as np
import tensorflow as tf

# ============================================================
# CONFIGURATION
# ============================================================

SEED = 42
tf.keras.utils.set_random_seed(SEED)

IMAGE_SIZE = (48, 48)
BATCH_SIZE = 32

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

TEST_DIR = os.path.join(
    DATA_DIR,
    "test"
)

MODEL_PATH = os.path.join(
    BASE_DIR,
    "src",
    "models",
    "improved_cnn.keras"
)

OUTPUT_DIR = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "facial_emotion"
)

OUTPUT_FILE = os.path.join(
    OUTPUT_DIR,
    "facial_emotion_features.csv"
)

os.makedirs(
    OUTPUT_DIR,
    exist_ok=True
)


# ============================================================
# LOAD MODEL
# ============================================================

print("\n" + "=" * 70)
print("FACIAL EMOTION FEATURE EXTRACTION")
print("=" * 70)

print("\nLoading trained model...")

model = tf.keras.models.load_model(
    MODEL_PATH
)

print("Model loaded successfully.")


# ============================================================
# COLLECT IMAGE PATHS
# ============================================================

def collect_test_images():

    image_paths = []
    labels = []

    for label_index, class_name in enumerate(CLASS_NAMES):

        class_dir = os.path.join(
            TEST_DIR,
            class_name
        )

        for extension in [
            "*.jpg",
            "*.jpeg",
            "*.png"
        ]:

            files = glob.glob(
                os.path.join(
                    class_dir,
                    extension
                )
            )

            for file_path in files:

                image_paths.append(
                    file_path
                )

                labels.append(
                    label_index
                )

    return (
        np.array(image_paths),
        np.array(labels)
    )


image_paths, true_labels = collect_test_images()

print(
    f"\nTotal images: {len(image_paths)}"
)


# ============================================================
# IMAGE PREPROCESSING
# ============================================================

def load_image(path):

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

    image = tf.cast(
        image,
        tf.float32
    ) / 255.0

    image.set_shape(
        [IMAGE_SIZE[0], IMAGE_SIZE[1], 1]
    )

    return image


# ============================================================
# CREATE DATASET
# ============================================================

def create_dataset(paths):

    dataset = tf.data.Dataset.from_tensor_slices(
        paths
    )

    dataset = dataset.map(
        load_image,
        num_parallel_calls=tf.data.AUTOTUNE
    )

    dataset = dataset.batch(
        BATCH_SIZE
    )

    dataset = dataset.prefetch(
        tf.data.AUTOTUNE
    )

    return dataset


dataset = create_dataset(
    image_paths
)


# ============================================================
# EXTRACT EMOTION PROBABILITIES
# ============================================================

print("\nExtracting facial emotion features...")

probabilities = model.predict(
    dataset,
    verbose=1
)

print(
    "\nFeature matrix shape:",
    probabilities.shape
)


# ============================================================
# PREDICTED EMOTIONS
# ============================================================

predicted_labels = np.argmax(
    probabilities,
    axis=1
)

predicted_emotions = [
    CLASS_NAMES[index]
    for index in predicted_labels
]


# ============================================================
# ADD DERIVED FEATURES
# ============================================================

angry = probabilities[:, 0]
disgust = probabilities[:, 1]
fear = probabilities[:, 2]
happy = probabilities[:, 3]
neutral = probabilities[:, 4]
sad = probabilities[:, 5]
surprise = probabilities[:, 6]


# Negative emotional probability

negative_emotion = (
    angry +
    disgust +
    fear +
    sad
)


# Positive emotional probability

positive_emotion = happy


# Emotional variability / uncertainty

emotion_entropy = -np.sum(
    probabilities *
    np.log(
        probabilities + 1e-8
    ),
    axis=1
)


# ============================================================
# SAVE CSV
# ============================================================

print("\nSaving extracted features...")

with open(
    OUTPUT_FILE,
    "w",
    newline="",
    encoding="utf-8"
) as file:

    writer = csv.writer(file)

    header = [
        "image_path",
        "true_label",

        "angry_probability",
        "disgust_probability",
        "fear_probability",
        "happy_probability",
        "neutral_probability",
        "sad_probability",
        "surprise_probability",

        "predicted_emotion",

        "negative_emotion_probability",
        "positive_emotion_probability",
        "emotion_entropy"
    ]

    writer.writerow(
        header
    )

    for i in range(
        len(image_paths)
    ):

        writer.writerow(
            [
                image_paths[i],

                CLASS_NAMES[
                    true_labels[i]
                ],

                float(
                    angry[i]
                ),

                float(
                    disgust[i]
                ),

                float(
                    fear[i]
                ),

                float(
                    happy[i]
                ),

                float(
                    neutral[i]
                ),

                float(
                    sad[i]
                ),

                float(
                    surprise[i]
                ),

                predicted_emotions[i],

                float(
                    negative_emotion[i]
                ),

                float(
                    positive_emotion[i]
                ),

                float(
                    emotion_entropy[i]
                )
            ]
        )


# ============================================================
# SAVE NUMPY FEATURE MATRIX
# ============================================================

feature_matrix = np.column_stack(
    [
        angry,
        disgust,
        fear,
        happy,
        neutral,
        sad,
        surprise,
        negative_emotion,
        positive_emotion,
        emotion_entropy
    ]
)

npy_path = os.path.join(
    OUTPUT_DIR,
    "facial_emotion_features.npy"
)

np.save(
    npy_path,
    feature_matrix
)


# ============================================================
# SUMMARY
# ============================================================

print("\n" + "=" * 70)
print("FEATURE EXTRACTION COMPLETED")
print("=" * 70)

print(
    f"Images processed : {len(image_paths)}"
)

print(
    f"Feature matrix   : {feature_matrix.shape}"
)

print(
    f"CSV file         : {OUTPUT_FILE}"
)

print(
    f"NumPy file       : {npy_path}"
)

print("\nFeatures extracted:")

for feature in [
    "Angry probability",
    "Disgust probability",
    "Fear probability",
    "Happy probability",
    "Neutral probability",
    "Sad probability",
    "Surprise probability",
    "Negative emotion probability",
    "Positive emotion probability",
    "Emotion entropy"
]:

    print(
        f"  ✓ {feature}"
    )

print("=" * 70)