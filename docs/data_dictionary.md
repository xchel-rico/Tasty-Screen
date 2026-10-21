# Data dictionary

Star schema of the gold layer (PostgreSQL). DDL: [`sql/01_ddl_star_schema.sql`](../sql/01_ddl_star_schema.sql).

![Star schema](star_schema.png)

## fact_food_reference

**Grain:** one row per canonical food × scene × evidence type × detection-method version.

| Column | Type | Description |
|---|---|---|
| `food_reference_key` | BIGINT, PK | Surrogate key |
| `movie_key` | INT, FK → dim_movie | Movie |
| `scene_key` | INT, FK → dim_scene | Scene (CinePile clip) |
| `food_key` | INT, FK → dim_food | Canonical food |
| `method_key` | INT, FK → dim_detection_method | Detection method and version |
| `reference_type` | VARCHAR(10) | `MENTION` (subtitles), `DESCRIBED` (scene description), `VISUAL` (detector) |
| `original_label` | VARCHAR(100) | Raw phrase or detector class before normalisation |
| `occurrence_count` | INT | Mentions, or merged visual appearances, in the scene |
| `avg_confidence` | DECIMAL(4,3) | Mean confidence (1.0 for exact text matches) |
| `max_confidence` | DECIMAL(4,3) | Highest confidence in the scene |
| `first_seen_sec` | INT, nullable | Second of the clip where the food first appears (visual only) |
| `batch_id` | VARCHAR(40) | Processing batch, for lineage |

## dim_movie — SCD Type 1

| Column | Type | Description |
|---|---|---|
| `movie_key` | INT, PK | Surrogate key |
| `source_movie_name` | VARCHAR(255) | `movie_name` as in CinePile |
| `movie_title` | VARCHAR(255) | Cleaned title |
| `release_year` | SMALLINT | Release year |
| `decade` | VARCHAR(5) | Derived, e.g. `1990s` |
| `genre` | VARCHAR(50) | Primary genre |

Corrections overwrite the old value; the analysis needs the best-known metadata, not its history. There is no separate date dimension because the source only provides a year.

## dim_scene — static

| Column | Type | Description |
|---|---|---|
| `scene_key` | INT, PK | Surrogate key |
| `clip_link` | VARCHAR(255) | `yt_clip_link`, natural key of the clip |
| `clip_title` | VARCHAR(255) | `yt_clip_title` |
| `movie_key` | INT | Movie the clip belongs to |
| `scene_description` | TEXT, nullable | `movie_scene` text |
| `subtitle_text` | TEXT, nullable | Clip subtitles |
| `n_frames_sampled` | INT, nullable | Frames extracted (NULL if not processed visually) |

A published clip never changes; new clips are inserted as new rows.

## dim_food — SCD Type 1

| Column | Type | Description |
|---|---|---|
| `food_key` | INT, PK | Surrogate key |
| `source_food_id` | VARCHAR(20), nullable | `fdc_id` in SR Legacy (NULL for categories we add) |
| `canonical_food_name` | VARCHAR(150) | Normalised name |
| `food_category` | VARCHAR(60) | Category aligned with the detector classes |
| `meal_type` | VARCHAR(20), nullable | meal, snack, dessert, drink |
| `is_beverage` | BOOLEAN | True for drinks |
| `energy_kcal_100g` | DECIMAL(7,2), nullable | Energy per 100 g (SR Legacy) |
| `protein_g_100g` | DECIMAL(6,2), nullable | Protein per 100 g (SR Legacy) |

Catalogue corrections overwrite; SR Legacy is a frozen release, so changes only fix errors.

## dim_detection_method — SCD Type 2

| Column | Type | Description |
|---|---|---|
| `method_key` | INT, PK | Surrogate key |
| `method_name` | VARCHAR(30) | `subtitle_match`, `description_match`, `yolo_detector` |
| `model_name` | VARCHAR(50), nullable | e.g. YOLO fine-tuned |
| `model_version` | VARCHAR(20) | v1, v2, … |
| `confidence_threshold` | DECIMAL(4,3) | Minimum confidence accepted |
| `valid_from` | DATE | Start of validity |
| `valid_to` | DATE, nullable | End of validity; NULL if current |
| `is_current` | BOOLEAN | Current-version flag |

Retraining the detector or changing the threshold adds a new row. Facts keep the version that produced them, so results are reproducible and versions can be compared.
