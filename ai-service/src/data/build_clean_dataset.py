"""
Carevora - Build a leakage-controlled FER-2013 dataset.

Rules:
1. Official test images that also occur in train are removed from TRAIN.
2. Conflicting-label duplicate groups inside TRAIN are removed.
3. Remaining exact duplicate groups inside TRAIN are reduced to one image.
4. Official TEST is preserved, but test images that occur in TRAIN are
   considered overlap and therefore are NOT used as the clean test set.
5. Original FER-2013 dataset is never modified.

Output:
    ai-service/data/raw/fer2013_clean/
"""

import hashlib
import json
import os
import shutil
from collections import defaultdict
from pathlib import Path

from PIL import Image
import numpy as np


CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise",
]

AI_DIR = Path(__file__).resolve().parents[2]

SOURCE_DIR = AI_DIR / "data" / "raw" / "fer2013"
OUTPUT_DIR = AI_DIR / "data" / "raw" / "fer2013_clean"


def image_hash(path):
    """
    Exact visual hash after the same normalization used by
    the previous duplicate-check script.
    """
    arr = np.asarray(
        Image.open(path).convert("L").resize((48, 48)),
        dtype=np.uint8,
    )

    return hashlib.md5(arr.tobytes()).hexdigest()


def collect_images(split):
    images = []

    for class_name in CLASS_NAMES:

        folder = SOURCE_DIR / split / class_name

        if not folder.exists():
            raise FileNotFoundError(
                f"Missing folder: {folder}"
            )

        for file in sorted(folder.iterdir()):

            if file.suffix.lower() in {".jpg", ".jpeg", ".png"}:

                images.append(
                    {
                        "path": file,
                        "label": class_name,
                        "hash": image_hash(file),
                    }
                )

    return images


def copy_image(src, destination_folder):

    destination_folder.mkdir(
        parents=True,
        exist_ok=True
    )

    destination = destination_folder / src.name

    # Avoid accidental filename collisions.
    if destination.exists():

        stem = src.stem
        suffix = src.suffix

        counter = 1

        while True:

            destination = (
                destination_folder
                / f"{stem}_copy{counter}{suffix}"
            )

            if not destination.exists():
                break

            counter += 1

    shutil.copy2(src, destination)


def main():

    print("=" * 75)
    print("CAREVORA - CLEAN FER-2013 DATASET BUILDER")
    print("=" * 75)

    if not SOURCE_DIR.exists():

        raise FileNotFoundError(
            f"Source dataset not found:\n{SOURCE_DIR}"
        )

    # ---------------------------------------------------------
    # 1. Read original dataset
    # ---------------------------------------------------------

    print("\n[1/6] Reading original dataset...")

    train = collect_images("train")
    test = collect_images("test")

    print(f"Original train images : {len(train)}")
    print(f"Original test images  : {len(test)}")

    # ---------------------------------------------------------
    # 2. Build train hash groups
    # ---------------------------------------------------------

    print("\n[2/6] Building image hash groups...")

    train_groups = defaultdict(list)

    for item in train:
        train_groups[item["hash"]].append(item)

    test_groups = defaultdict(list)

    for item in test:
        test_groups[item["hash"]].append(item)

    # ---------------------------------------------------------
    # 3. Identify test/train overlap
    # ---------------------------------------------------------

    test_hashes = set(test_groups.keys())

    train_test_overlap = [
        item
        for item in train
        if item["hash"] in test_hashes
    ]

    overlap_hashes = {
        item["hash"]
        for item in train_test_overlap
    }

    print(
        f"Train images overlapping with test : "
        f"{len(train_test_overlap)}"
    )

    # ---------------------------------------------------------
    # 4. Identify conflicting train duplicate groups
    # ---------------------------------------------------------

    conflicting_groups = []

    for h, group in train_groups.items():

        labels = {
            item["label"]
            for item in group
        }

        if len(labels) > 1:

            conflicting_groups.append(
                {
                    "hash": h,
                    "items": group,
                }
            )

    conflicting_hashes = {
        group["hash"]
        for group in conflicting_groups
    }

    conflicting_images = sum(
        len(group["items"])
        for group in conflicting_groups
    )

    print(
        "Conflicting duplicate groups : "
        f"{len(conflicting_groups)}"
    )

    print(
        "Images in conflicting groups : "
        f"{conflicting_images}"
    )

    # ---------------------------------------------------------
    # 5. Build clean TRAIN
    # ---------------------------------------------------------

    print("\n[3/6] Building clean training set...")

    clean_train = []

    removed_overlap = 0
    removed_conflicts = 0
    removed_duplicates = 0

    for h, group in train_groups.items():

        # A. Remove train/test overlap
        if h in overlap_hashes:

            removed_overlap += len(group)
            continue

        # B. Remove conflicting-label groups
        if h in conflicting_hashes:

            removed_conflicts += len(group)
            continue

        # C. Keep exactly one image from duplicate group
        clean_train.append(group[0])

        if len(group) > 1:

            removed_duplicates += len(group) - 1

    print(
        f"Removed train/test overlap images : "
        f"{removed_overlap}"
    )

    print(
        f"Removed conflicting-label images  : "
        f"{removed_conflicts}"
    )

    print(
        f"Removed extra duplicate images    : "
        f"{removed_duplicates}"
    )

    # ---------------------------------------------------------
    # 6. Build clean TEST
    # ---------------------------------------------------------

    print("\n[4/6] Building clean test set...")

    clean_test = []

    removed_test_overlap = 0

    for item in test:

        if item["hash"] in overlap_hashes:

            removed_test_overlap += 1

        else:

            clean_test.append(item)

    print(
        f"Removed test images overlapping train : "
        f"{removed_test_overlap}"
    )

    print(
        f"Final clean test images               : "
        f"{len(clean_test)}"
    )

    # ---------------------------------------------------------
    # Recreate output folder
    # ---------------------------------------------------------

    print("\n[5/6] Creating clean dataset folder...")

    if OUTPUT_DIR.exists():

        print(
            f"Removing previous clean dataset:\n"
            f"{OUTPUT_DIR}"
        )

        shutil.rmtree(OUTPUT_DIR)

    # ---------------------------------------------------------
    # Copy clean train
    # ---------------------------------------------------------

    for item in clean_train:

        copy_image(
            item["path"],
            OUTPUT_DIR / "train" / item["label"]
        )

    # ---------------------------------------------------------
    # Copy clean test
    # ---------------------------------------------------------

    for item in clean_test:

        copy_image(
            item["path"],
            OUTPUT_DIR / "test" / item["label"]
        )

    # ---------------------------------------------------------
    # Count classes
    # ---------------------------------------------------------

    train_counts = {
        class_name: 0
        for class_name in CLASS_NAMES
    }

    test_counts = {
        class_name: 0
        for class_name in CLASS_NAMES
    }

    for item in clean_train:
        train_counts[item["label"]] += 1

    for item in clean_test:
        test_counts[item["label"]] += 1

    # ---------------------------------------------------------
    # Summary
    # ---------------------------------------------------------

    summary = {

        "source_dataset": str(SOURCE_DIR),

        "output_dataset": str(OUTPUT_DIR),

        "original_train_images": len(train),

        "original_test_images": len(test),

        "train_test_overlap_images_removed_from_train":
            removed_overlap,

        "conflicting_duplicate_groups":
            len(conflicting_groups),

        "conflicting_duplicate_images_removed":
            removed_conflicts,

        "extra_duplicate_train_images_removed":
            removed_duplicates,

        "test_overlap_images_removed":
            removed_test_overlap,

        "final_clean_train_images":
            len(clean_train),

        "final_clean_test_images":
            len(clean_test),

        "train_class_counts":
            train_counts,

        "test_class_counts":
            test_counts,
    }

    summary_path = (
        AI_DIR
        / "data"
        / "processed"
        / "clean_dataset_summary.json"
    )

    summary_path.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    with open(
        summary_path,
        "w",
        encoding="utf-8"
    ) as f:

        json.dump(
            summary,
            f,
            indent=4
        )

    # ---------------------------------------------------------
    # Final output
    # ---------------------------------------------------------

    print("\n[6/6] CLEAN DATASET CREATED")
    print("=" * 75)

    print(
        f"Clean train : {len(clean_train)}"
    )

    print(
        f"Clean test  : {len(clean_test)}"
    )

    print("\nTrain class distribution:")

    for c in CLASS_NAMES:
        print(
            f"  {c:10s}: {train_counts[c]}"
        )

    print("\nTest class distribution:")

    for c in CLASS_NAMES:
        print(
            f"  {c:10s}: {test_counts[c]}"
        )

    print(
        f"\nDataset saved to:\n{OUTPUT_DIR}"
    )

    print(
        f"\nSummary saved to:\n{summary_path}"
    )

    print("=" * 75)


if __name__ == "__main__":
    main()