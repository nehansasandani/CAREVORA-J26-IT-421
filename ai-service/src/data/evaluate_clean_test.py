"""
Carevora - Honest test evaluation (removes train/test overlap)

FER-2013 has test images that also exist in the train folder. This script
evaluates the saved EfficientNetB0 model on:
  1. the full official test set
  2. the CLEAN subset  (test images NOT found in train)  <- number to report
  3. the OVERLAP subset (test images found in train)     <- shows memorisation

Run:
    python ai-service/src/data/evaluate_clean_test.py
"""

import hashlib
import os
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image
from sklearn.metrics import accuracy_score, classification_report, f1_score

CLASS_NAMES = ["angry", "disgust", "fear", "happy", "neutral", "sad", "surprise"]
IMG_SIZE = 96
BATCH_SIZE = 64

AI_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = AI_DIR / "data" / "raw" / "fer2013"
MODEL_PATH = AI_DIR / "src" / "models" / "transfer_emotion.keras"


def image_hash(path):
    arr = np.asarray(Image.open(path).convert("L").resize((48, 48)), dtype=np.uint8)
    return hashlib.md5(arr.tobytes()).hexdigest()


def list_images(split):
    paths, labels = [], []
    for idx, name in enumerate(CLASS_NAMES):
        folder = DATA_DIR / split / name
        for f in sorted(os.listdir(folder)):
            if f.lower().endswith((".jpg", ".jpeg", ".png")):
                paths.append(str(folder / f))
                labels.append(idx)
    return paths, np.array(labels)


def load_image(path):
    img = tf.io.read_file(path)
    img = tf.image.decode_image(img, channels=3, expand_animations=False)
    img = tf.image.resize(img, (IMG_SIZE, IMG_SIZE))
    img = tf.cast(img, tf.float32)  # raw 0..255
    img.set_shape([IMG_SIZE, IMG_SIZE, 3])
    return img


def predict(model, paths):
    ds = (tf.data.Dataset.from_tensor_slices(paths)
          .map(load_image, num_parallel_calls=tf.data.AUTOTUNE)
          .batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE))
    return model.predict(ds, verbose=1)


def report(title, y_true, y_pred):
    if len(y_true) == 0:
        print(f"\n{title}: no images")
        return
    acc = accuracy_score(y_true, y_pred) * 100
    f1 = f1_score(y_true, y_pred, average="macro", zero_division=0)
    print(f"\n{title}\n  images: {len(y_true)} | accuracy: {acc:.2f}% | macro F1: {f1:.4f}")


def main():
    train_paths, train_labels = list_images("train")
    test_paths, test_labels = list_images("test")

    print("Hashing train images ...")
    train_hash_labels = {}
    for p, l in zip(train_paths, train_labels):
        train_hash_labels.setdefault(image_hash(p), set()).add(int(l))

    print("Hashing test images ...")
    overlap = np.array([image_hash(p) in train_hash_labels for p in test_paths])

    model = tf.keras.models.load_model(str(MODEL_PATH))
    pred = predict(model, test_paths).argmax(1)

    print("\n" + "=" * 70)
    print("HONEST TEST EVALUATION")
    print("=" * 70)
    report("FULL test set", test_labels, pred)
    report("CLEAN test set (not in train)  <-- report this", test_labels[~overlap], pred[~overlap])
    report("OVERLAP subset (also in train)", test_labels[overlap], pred[overlap])

    print("\nClassification report - CLEAN subset")
    print(classification_report(
        test_labels[~overlap], pred[~overlap], labels=range(7),
        target_names=CLASS_NAMES, digits=4, zero_division=0))


if __name__ == "__main__":
    main()
