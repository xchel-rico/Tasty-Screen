# Local Airflow

The root Compose stack runs Airflow 3.3.2 in [standalone development mode](https://airflow.apache.org/docs/apache-airflow/3.3.2/start.html). This starts the API server/UI, scheduler, DAG processor, and triggerer in one container, using LocalExecutor. It is a local development setup.

Airflow stores its metadata in the separate `airflow-postgres` service. The analytical warehouse remains in the `postgres` service; its existing schema and volume are unchanged. Airflow is installed from its official image, while pipeline packages from the root `requirements.txt` are installed in `/opt/pipeline/venv`. Tasks invoke that environment explicitly.

## Start and log in

From the repository root, copy `.env.example` to `.env` if you have not already done so. Set `POSTGRES_PASSWORD` and choose an `AIRFLOW_DB_PASSWORD`. Existing `.env` files can add the two Airflow settings from the example without replacing warehouse credentials.

```bash
docker compose up -d --build --wait
docker compose logs -f airflow
```

Open `http://localhost:8080`, or your configured `AIRFLOW_PORT`. The username is `admin`. Airflow's [Simple auth manager](https://airflow.apache.org/docs/apache-airflow/3.3.2/core-concepts/auth-manager/simple/index.html) generates the password and prints it in its logs. You can also read it locally:

```bash
docker compose exec airflow cat /opt/airflow/simple_auth_manager_passwords.json.generated
```

The `admin:admin` setting in Compose means **username `admin`, role `admin`**; it does not set the password to `admin`. The generated password is retained in the `airflow_home` volume. Changing `AIRFLOW_DB_PASSWORD` after initialization does not change the existing metadata database role's password automatically.

The UI port is bound to localhost, and the metadata database has no published port. The example metadata credentials are for local development. Allocate sufficient memory for Airflow and both databases; its initial startup can take longer than the Python development container.

## Demo DAG

[`dags/warehouse_demo.py`](dags/warehouse_demo.py) defines `warehouse_demo`, with a weekly schedule and no catchup. It starts **paused**, so it does not run automatically on installation. Its tasks:

1. Read the row counts of the five existing warehouse tables with `scripts/check_warehouse.py`.
2. Run `dbt build` to create or refresh `analytics.current_food_references`.

The first task is read-only. The dbt task manages the analytical view; neither task recreates the warehouse tables or inserts sample rows. This is a working demo of orchestration, not the full CinePile/USDA ingestion pipeline.

After startup and DAG discovery, find `warehouse_demo` in the UI and trigger it manually. Alternatively:

```bash
docker compose exec airflow airflow dags list
docker compose exec airflow airflow dags trigger warehouse_demo
```

Use the UI to inspect task logs and results. Unpause the DAG when you want the weekly schedule to run. Add future DAGs under `airflow/dags/`; that folder is mounted read-only into the container. The repository is also mounted at `/workspace`, allowing tasks to read scripts and dbt models and persist generated dbt output locally.

## Check and stop

```bash
docker compose ps
docker compose exec airflow airflow db check
docker compose exec airflow /opt/pipeline/venv/bin/python -m pip check
docker compose down
```

`docker compose down` preserves both databases and Airflow state. `docker compose down --volumes` deletes all root-stack volumes, including warehouse data, Airflow history, logs, and generated login credentials. The independent `vision/` Compose project is unaffected by these root-stack commands.
