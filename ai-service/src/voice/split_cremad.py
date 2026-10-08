from pathlib import Path
import random
import csv
from collections import Counter


# ============================================================
# CONFIGURATION
# ============================================================

DATASET_DIR = Path(
    "ai-service/data/raw/CREMA-D/AudioWAV"
)

OUTPUT_DIR = Path(
    "ai-service/data/cremad_splits"
)

TRAIN_ACTORS = 63
VAL_ACTORS = 13
TEST_ACTORS = 15

SEED = 42

EMOTION_MAP = {
    "ANG": "angry",
    "DIS": "disgust",
    "FEA": "fear",
    "HAP": "happy",
    "NEU": "neutral",
    "SAD": "sad",
}


# ============================================================
# CREATE OUTPUT DIRECTORY
# ============================================================

OUTPUT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


# ============================================================
# FIND WAV FILES
# ============================================================

wav_files = sorted(
    DATASET_DIR.glob("*.wav")
)

print("=" * 70)
print("CREMA-D SPEAKER-INDEPENDENT SPLIT")
print("=" * 70)

print(f"\nTotal WAV files found: {len(wav_files)}")


# ============================================================
# EXTRACT ACTOR IDS
# ============================================================

actor_ids = sorted(
    set(
        file.name.split("_")[0]
        for file in wav_files
    )
)

print(f"Unique actors found: {len(actor_ids)}")


# ============================================================
# VALIDATE ACTOR COUNT
# ============================================================

expected_total = (
    TRAIN_ACTORS
    + VAL_ACTORS
    + TEST_ACTORS
)

if len(actor_ids) != expected_total:
    raise ValueError(
        f"Expected {expected_total} actors, "
        f"but found {len(actor_ids)}."
    )


# ============================================================
# RANDOM BUT REPRODUCIBLE ACTOR SPLIT
# ============================================================

random.seed(SEED)

shuffled_actors = actor_ids.copy()

random.shuffle(
    shuffled_actors
)


train_actors = sorted(
    shuffled_actors[:TRAIN_ACTORS]
)

val_actors = sorted(
    shuffled_actors[
        TRAIN_ACTORS:
        TRAIN_ACTORS + VAL_ACTORS
    ]
)

test_actors = sorted(
    shuffled_actors[
        TRAIN_ACTORS + VAL_ACTORS:
    ]
)


# ============================================================
# PRINT ACTOR SPLIT
# ============================================================

print("\nActor split:")
print(
    f"Train      : {len(train_actors)} actors"
)

print(
    f"Validation : {len(val_actors)} actors"
)

print(
    f"Test       : {len(test_actors)} actors"
)


# ============================================================
# VERIFY ACTOR INDEPENDENCE
# ============================================================

train_set = set(train_actors)
val_set = set(val_actors)
test_set = set(test_actors)

if train_set & val_set:
    raise RuntimeError(
        "ERROR: Train/Validation actor overlap detected!"
    )

if train_set & test_set:
    raise RuntimeError(
        "ERROR: Train/Test actor overlap detected!"
    )

if val_set & test_set:
    raise RuntimeError(
        "ERROR: Validation/Test actor overlap detected!"
    )

print(
    "\nActor independence check: PASSED"
)


# ============================================================
# CREATE ACTOR → SPLIT LOOKUP
# ============================================================

actor_to_split = {}

for actor in train_actors:
    actor_to_split[actor] = "train"

for actor in val_actors:
    actor_to_split[actor] = "validation"

for actor in test_actors:
    actor_to_split[actor] = "test"


# ============================================================
# ASSIGN EACH AUDIO FILE
# ============================================================

rows = []

for wav_file in wav_files:

    parts = wav_file.stem.split("_")

    if len(parts) != 4:
        raise ValueError(
            f"Unexpected filename format: "
            f"{wav_file.name}"
        )

    actor_id = parts[0]
    sentence = parts[1]
    emotion_code = parts[2]
    intensity = parts[3]

    if actor_id not in actor_to_split:
        raise ValueError(
            f"Actor {actor_id} has no split assignment."
        )

    if emotion_code not in EMOTION_MAP:
        raise ValueError(
            f"Unknown emotion code: {emotion_code}"
        )

    split = actor_to_split[
        actor_id
    ]

    rows.append({
        "file_name": wav_file.name,
        "file_path": str(wav_file),
        "actor_id": actor_id,
        "sentence": sentence,
        "emotion_code": emotion_code,
        "emotion": EMOTION_MAP[emotion_code],
        "intensity": intensity,
        "split": split,
    })


# ============================================================
# SAVE COMPLETE METADATA
# ============================================================

metadata_path = (
    OUTPUT_DIR / "cremad_metadata.csv"
)

fieldnames = [
    "file_name",
    "file_path",
    "actor_id",
    "sentence",
    "emotion_code",
    "emotion",
    "intensity",
    "split",
]

with open(
    metadata_path,
    "w",
    newline="",
    encoding="utf-8"
) as file:

    writer = csv.DictWriter(
        file,
        fieldnames=fieldnames
    )

    writer.writeheader()
    writer.writerows(rows)


# ============================================================
# SAVE INDIVIDUAL SPLIT CSV FILES
# ============================================================

for split_name in [
    "train",
    "validation",
    "test"
]:

    split_rows = [
        row
        for row in rows
        if row["split"] == split_name
    ]

    output_path = (
        OUTPUT_DIR
        / f"{split_name}.csv"
    )

    with open(
        output_path,
        "w",
        newline="",
        encoding="utf-8"
    ) as file:

        writer = csv.DictWriter(
            file,
            fieldnames=fieldnames
        )

        writer.writeheader()
        writer.writerows(split_rows)


# ============================================================
# STATISTICS
# ============================================================

print("\n" + "=" * 70)
print("DATASET SPLIT SUMMARY")
print("=" * 70)


for split_name in [
    "train",
    "validation",
    "test"
]:

    split_rows = [
        row
        for row in rows
        if row["split"] == split_name
    ]

    actors = sorted(
        set(
            row["actor_id"]
            for row in split_rows
        )
    )

    emotions = Counter(
        row["emotion"]
        for row in split_rows
    )

    print(
        f"\n{split_name.upper()}"
    )

    print(
        f"Actors : {len(actors)}"
    )

    print(
        f"Files  : {len(split_rows)}"
    )

    print(
        "Emotion distribution:"
    )

    for emotion in EMOTION_MAP.values():
        print(
            f"  {emotion:8s}: "
            f"{emotions[emotion]}"
        )


# ============================================================
# FINAL VALIDATION
# ============================================================

print("\n" + "=" * 70)
print("FINAL VALIDATION")
print("=" * 70)


total_split_files = sum(
    1
    for row in rows
    if row["split"] in {
        "train",
        "validation",
        "test"
    }
)

if total_split_files != len(wav_files):
    raise RuntimeError(
        "Split file count does not match "
        "total WAV file count!"
    )


# Verify every actor belongs to exactly one split

all_split_actors = (
    train_set
    | val_set
    | test_set
)

if len(all_split_actors) != 91:
    raise RuntimeError(
        "Not all 91 actors were assigned."
    )


# Verify no actor overlap again

assert train_set.isdisjoint(val_set)
assert train_set.isdisjoint(test_set)
assert val_set.isdisjoint(test_set)


print(
    "Total WAV files      :", len(wav_files)
)

print(
    "Total split records  :", total_split_files
)

print(
    "Total actors         :", len(all_split_actors)
)

print(
    "Train actors         :", len(train_set)
)

print(
    "Validation actors    :", len(val_set)
)

print(
    "Test actors          :", len(test_set)
)

print(
    "\nSpeaker-independent split: PASSED"
)

print(
    "\nSaved files:"
)

print(
    f"  {OUTPUT_DIR / 'cremad_metadata.csv'}"
)

print(
    f"  {OUTPUT_DIR / 'train.csv'}"
)

print(
    f"  {OUTPUT_DIR / 'validation.csv'}"
)

print(
    f"  {OUTPUT_DIR / 'test.csv'}"
)

print("\n" + "=" * 70)
print("SPLIT COMPLETED SUCCESSFULLY")
print("=" * 70)