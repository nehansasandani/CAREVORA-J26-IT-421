from pathlib import Path
import numpy as np
from collections import Counter


# ============================================================
# CONFIGURATION
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[2]

FEATURE_DIR = (
    PROJECT_ROOT
    / "data"
    / "voice_features"
)


# Expected dataset sizes
EXPECTED_SAMPLES = {
    "train": 5147,
    "validation": 1066,
    "test": 1229,
}

EXPECTED_ACTORS = {
    "train": 63,
    "validation": 13,
    "test": 15,
}

EXPECTED_TOTAL_ACTORS = 91

EXPECTED_FEATURE_SHAPE = {
    "train": (5147, 128, 174),
    "validation": (1066, 128, 174),
    "test": (1229, 128, 174),
}

# CREMA-D has 6 emotions
CLASS_NAMES = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
]

CLASS_IDS = {
    "angry": 0,
    "disgust": 1,
    "fear": 2,
    "happy": 3,
    "neutral": 4,
    "sad": 5,
}


# ============================================================
# LOAD DATA
# ============================================================

def load_split(split_name):

    feature_path = (
        FEATURE_DIR
        / f"{split_name}_logmel.npy"
    )

    label_path = (
        FEATURE_DIR
        / f"{split_name}_labels.npy"
    )

    actor_path = (
        FEATURE_DIR
        / f"{split_name}_actors.npy"
    )

    file_path = (
        FEATURE_DIR
        / f"{split_name}_files.npy"
    )

    X = np.load(
        feature_path
    )

    y = np.load(
        label_path
    )

    actors = np.load(
        actor_path,
        allow_pickle=True
    )

    files = np.load(
        file_path,
        allow_pickle=True
    )

    return X, y, actors, files


# ============================================================
# VALIDATE ONE SPLIT
# ============================================================

def validate_split(split_name):

    print("\n" + "=" * 70)
    print(
        f"VALIDATING {split_name.upper()}"
    )
    print("=" * 70)

    X, y, actors, files = load_split(
        split_name
    )

    passed = True

    # --------------------------------------------------------
    # Shape checks
    # --------------------------------------------------------

    print("\nShape checks:")

    print(
        f"Features : {X.shape}"
    )

    print(
        f"Labels   : {y.shape}"
    )

    print(
        f"Actors   : {actors.shape}"
    )

    print(
        f"Files    : {files.shape}"
    )

    expected_shape = (
        EXPECTED_FEATURE_SHAPE[
            split_name
        ]
    )

    if X.shape != expected_shape:

        print(
            f"FAILED: Expected feature shape "
            f"{expected_shape}"
        )

        passed = False

    else:

        print(
            "Feature shape: PASSED"
        )

    # --------------------------------------------------------
    # Sample count
    # --------------------------------------------------------

    expected_samples = (
        EXPECTED_SAMPLES[
            split_name
        ]
    )

    if len(y) != expected_samples:

        print(
            f"FAILED: Expected "
            f"{expected_samples} labels"
        )

        passed = False

    else:

        print(
            f"Sample count: PASSED "
            f"({len(y)})"
        )

    # --------------------------------------------------------
    # Feature / label / actor / file alignment
    # --------------------------------------------------------

    if not (
        len(X)
        == len(y)
        == len(actors)
        == len(files)
    ):

        print(
            "FAILED: Feature/label/actor/file "
            "count mismatch"
        )

        passed = False

    else:

        print(
            "Feature-label-file alignment: PASSED"
        )

    # --------------------------------------------------------
    # Label range
    # --------------------------------------------------------

    unique_labels = sorted(
        np.unique(y).tolist()
    )

    print(
        f"\nUnique labels: {unique_labels}"
    )

    if unique_labels != [0, 1, 2, 3, 4, 5]:

        print(
            "FAILED: Expected labels "
            "0, 1, 2, 3, 4, 5"
        )

        passed = False

    else:

        print(
            "Label range: PASSED"
        )

    # --------------------------------------------------------
    # Class distribution
    # --------------------------------------------------------

    print("\nClass distribution:")

    label_counts = Counter(
        y.tolist()
    )

    for emotion, class_id in CLASS_IDS.items():

        count = label_counts[
            class_id
        ]

        percentage = (
            count / len(y)
        ) * 100

        print(
            f"  {emotion:8s}: "
            f"{count:4d} "
            f"({percentage:6.2f}%)"
        )

    # --------------------------------------------------------
    # NaN / Inf checks
    # --------------------------------------------------------

    print("\nFeature value checks:")

    nan_count = np.isnan(
        X
    ).sum()

    inf_count = np.isinf(
        X
    ).sum()

    print(
        f"NaN values : {nan_count}"
    )

    print(
        f"Inf values : {inf_count}"
    )

    if nan_count != 0:

        print(
            "FAILED: NaN values found"
        )

        passed = False

    else:

        print(
            "NaN check: PASSED"
        )

    if inf_count != 0:

        print(
            "FAILED: Infinite values found"
        )

        passed = False

    else:

        print(
            "Inf check: PASSED"
        )

    # --------------------------------------------------------
    # Feature statistics
    # --------------------------------------------------------

    print("\nFeature statistics:")

    print(
        f"Minimum : {X.min():.4f}"
    )

    print(
        f"Maximum : {X.max():.4f}"
    )

    print(
        f"Mean    : {X.mean():.4f}"
    )

    print(
        f"Std     : {X.std():.4f}"
    )

    # --------------------------------------------------------
    # Actor count
    # --------------------------------------------------------

    unique_actors = np.unique(
        actors
    )

    expected_actor_count = (
        EXPECTED_ACTORS[
            split_name
        ]
    )

    print(
        f"\nUnique actors: "
        f"{len(unique_actors)}"
    )

    if (
        len(unique_actors)
        != expected_actor_count
    ):

        print(
            f"FAILED: Expected "
            f"{expected_actor_count} actors"
        )

        passed = False

    else:

        print(
            "Actor count: PASSED"
        )

    # --------------------------------------------------------
    # File uniqueness
    # --------------------------------------------------------

    unique_files = np.unique(
        files
    )

    print(
        f"Unique files: "
        f"{len(unique_files)}"
    )

    if len(unique_files) != len(files):

        print(
            "FAILED: Duplicate files found"
        )

        passed = False

    else:

        print(
            "File uniqueness: PASSED"
        )

    # --------------------------------------------------------
    # Final split result
    # --------------------------------------------------------

    print("\nSplit validation:")

    if passed:

        print(
            f"{split_name.upper()}: PASSED"
        )

    else:

        print(
            f"{split_name.upper()}: FAILED"
        )

    return {
        "X": X,
        "y": y,
        "actors": actors,
        "files": files,
        "passed": passed,
    }


# ============================================================
# ACTOR LEAKAGE CHECK
# ============================================================

def check_actor_leakage(results):

    print("\n" + "=" * 70)
    print("ACTOR LEAKAGE CHECK")
    print("=" * 70)

    train_actors = set(
        results["train"]["actors"]
    )

    val_actors = set(
        results["validation"]["actors"]
    )

    test_actors = set(
        results["test"]["actors"]
    )

    train_val = (
        train_actors
        & val_actors
    )

    train_test = (
        train_actors
        & test_actors
    )

    val_test = (
        val_actors
        & test_actors
    )

    print(
        f"\nTrain ∩ Validation: "
        f"{len(train_val)}"
    )

    print(
        f"Train ∩ Test      : "
        f"{len(train_test)}"
    )

    print(
        f"Validation ∩ Test : "
        f"{len(val_test)}"
    )

    if (
        len(train_val) == 0
        and len(train_test) == 0
        and len(val_test) == 0
    ):

        print(
            "\nActor leakage: PASSED"
        )

        return True

    else:

        print(
            "\nActor leakage: FAILED"
        )

        return False


# ============================================================
# CROSS-SPLIT FILE LEAKAGE CHECK
# ============================================================

def check_file_leakage(results):

    print("\n" + "=" * 70)
    print("FILE LEAKAGE CHECK")
    print("=" * 70)

    train_files = set(
        results["train"]["files"]
    )

    val_files = set(
        results["validation"]["files"]
    )

    test_files = set(
        results["test"]["files"]
    )

    train_val = (
        train_files
        & val_files
    )

    train_test = (
        train_files
        & test_files
    )

    val_test = (
        val_files
        & test_files
    )

    print(
        f"\nTrain ∩ Validation: "
        f"{len(train_val)}"
    )

    print(
        f"Train ∩ Test      : "
        f"{len(train_test)}"
    )

    print(
        f"Validation ∩ Test : "
        f"{len(val_test)}"
    )

    if (
        len(train_val) == 0
        and len(train_test) == 0
        and len(val_test) == 0
    ):

        print(
            "\nFile leakage: PASSED"
        )

        return True

    else:

        print(
            "\nFile leakage: FAILED"
        )

        return False


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 70)
    print(
        "CREMA-D VOICE FEATURE VALIDATION"
    )
    print("=" * 70)

    print(
        f"\nFeature directory:"
    )

    print(
        FEATURE_DIR
    )

    if not FEATURE_DIR.exists():

        raise FileNotFoundError(
            f"Feature directory not found: "
            f"{FEATURE_DIR}"
        )

    # --------------------------------------------------------
    # Validate all splits
    # --------------------------------------------------------

    results = {}

    for split_name in [
        "train",
        "validation",
        "test"
    ]:

        results[split_name] = (
            validate_split(
                split_name
            )
        )

    # --------------------------------------------------------
    # Actor leakage
    # --------------------------------------------------------

    actor_check = (
        check_actor_leakage(
            results
        )
    )

    # --------------------------------------------------------
    # File leakage
    # --------------------------------------------------------

    file_check = (
        check_file_leakage(
            results
        )
    )

    # --------------------------------------------------------
    # Total sample count
    # --------------------------------------------------------

    total_samples = sum(
        len(
            results[split]["y"]
        )
        for split in [
            "train",
            "validation",
            "test"
        ]
    )

    print("\n" + "=" * 70)
    print("OVERALL VALIDATION")
    print("=" * 70)

    print(
        f"\nTotal samples: "
        f"{total_samples}"
    )

    total_sample_check = (
        total_samples == 7442
    )

    print(
        "Total sample count:",
        "PASSED"
        if total_sample_check
        else "FAILED"
    )

    # --------------------------------------------------------
    # Total actor count
    # --------------------------------------------------------

    all_actors = set()

    for split_name in [
        "train",
        "validation",
        "test"
    ]:

        all_actors.update(
            results[split_name]["actors"]
        )

    total_actor_check = (
        len(all_actors)
        == EXPECTED_TOTAL_ACTORS
    )

    print(
        "Total actor count:",
        "PASSED"
        if total_actor_check
        else "FAILED"
    )

    # --------------------------------------------------------
    # Split checks
    # --------------------------------------------------------

    split_checks = all(
        results[split]["passed"]
        for split in [
            "train",
            "validation",
            "test"
        ]
    )

    # --------------------------------------------------------
    # FINAL RESULT
    # --------------------------------------------------------

    all_checks = (
        split_checks
        and actor_check
        and file_check
        and total_sample_check
        and total_actor_check
    )

    print("\n" + "=" * 70)

    if all_checks:

        print(
            "VOICE FEATURE VALIDATION: PASSED"
        )

        print(
            "\nAll feature, label, file, "
            "and speaker-independence checks passed."
        )

    else:

        print(
            "VOICE FEATURE VALIDATION: FAILED"
        )

        print(
            "\nPlease investigate the failed checks "
            "before training the model."
        )

    print("=" * 70)


# ============================================================
# RUN
# ============================================================

if __name__ == "__main__":
    main()