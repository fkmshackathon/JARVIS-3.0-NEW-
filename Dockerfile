# Same-origin deployment: Flutter web + scheduling API + server-only Groq.
FROM ghcr.io/cirruslabs/flutter:3.47.1 AS flutter-build

WORKDIR /workspace
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM python:3.14.7-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace/backend \
    SYNCHRO_WEB_DIR=/workspace/web-build \
    PORT=8080

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

EXPOSE 8080
CMD ["/workspace/docker-entrypoint.sh"]
