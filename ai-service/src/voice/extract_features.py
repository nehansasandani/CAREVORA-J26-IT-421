from pathlib import Path
import numpy as np
import pandas as pd
import librosa
import json


# ============================================================
# CONFIGURATION
# ============================================================

PROJECT_ROOT = Path(__file__).resolve().parents[2]

CREMA_ROOT = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "CREMA-D"
)

AUDIO_DIR = CREMA_ROOT / "AudioWAV"

SPLIT_DIR = (
    PROJECT_ROOT
    / "data"
    / "cremad_splits"
)

OUTPUT_DIR = (
    PROJECT_ROOT
    / "data"
    / "voice_features"
)

OUTPUT_DIR.mkdir(
    parents=True,
    exist_ok=True
)


# Audio configuration
SAMPLE_RATE = 16000

N_MELS = 128
N_FFT = 2048
HOP_LENGTH = 512

# Fixed time dimension
MAX_PAD_LEN = 174


# ============================================================
# EMOTION LABEL MAPPING
# ============================================================

EMOTION_TO_ID = {
    "angry": 0,
    "disgust": 1,
    "fear": 2,
    "happy": 3,
    "neutral": 4,
    "sad": 5,
}

ID_TO_EMOTION = {
    value: key
    for key, value in EMOTION_TO_ID.items()
}


# ============================================================
# LOAD CSV
# ============================================================

def load_split(split_name):

    csv_path = (
        SPLIT_DIR
        / f"{split_name}.csv"
    )

    if not csv_path.exists():
        raise FileNotFoundError(
            f"Split file not found: {csv_path}"
        )

    df = pd.read_csv(csv_path)

    print(
        f"{split_name.capitalize()} records: "
        f"{len(df)}"
    )

    return df


# ============================================================
# AUDIO → LOG-MEL SPECTROGRAM
# ============================================================

def extract_logmel(audio_path):

    try:

        # Load audio
        audio, _ = librosa.load(
            audio_path,
            sr=SAMPLE_RATE,
            mono=True
        )

        # Log-Mel spectrogram
        mel = librosa.feature.melspectrogram(
            y=audio,
            sr=SAMPLE_RATE,
            n_fft=N_FFT,
            hop_length=HOP_LENGTH,
            n_mels=N_MELS
        )

        # Convert power spectrogram to dB
        logmel = librosa.power_to_db(
            mel,
            ref=np.max
        )

        # ----------------------------------------------------
        # FIXED LENGTH
        # ----------------------------------------------------

        if logmel.shape[1] < MAX_PAD_LEN:

            pad_width = (
                MAX_PAD_LEN
                - logmel.shape[1]
            )

            logmel = np.pad(
                logmel,
                (
                    (0, 0),
                    (0, pad_width)
                ),
                mode="constant",
                constant_values=logmel.min()
            )

        else:

            logmel = logmel[
                :,
                :MAX_PAD_LEN
            ]

        return logmel.astype(
            np.float32
        )

    except Exception as e:

        print(
            f"ERROR processing "
            f"{audio_path.name}: {e}"
        )

        return None


# ============================================================
# PROCESS ONE SPLIT
# ============================================================

def process_split(split_name):

    print("\n" + "=" * 70)
    print(
        f"PROCESSING {split_name.upper()}"
    )
    print("=" * 70)

    df = load_split(
        split_name
    )

    features = []
    labels = []
    actor_ids = []
    file_names = []

    failed_files = []

    total = len(df)

    for index, row in df.iterrows():

        file_name = row[
            "file_name"
        ]

        audio_path = (
            AUDIO_DIR
            / file_name
        )

        if not audio_path.exists():

            print(
                f"Missing file: "
                f"{audio_path}"
            )

            failed_files.append(
                file_name
            )

            continue

        feature = extract_logmel(
            audio_path
        )

        if feature is None:

            failed_files.append(
                file_name
            )

            continue

        emotion = row[
            "emotion"
        ]

        if emotion not in EMOTION_TO_ID:

            raise ValueError(
                f"Unknown emotion: "
                f"{emotion}"
            )

        features.append(
            feature
        )

        labels.append(
            EMOTION_TO_ID[emotion]
        )

        actor_ids.append(
            row["actor_id"]
        )

        file_names.append(
            file_name
        )

        # Progress
        if (
            (index + 1) % 500 == 0
            or index + 1 == total
        ):

            print(
                f"Processed "
                f"{index + 1}/{total}"
            )

    # --------------------------------------------------------
    # Convert to NumPy arrays
    # --------------------------------------------------------

    X = np.stack(
        features
    )

    y = np.array(
        labels,
        dtype=np.int64
    )

    actor_ids = np.array(
        actor_ids
    )

    file_names = np.array(
        file_names
    )

    # --------------------------------------------------------
    # Save
    # --------------------------------------------------------

    feature_path = (
        OUTPUT_DIR
        / f"{split_name}_logmel.npy"
    )

    label_path = (
        OUTPUT_DIR
        / f"{split_name}_labels.npy"
    )

    actor_path = (
        OUTPUT_DIR
        / f"{split_name}_actors.npy"
    )

    files_path = (
        OUTPUT_DIR
        / f"{split_name}_files.npy"
    )

    np.save(
        feature_path,
        X
    )

    np.save(
        label_path,
        y
    )

    np.save(
        actor_path,
        actor_ids
    )

    np.save(
        files_path,
        file_names
    )

    # --------------------------------------------------------
    # Summary
    # --------------------------------------------------------

    print(
        f"\n{split_name.capitalize()} completed."
    )

    print(
        f"Features shape : {X.shape}"
    )

    print(
        f"Labels shape   : {y.shape}"
    )

    print(
        f"Actors shape   : {actor_ids.shape}"
    )

    print(
        f"Failed files   : {len(failed_files)}"
    )

    print(
        f"Saved          : {feature_path}"
    )

    return {
        "split": split_name,
        "samples": len(X),
        "feature_shape": list(X.shape),
        "failed_files": len(
            failed_files
        ),
    }


# ============================================================
# MAIN
# ============================================================

def main():

    print("=" * 70)
    print(
        "CREMA-D LOG-MEL FEATURE EXTRACTION"
    )
    print("=" * 70)

    print(
        f"\nProject root : {PROJECT_ROOT}"
    )

    print(
        f"Audio folder : {AUDIO_DIR}"
    )

    print(
        f"Split folder : {SPLIT_DIR}"
    )

    print(
        f"Output folder: {OUTPUT_DIR}"
    )

    print(
        f"\nSample rate  : {SAMPLE_RATE}"
    )

    print(
        f"N-Mels       : {N_MELS}"
    )

    print(
        f"N-FFT        : {N_FFT}"
    )

    print(
        f"Hop length   : {HOP_LENGTH}"
    )

    print(
        f"Max time     : {MAX_PAD_LEN}"
    )

    # --------------------------------------------------------
    # Check directories
    # --------------------------------------------------------

    if not AUDIO_DIR.exists():

        raise FileNotFoundError(
            f"Audio directory not found: "
            f"{AUDIO_DIR}"
        )

    if not SPLIT_DIR.exists():

        raise FileNotFoundError(
            f"Split directory not found: "
            f"{SPLIT_DIR}"
        )

    # --------------------------------------------------------
    # Process all splits
    # --------------------------------------------------------

    summaries = []

    for split_name in [
        "train",
        "validation",
        "test"
    ]:

        summary = process_split(
            split_name
        )

        summaries.append(
            summary
        )

    # --------------------------------------------------------
    # Save metadata
    # --------------------------------------------------------

    metadata = {

        "dataset": "CREMA-D",

        "feature_type": "Log-Mel Spectrogram",

        "sample_rate": SAMPLE_RATE,

        "n_mels": N_MELS,

        "n_fft": N_FFT,

        "hop_length": HOP_LENGTH,

        "max_pad_len": MAX_PAD_LEN,

        "num_classes": 6,

        "class_names": list(
            EMOTION_TO_ID.keys()
        ),

        "splits": summaries,

    }

    metadata_path = (
        OUTPUT_DIR
        / "feature_metadata.json"
    )

    with open(
        metadata_path,
        "w",
        encoding="utf-8"
    ) as file:

        json.dump(
            metadata,
            file,
            indent=4
        )

    # --------------------------------------------------------
    # Final message
    # --------------------------------------------------------

    print("\n" + "=" * 70)
    print(
        "FEATURE EXTRACTION COMPLETED"
    )
    print("=" * 70)

    print(
        f"\nOutput directory:"
    )

    print(
        OUTPUT_DIR
    )

    print(
        f"\nMetadata:"
    )

    print(
        metadata_path
    )


if __name__ == "__main__":
    main()