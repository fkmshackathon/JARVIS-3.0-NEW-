# Reproducible two-process demo image: FastAPI on :8000 and the Flutter web
# build on :8080. The Flutter client still talks to the existing API contract.
FROM ghcr.io/cirruslabs/flutter:3.47.1 AS flutter-build

WORKDIR /workspace
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=SYNCHRO_API=http://localhost:8000

FROM python:3.14.7-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace/backend

WORKDIR /workspace
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt backend/requirements.txt
RUN python -m pip install --no-cache-dir -r backend/requirements.txt
COPY backend backend
COPY --from=flutter-build /workspace/build/web web-build
COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod +x docker-entrypoint.sh

EXPOSE 8000 8080
CMD ["/workspace/docker-entrypoint.sh"]
