-- =====================================================================
-- Food in Movies — star schema (gold layer), PostgreSQL
-- Grain of fact_food_reference: one row per canonical food x scene x
-- evidence type x detection-method version.
-- =====================================================================

DROP TABLE IF EXISTS fact_food_reference;
DROP TABLE IF EXISTS dim_scene;
DROP TABLE IF EXISTS dim_movie;
DROP TABLE IF EXISTS dim_food;
DROP TABLE IF EXISTS dim_detection_method;

-- ---------------------------------------------------------------------
-- dim_movie — SCD Type 1 (corrections overwrite)
-- ---------------------------------------------------------------------
CREATE TABLE dim_movie (
    movie_key          SERIAL       PRIMARY KEY,
    source_movie_name  VARCHAR(255) NOT NULL,            -- movie_name as in CinePile
    movie_title        VARCHAR(255) NOT NULL,            -- cleaned title
    release_year       SMALLINT     NOT NULL CHECK (release_year BETWEEN 1900 AND 2100),
    decade             VARCHAR(5)   NOT NULL,            -- e.g. '1990s'
    genre              VARCHAR(50),                      -- primary genre
    CONSTRAINT uq_movie UNIQUE (source_movie_name, release_year)
);

-- ---------------------------------------------------------------------
-- dim_scene — static (a published clip never changes)
-- ---------------------------------------------------------------------
CREATE TABLE dim_scene (
    scene_key          SERIAL       PRIMARY KEY,
    clip_link          VARCHAR(255) NOT NULL UNIQUE,     -- yt_clip_link (natural key)
    clip_title         VARCHAR(255),                     -- yt_clip_title
    movie_key          INT          NOT NULL REFERENCES dim_movie (movie_key),
    scene_description  TEXT,                             -- movie_scene
    subtitle_text      TEXT,                             -- subtitles
    n_frames_sampled   INT          CHECK (n_frames_sampled >= 0)  -- NULL if not processed visually
);

-- ---------------------------------------------------------------------
-- dim_food — SCD Type 1 (catalogue corrections overwrite)
-- ---------------------------------------------------------------------
CREATE TABLE dim_food (
    food_key             SERIAL        PRIMARY KEY,
    source_food_id       VARCHAR(20),                     -- fdc_id in SR Legacy; NULL for categories we add
    canonical_food_name  VARCHAR(150)  NOT NULL UNIQUE,
    food_category        VARCHAR(60)   NOT NULL,          -- aligned with detector classes
    meal_type            VARCHAR(20),                     -- meal, snack, dessert, drink
    is_beverage          BOOLEAN       NOT NULL DEFAULT FALSE,
    energy_kcal_100g     DECIMAL(7,2),
    protein_g_100g       DECIMAL(6,2)
);

-- ---------------------------------------------------------------------
-- dim_detection_method — SCD Type 2 (new row per model version/threshold)
-- ---------------------------------------------------------------------
CREATE TABLE dim_detection_method (
    method_key            SERIAL       PRIMARY KEY,
    method_name           VARCHAR(30)  NOT NULL
        CHECK (method_name IN ('subtitle_match', 'description_match', 'yolo_detector')),
    model_name            VARCHAR(50),
    model_version         VARCHAR(20)  NOT NULL,
    confidence_threshold  DECIMAL(4,3) NOT NULL CHECK (confidence_threshold BETWEEN 0 AND 1),
    valid_from            DATE         NOT NULL,
    valid_to              DATE,                            -- NULL while current
    is_current            BOOLEAN      NOT NULL,
    CONSTRAINT uq_method_version UNIQUE (method_name, model_version)
);

-- ---------------------------------------------------------------------
-- fact_food_reference
-- ---------------------------------------------------------------------
CREATE TABLE fact_food_reference (
    food_reference_key  BIGSERIAL    PRIMARY KEY,
    movie_key           INT          NOT NULL REFERENCES dim_movie (movie_key),
    scene_key           INT          NOT NULL REFERENCES dim_scene (scene_key),
    food_key            INT          NOT NULL REFERENCES dim_food (food_key),
    method_key          INT          NOT NULL REFERENCES dim_detection_method (method_key),
    reference_type      VARCHAR(10)  NOT NULL CHECK (reference_type IN ('MENTION', 'DESCRIBED', 'VISUAL')),
    original_label      VARCHAR(100) NOT NULL,             -- raw phrase / class before normalisation
    occurrence_count    INT          NOT NULL CHECK (occurrence_count >= 1),
    avg_confidence      DECIMAL(4,3) NOT NULL CHECK (avg_confidence BETWEEN 0 AND 1),
    max_confidence      DECIMAL(4,3) NOT NULL CHECK (max_confidence BETWEEN 0 AND 1),
    first_seen_sec      INT          CHECK (first_seen_sec >= 0),  -- visual only
    batch_id            VARCHAR(40)  NOT NULL,
    CONSTRAINT uq_fact_grain UNIQUE (food_key, scene_key, reference_type, method_key)
);

CREATE INDEX ix_fact_movie ON fact_food_reference (movie_key);
CREATE INDEX ix_fact_scene ON fact_food_reference (scene_key);
CREATE INDEX ix_fact_food  ON fact_food_reference (food_key);
CREATE INDEX ix_fact_type  ON fact_food_reference (reference_type);
