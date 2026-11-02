FROM python:3.12.16-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 ffmpeg libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /opt/requirements.txt
RUN python -m pip install --no-cache-dir -r /opt/requirements.txt \
    && python -m pip check

RUN groupadd --gid 1000 app \
    && useradd --uid 1000 --gid app --create-home app
WORKDIR /workspace/vision
COPY --chown=app:app . /workspace/vision
USER app
CMD ["sleep", "infinity"]
