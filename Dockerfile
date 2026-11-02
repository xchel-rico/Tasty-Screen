FROM python:3.12.16-slim-bookworm AS development

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
COPY requirements.txt /opt/requirements/requirements.txt
RUN python -m pip install --no-cache-dir -r /opt/requirements/requirements.txt \
    && python -m pip check

RUN groupadd --gid 1000 app \
    && useradd --uid 1000 --gid app --create-home app

COPY --chown=app:app . /workspace
USER app
CMD ["sleep", "infinity"]
