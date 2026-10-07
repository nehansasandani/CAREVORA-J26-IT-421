import os
import csv
import numpy as np
import tensorflow as tf
from pathlib import Path


# ============================================================
# CONFIGURATION
# ============================================================

MODEL_PATH = (
    "ai-service/src/models/clean_seed/seed42/"
    "transfer_emotion_clean.keras"
)

DATASET_DIR = "ai-service/data/raw/fer2013_clean/test"

OUTPUT_DIR = "ai-service/results/facial_emotion/features"

OUTPUT_CSV = os.path.join(
    OUTPUT_DIR,
    "fer2013_emotion_features_seed42.csv"
)

IMG_SIZE = (96, 96)

CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise"
]


# ============================================================
# LOAD MODEL
# ============================================================

print("=" * 70)
print("EMOTION FEATURE EXTRACTION")
print("=" * 70)

print("\nLoading EfficientNetB0 model...")

model = tf.keras.models.load_model(MODEL_PATH)

print("Model loaded successfully.")
print("Input shape :", model.input_shape)
print("Output shape:", model.output_shape)


# ============================================================
# CREATE OUTPUT DIRECTORY
# ============================================================

Path(OUTPUT_DIR).mkdir(
    parents=True,
    exist_ok=True
)


# ============================================================
# FIND IMAGE FILES
# ============================================================

image_extensions = {
    ".jpg",
    ".jpeg",
    ".png",
    ".bmp"
}

image_paths = []

for class_name in CLASS_NAMES:

    class_dir = Path(DATASET_DIR) / class_name

    if not class_dir.exists():
        print(f"WARNING: Missing directory: {class_dir}")
        continue

    for image_path in sorted(class_dir.rglob("*")):

        if image_path.suffix.lower() in image_extensions:
            image_paths.append(
                (str(image_path), class_name)
            )


print(f"\nTotal images found: {len(image_paths)}")


# ============================================================
# EXTRACT FEATURES
# ============================================================

rows = []

for index, (image_path, true_label) in enumerate(image_paths):

    try:

        # Load image as RGB
        image = tf.keras.utils.load_img(
            image_path,
            target_size=IMG_SIZE,
            color_mode="rgb"
        )

        # Convert image to NumPy array
        image_array = tf.keras.utils.img_to_array(image)

        # Keep raw 0-255 pixel values.
        # EfficientNetB0 performs its own preprocessing.

        # Add batch dimension
        image_array = np.expand_dims(
            image_array,
            axis=0
        )

        # Prediction
        probabilities = model.predict(
            image_array,
            verbose=0
        )[0]

        # Predicted emotion
        predicted_index = int(
            np.argmax(probabilities)
        )

        predicted_emotion = CLASS_NAMES[
            predicted_index
        ]

        confidence = float(
            probabilities[predicted_index]
        )

        # Store complete 7-dimensional probability vector
        row = {
            "image_path": image_path,
            "true_label": true_label,

            "angry_probability": float(probabilities[0]),
            "disgust_probability": float(probabilities[1]),
            "fear_probability": float(probabilities[2]),
            "happy_probability": float(probabilities[3]),
            "neutral_probability": float(probabilities[4]),
            "sad_probability": float(probabilities[5]),
            "surprise_probability": float(probabilities[6]),

            "predicted_emotion": predicted_emotion,
            "confidence": confidence
        }

        rows.append(row)

        # Progress
        if (index + 1) % 500 == 0:
            print(
                f"Processed {index + 1}/{len(image_paths)} images..."
            )

    except Exception as e:

        print(
            f"ERROR processing image: {image_path}"
        )

        print(f"Reason: {e}")


# ============================================================
# SAVE CSV
# ============================================================

fieldnames = [
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
    "confidence"
]


with open(
    OUTPUT_CSV,
    "w",
    newline="",
    encoding="utf-8"
) as csv_file:

    writer = csv.DictWriter(
        csv_file,
        fieldnames=fieldnames
    )

    writer.writeheader()
    writer.writerows(rows)


# ============================================================
# FINAL SUMMARY
# ============================================================

print("\n" + "=" * 70)
print("FEATURE EXTRACTION COMPLETED")
print("=" * 70)

print(f"Images processed : {len(rows)}")
print(f"Output CSV       : {OUTPUT_CSV}")

print("\nFeature columns:")

for emotion in CLASS_NAMES:
    print(f"  {emotion}_probability")

print("\nAdditional columns:")
print("  predicted_emotion")
print("  confidence")

print("\n" + "=" * 70)