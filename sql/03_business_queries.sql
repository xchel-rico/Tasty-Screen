-- =====================================================================
-- Food in Movies — demo queries for the business questions Q1–Q7.
-- Visual queries keep only the current detector version (is_current).
-- =====================================================================

-- Q1. Which food categories are shown on screen most often?
SELECT f.food_category, SUM(r.occurrence_count) AS appearances
FROM fact_food_reference r
JOIN dim_food f             ON f.food_key   = r.food_key
JOIN dim_detection_method d ON d.method_key = r.method_key
WHERE r.reference_type = 'VISUAL' AND d.is_current
GROUP BY f.food_category
ORDER BY appearances DESC;

-- Q2. Which foods are mentioned most often in dialogue?
SELECT f.canonical_food_name, SUM(r.occurrence_count) AS mentions
FROM fact_food_reference r
JOIN dim_food f ON f.food_key = r.food_key
WHERE r.reference_type = 'MENTION'
GROUP BY f.canonical_food_name
ORDER BY mentions DESC
LIMIT 20;

-- Q3. In which scenes is the same food both mentioned and shown?
SELECT m.movie_title, s.clip_title, f.canonical_food_name
FROM fact_food_reference r
JOIN dim_movie m            ON m.movie_key  = r.movie_key
JOIN dim_scene s            ON s.scene_key  = r.scene_key
JOIN dim_food  f            ON f.food_key   = r.food_key
JOIN dim_detection_method d ON d.method_key = r.method_key
WHERE r.reference_type IN ('MENTION', 'VISUAL') AND d.is_current
GROUP BY m.movie_title, s.clip_title, f.canonical_food_name
HAVING COUNT(DISTINCT r.reference_type) = 2;

-- Q4. Which genres have the highest food reference rate per 100 scenes?
WITH scenes AS (
    SELECT m.genre, COUNT(*) AS n_scenes
    FROM dim_scene s
    JOIN dim_movie m ON m.movie_key = s.movie_key
    GROUP BY m.genre
),
refs AS (
    SELECT m.genre, COUNT(*) AS n_refs
    FROM fact_food_reference r
    JOIN dim_movie m            ON m.movie_key  = r.movie_key
    JOIN dim_detection_method d ON d.method_key = r.method_key
    WHERE d.is_current
    GROUP BY m.genre
)
SELECT s.genre,
       ROUND(100.0 * COALESCE(r.n_refs, 0) / s.n_scenes, 1) AS refs_per_100_scenes
FROM scenes s
LEFT JOIN refs r ON r.genre = s.genre
ORDER BY refs_per_100_scenes DESC;

-- Q5. Which food categories appear across the widest range of genres?
SELECT f.food_category, COUNT(DISTINCT m.genre) AS n_genres
FROM fact_food_reference r
JOIN dim_food  f ON f.food_key  = r.food_key
JOIN dim_movie m ON m.movie_key = r.movie_key
GROUP BY f.food_category
ORDER BY n_genres DESC, f.food_category;

-- Q6. Which movies feature the highest number of food references?
SELECT m.movie_title,
       m.release_year,
       m.genre,
       SUM(r.occurrence_count)                       AS food_references,
       COUNT(DISTINCT r.food_key)                    AS distinct_foods,
       COUNT(DISTINCT r.scene_key)                   AS scenes_with_food
FROM fact_food_reference r
JOIN dim_movie m            ON m.movie_key  = r.movie_key
JOIN dim_detection_method d ON d.method_key = r.method_key
WHERE d.is_current
GROUP BY m.movie_key, m.movie_title, m.release_year, m.genre
ORDER BY food_references DESC
LIMIT 10;

-- Q7. Are beverages shown more often than solid food?
SELECT CASE WHEN f.is_beverage THEN 'beverage' ELSE 'solid food' END AS kind,
       SUM(r.occurrence_count) AS appearances
FROM fact_food_reference r
JOIN dim_food f             ON f.food_key   = r.food_key
JOIN dim_detection_method d ON d.method_key = r.method_key
WHERE r.reference_type = 'VISUAL' AND d.is_current
GROUP BY 1
ORDER BY appearances DESC;
