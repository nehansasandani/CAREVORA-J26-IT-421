import os
import matplotlib.pyplot as plt

DATASET_PATH = "ai-service/data/raw/fer2013"
RESULTS_PATH = "ai-service/results/facial_emotion"

classes = [
    "angry",
    "disgust",
    "fear",
    "happy",
    "neutral",
    "sad",
    "surprise"
]


def count_images(folder_path):
    return sum(
        1
        for file in os.listdir(folder_path)
        if file.lower().endswith((".jpg", ".jpeg", ".png"))
    )


train_counts = []
test_counts = []

for emotion in classes:

    train_path = os.path.join(
        DATASET_PATH, "train", emotion
    )

    test_path = os.path.join(
        DATASET_PATH, "test", emotion
    )

    train_counts.append(count_images(train_path))
    test_counts.append(count_images(test_path))


print("\nFER-2013 DATASET STATISTICS")
print("=" * 50)

for i, emotion in enumerate(classes):
    print(
        f"{emotion:10s} | "
        f"Train: {train_counts[i]:5d} | "
        f"Test: {test_counts[i]:5d}"
    )

print("=" * 50)
print(f"Total Train: {sum(train_counts)}")
print(f"Total Test : {sum(test_counts)}")


os.makedirs(RESULTS_PATH, exist_ok=True)


# -------------------------------
# Training distribution
# -------------------------------

plt.figure(figsize=(10, 6))

plt.bar(classes, train_counts)

plt.title("FER-2013 Training Class Distribution")
plt.xlabel("Emotion")
plt.ylabel("Number of Images")

plt.tight_layout()

plt.savefig(
    os.path.join(
        RESULTS_PATH,
        "train_class_distribution.png"
    ),
    dpi=300
)

plt.close()


# -------------------------------
# Test distribution
# -------------------------------

plt.figure(figsize=(10, 6))

plt.bar(classes, test_counts)

plt.title("FER-2013 Test Class Distribution")
plt.xlabel("Emotion")
plt.ylabel("Number of Images")

plt.tight_layout()

plt.savefig(
    os.path.join(
        RESULTS_PATH,
        "test_class_distribution.png"
    ),
    dpi=300
)

plt.close()


print("\nDistribution plots saved successfully.")