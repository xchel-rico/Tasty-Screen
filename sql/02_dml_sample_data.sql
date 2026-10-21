-- =====================================================================
-- Illustrative sample data (hand-written, NOT real CinePile records).
-- Movie titles, clip links and texts are placeholders that only show the
-- shape of the data so that the demo queries return something.
-- Real samples: run scripts/make_samples.py.
-- =====================================================================

INSERT INTO dim_movie (source_movie_name, movie_title, release_year, decade, genre) VALUES
  ('example_movie_a', 'Example Movie A', 1994, '1990s', 'Crime'),
  ('example_movie_b', 'Example Movie B', 2007, '2000s', 'Comedy'),
  ('example_movie_c', 'Example Movie C', 2015, '2010s', 'Drama');

INSERT INTO dim_scene (clip_link, clip_title, movie_key, scene_description, subtitle_text, n_frames_sampled) VALUES
  ('https://www.youtube.com/watch?v=EXAMPLE_A1', 'Example Movie A — diner scene', 1,
   'Two men sit in a diner; one eats a burger and drinks a soda.', 'Is that a good burger? ... Mind if I try some of your soda?', 75),
  ('https://www.youtube.com/watch?v=EXAMPLE_B1', 'Example Movie B — kitchen scene', 2,
   'She takes a pizza out of the oven.', 'Who wants pizza? ... I made coffee too.', 80),
  ('https://www.youtube.com/watch?v=EXAMPLE_C1', 'Example Movie C — bar scene', 3,
   'He orders a glass of wine at the bar.', 'Just a glass of red, please.', 70),
  ('https://www.youtube.com/watch?v=EXAMPLE_C2', 'Example Movie C — office scene', 3,
   'They argue in an office.', 'You never listen to me.', NULL);

INSERT INTO dim_food (source_food_id, canonical_food_name, food_category, meal_type, is_beverage, energy_kcal_100g, protein_g_100g) VALUES
  (NULL, 'Hamburger',       'burger/sandwich',  'meal',  FALSE, NULL, NULL),
  (NULL, 'Pizza',           'pizza',            'meal',  FALSE, NULL, NULL),
  (NULL, 'Soft drink',      'soft drink/bottle','drink', TRUE,  NULL, NULL),
  (NULL, 'Coffee',          'hot drink',        'drink', TRUE,  NULL, NULL),
  (NULL, 'Wine',            'alcoholic drink',  'drink', TRUE,  NULL, NULL);
-- In the real load, source_food_id and nutrition values come from SR Legacy.

INSERT INTO dim_detection_method (method_name, model_name, model_version, confidence_threshold, valid_from, valid_to, is_current) VALUES
  ('subtitle_match',    'spaCy PhraseMatcher', 'v1', 1.000, '2026-11-01', NULL,         TRUE),
  ('description_match', 'spaCy PhraseMatcher', 'v1', 1.000, '2026-11-01', NULL,         TRUE),
  ('yolo_detector',     'YOLO fine-tuned',     'v1', 0.500, '2026-11-01', '2026-11-30', FALSE),
  ('yolo_detector',     'YOLO fine-tuned',     'v2', 0.550, '2026-12-01', NULL,         TRUE);   -- SCD Type 2: new version row

INSERT INTO fact_food_reference
  (movie_key, scene_key, food_key, method_key, reference_type, original_label, occurrence_count, avg_confidence, max_confidence, first_seen_sec, batch_id) VALUES
  -- scene A1: burger mentioned, described and seen; soda mentioned and seen
  (1, 1, 1, 1, 'MENTION',   'burger',     1, 1.000, 1.000, NULL, '2026-W48'),
  (1, 1, 1, 2, 'DESCRIBED', 'burger',     1, 1.000, 1.000, NULL, '2026-W48'),
  (1, 1, 1, 4, 'VISUAL',    'burger',     3, 0.820, 0.910,   12, '2026-W49'),
  (1, 1, 3, 1, 'MENTION',   'soda',       1, 1.000, 1.000, NULL, '2026-W48'),
  (1, 1, 3, 4, 'VISUAL',    'bottle',     2, 0.640, 0.700,   20, '2026-W49'),
  -- old model version kept for comparison (SCD 2)
  (1, 1, 1, 3, 'VISUAL',    'sandwich',   2, 0.600, 0.680,   14, '2026-W48'),
  -- scene B1: pizza mentioned and seen; coffee only mentioned
  (2, 2, 2, 1, 'MENTION',   'pizza',      1, 1.000, 1.000, NULL, '2026-W48'),
  (2, 2, 2, 4, 'VISUAL',    'pizza',      1, 0.930, 0.930,    5, '2026-W49'),
  (2, 2, 4, 1, 'MENTION',   'coffee',     1, 1.000, 1.000, NULL, '2026-W48'),
  -- scene C1: wine described and seen
  (3, 3, 5, 2, 'DESCRIBED', 'glass of wine', 1, 1.000, 1.000, NULL, '2026-W48'),
  (3, 3, 5, 4, 'VISUAL',    'wine glass', 2, 0.770, 0.880,    3, '2026-W49');
