FROM denoland/deno:bin-2.5.6 AS javascript

FROM apache/airflow:3.3.2-python3.12

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 ffmpeg \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/pipeline \
    && chown airflow:0 /opt/pipeline
COPY --from=javascript /deno /usr/local/bin/deno
COPY requirements.txt /opt/pipeline/requirements.txt

# Keep pipeline libraries separate from the official Airflow installation.
USER airflow
RUN python -m venv /opt/pipeline/venv \
    && /opt/pipeline/venv/bin/python -m pip install --no-cache-dir -r /opt/pipeline/requirements.txt \
    && /opt/pipeline/venv/bin/python -m pip check
ENV PIPELINE_PYTHON=/opt/pipeline/venv/bin/python
