# Food detector training

This is a standalone model-training project with its own Compose stack, Dockerfile, Python dependencies, and local settings. It can run without the root project, PostgreSQL, or the data engineering containers. It owns the visual-model work: frame selection, annotation, training, evaluation, and the artifacts handed to the data engineering pipeline. The [main project](../README.md) owns ingestion, normalization, the PostgreSQL model, and analytical results.

The training configuration is a starting template. No annotated dataset, trained checkpoint, or measured detector results are included yet.

## Contents

```text
vision/
├── README.md
├── compose.yaml
├── .env.example
├── .dockerignore
├── .gitignore
├── Dockerfile
├── requirements.txt
└── configs/
    ├── dataset.yaml
    └── train.yaml
```

Put local datasets under `vision/data/`, training output under `vision/runs/`, and selected checkpoints under `vision/models/`. Those artifacts are ignored by Git and excluded from Docker builds. Keep dataset/split manifests and evaluation reports in version control when they become available.

## Local CPU environment

From the repository root, enter this project and set up its local settings:

```bash
cd vision
cp .env.example .env
# On Linux/WSL, set LOCAL_UID and LOCAL_GID to your `id -u` and `id -g` values.
docker compose up -d --build --wait
docker compose exec vision python -m pip check
docker compose exec vision bash
```

If `.env` already exists, edit it instead of copying over it. The shell opens at `/workspace/vision`. Only the vision folder is mounted, so annotations, configuration edits, and training output persist in this project. The image installs its own `requirements.txt` with YOLO and CPU PyTorch; it does not read the root requirements or database settings. The build context is this folder. The Compose project is named `tasty-screen-vision` to keep its containers and network separate from the data engineering stack.

All subsequent Docker commands in this guide run from `vision/` on your host, after exiting the container shell. No profile is needed. Both projects can run independently or at the same time.

To rebuild after editing versions in `requirements.txt`, check status, or stop this project:

```bash
docker compose up -d --build --wait
docker compose ps
docker compose down
```

Stopping this project leaves the root data engineering stack running. From the repository root you can instead select this stack explicitly with `docker compose --env-file vision/.env -f vision/compose.yaml up -d --build --wait`.

## Frame selection and annotation

1. Start with a target of approximately 1,500 annotated frames across movie genres, including about 15% negative frames without food. Treat this as an initial annotation budget; use evaluation results to decide whether more examples are needed.
2. Sample frames from clips where the text pipeline found food. Also retain a random control sample of clips to evaluate and run inference beyond clips that mention food.
3. Use a pretrained COCO detector to propose boxes, then correct them and add missing food classes in Label Studio. COCO labels do not match all project classes; inspect every proposal.
4. Have the three annotators label 50 shared frames. Review class disagreements and boxes with intersection over union below 0.5, then update the shared labeling guide before dividing the remaining frames.
5. Aim for 500 frames per team member. Check class counts and merge sparse classes only after updating the class mapping and documenting a new dataset version.

Use tight boxes around visible food or beverage instances. Apply the same policy for partially occluded objects, containers, and ambiguous dishes across annotators. Mark uncertain cases for review instead of guessing a class. The class IDs and 13 starting classes are defined in [configs/dataset.yaml](configs/dataset.yaml).

Export labels in [Ultralytics YOLO detection format](https://docs.ultralytics.com/datasets/detect/): one text file per image, with each object represented by `class_id x_center y_center width height`. Coordinates are normalized to the image width and height. Negative frames have no object labels.

Prepare this layout locally:

```text
vision/data/food/
├── images/
│   ├── train/
│   ├── val/
│   └── test/
└── labels/
    ├── train/
    ├── val/
    └── test/
```

Image and label files share their filename stem. Split roughly 70/15/15 into training, validation, and test sets **by clip**, so consecutive frames cannot leak across splits. Group by movie instead if the evaluation is intended to measure performance on unseen movies. Save the split manifest with clip IDs, movie IDs, frame timestamps, and dataset version.

## Training

Fine-tune the pretrained `yolo11n.pt` detector using [configs/train.yaml](configs/train.yaml). The initial epoch count and batch size are experiment settings, not measured optimal values. Follow the [Ultralytics training documentation](https://docs.ultralytics.com/modes/train/) for parameter details.

After the annotated dataset is ready, run from `vision/` on your host:

```bash
docker compose exec vision yolo detect train cfg=configs/train.yaml
```

The first run may download the pretrained weights. By default, the configuration uses CPU and writes output under `vision/runs/food-v1/`; repeated runs may receive numbered directories. Inspect the actual output path printed by YOLO. Do not assume a training duration before benchmarking the dataset and hardware.

For a smaller local trial, override the training parameters:

```bash
docker compose exec vision yolo detect train cfg=configs/train.yaml epochs=1 batch=2 name=food-smoke
```

### Google Colab / GPU training

Use a Colab GPU runtime for the full training experiment. Copy this folder, annotations, and split manifest into the runtime, and update `path` in `configs/dataset.yaml` to the dataset's absolute location there. Install `ultralytics==8.3.253` in that runtime using its GPU-compatible PyTorch installation; do not install the local CPU-only `torch` and `torchvision` pins from `vision/requirements.txt`.

From the copied `vision/` folder, run `yolo detect train cfg=configs/train.yaml device=0`. Adjust batch size to GPU memory. Record `pip freeze`, GPU type, seed, training arguments, and dataset version with the experiment. Copy checkpoints and reports out of Colab before the runtime expires. The local Docker image does not configure CUDA or GPU access.

## Evaluation and model selection

Use validation data to select model settings and the inference confidence threshold. Once those choices are fixed, evaluate on the held-out test set. Report mAP@0.5, mAP@0.5:0.95, per-class precision/recall, class support, and false positives on negative frames. Include errors involving beverages, containers, occlusion, and small food objects.

For the first run's checkpoint, evaluation commands from `vision/` on your host are:

```bash
docker compose exec vision yolo detect val model=runs/food-v1/weights/best.pt data=configs/dataset.yaml split=val device=cpu project=runs name=food-v1-val
docker compose exec vision yolo detect val model=runs/food-v1/weights/best.pt data=configs/dataset.yaml split=test device=cpu project=runs name=food-v1-test
```

Replace the checkpoint path if YOLO selected a numbered run directory. Record the validation-selected threshold separately from the confidence settings used to compute evaluation curves.

For each released model, preserve the checkpoint and its SHA-256 checksum, model name/version, class mapping, dataset/split version, configuration, environment, metrics, selected threshold, and a short error analysis. Store large checkpoints outside Git and record their artifact location. There is no trained-model release or evaluation report yet.

## Handoff to the data engineering pipeline

The proposed raw detection record contains `clip_link`, `frame_time_sec`, `original_label`, `confidence`, `bbox_xyxy`, `model_name`, `model_version`, and `batch_id`. Record bounding-box coordinates in pixels with the source image dimensions. Preserve the raw output so normalization can be repeated. Export scripts and this interface still need implementation.

The pipeline will map detector labels to canonical foods, register the model and threshold in `dim_detection_method`, merge repeated detections into scene-level appearances, and load `VISUAL` facts into `fact_food_reference`. It must compute `occurrence_count`, confidence aggregates, and `first_seen_sec` at the [documented fact grain](../docs/data_dictionary.md). A frame detection is not automatically a distinct food appearance; define and version the temporal merging rule before loading facts.

Training code, notebooks, annotation guides, and evaluation reports should be added here. Pipeline ingestion and warehouse loading belong in the main project.
