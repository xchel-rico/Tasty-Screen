"""Read warehouse table counts without changing the schema or sample data."""

import json

import psycopg
from psycopg import sql


def main():
    tables = (
        "dim_movie",
        "dim_scene",
        "dim_food",
        "dim_detection_method",
        "fact_food_reference",
    )
    with psycopg.connect() as connection:
        with connection.transaction():
            connection.execute("SET TRANSACTION READ ONLY")
            counts = {
                table: connection.execute(
                    sql.SQL("SELECT COUNT(*) FROM public.{}").format(sql.Identifier(table))
                ).fetchone()[0]
                for table in tables
            }
    print(json.dumps(counts, sort_keys=True))


if __name__ == "__main__":
    main()
