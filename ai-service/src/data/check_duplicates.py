import hashlib
import os
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image

AI_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = AI_DIR / "data" / "raw" / "fer2013"


def image_hash(path):
    arr = np.asarray(
        Image.open(path).convert("L").resize((48, 48)),
        dtype=np.uint8
    )
    return hashlib.md5(arr.tobytes()).hexdigest()


def scan(split):
    groups = defaultdict(list)

    for root, _, files in os.walk(DATA_DIR / split):
        for f in files:
            if f.lower().endswith((".jpg", ".jpeg", ".png")):
                p = os.path.join(root, f)
                groups[image_hash(p)].append(p)

    return groups


def main():

    print("=" * 70)
    print("FER-2013 DUPLICATE / LEAKAGE CHECK")
    print("=" * 70)

    train = scan("train")
    test = scan("test")

    n_train = sum(len(v) for v in train.values())
    n_test = sum(len(v) for v in test.values())

    dup_groups = [
        v for v in train.values()
        if len(v) > 1
    ]

    dup_images = sum(
        len(v) - 1
        for v in dup_groups
    )

    cross = [
        h for h in train
        if h in test
    ]

    cross_images = sum(
        len(test[h])
        for h in cross
    )

    conflicts = [
        v for v in dup_groups
        if len({
            Path(p).parent.name
            for p in v
        }) > 1
    ]

    print(f"\nTrain images : {n_train}")
    print(f"Test images  : {n_test}")

    print("\nDuplicate groups inside TRAIN:")
    print(f"  Groups       : {len(dup_groups)}")
    print(f"  Extra images : {dup_images}")

    print("\nDuplicate groups with conflicting labels:")
    print(f"  Groups : {len(conflicts)}")

    print("\nTRAIN ↔ TEST overlap:")
    print(f"  Test images also found in train : {cross_images}")

    print("\n" + "=" * 70)
    print("CHECK COMPLETED")
    print("=" * 70)


if __name__ == "__main__":
    main()