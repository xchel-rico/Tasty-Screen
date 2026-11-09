"""Local weekly warehouse check and dbt build; ingestion is not implemented."""

from datetime import datetime, timezone
import os
import subprocess

from airflow.sdk import dag, task


@dag(
    dag_id="warehouse_demo",
    schedule="@weekly",
    start_date=datetime(2026, 11, 1, tzinfo=timezone.utc),
    catchup=False,
    is_paused_upon_creation=True,
    tags=["tasty-screen", "demo"],
)
def warehouse_demo():
    @task
    def check_warehouse():
        subprocess.run(
            [os.environ["PIPELINE_PYTHON"], "/workspace/scripts/check_warehouse.py"],
            check=True,
        )

    @task
    def build_analytics():
        subprocess.run(
            [
                "/opt/pipeline/venv/bin/dbt",
                "build",
                "--project-dir",
                "/workspace/dbt",
                "--profiles-dir",
                "/workspace/dbt",
            ],
            check=True,
        )

    check_warehouse() >> build_analytics()


warehouse_demo()
