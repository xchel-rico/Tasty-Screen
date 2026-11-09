-- Preserve the fact grain and expose only current detection-method versions.
select
    r.*,
    f.canonical_food_name,
    f.food_category,
    f.is_beverage,
    d.method_name,
    d.model_version
from {{ source('warehouse', 'fact_food_reference') }} as r
join {{ source('warehouse', 'dim_food') }} as f
    on f.food_key = r.food_key
join {{ source('warehouse', 'dim_detection_method') }} as d
    on d.method_key = r.method_key
where d.is_current
