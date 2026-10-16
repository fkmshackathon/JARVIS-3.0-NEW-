.PHONY: test analyze flutter-test backend-test build-web build-apk docker-build

test: flutter-test backend-test

flutter-test:
	flutter test

backend-test:
	python -m pytest backend/tests

analyze:
	flutter analyze

build-web:
	flutter build web --release

build-apk:
	flutter build apk --release

docker-build:
	docker build -t synchro:local .
