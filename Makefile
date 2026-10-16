.PHONY: test analyze flutter-test backend-test build-web build-apk docker-build

test: flutter-test backend-test

flutter-test:
	flutter test

backend-test:
	python -m pytest backend/tests

analyze:
	flutter analyze

build-web:
	flutter build web --release --dart-define=SYNCHRO_API=http://localhost:8000

build-apk:
	flutter build apk --release

docker-build:
	docker build -t synchro:local .
