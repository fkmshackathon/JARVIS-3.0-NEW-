.PHONY: test analyze flutter-test backend-test build-web build-apk docker-build

PYTHON ?= $(if $(wildcard .venv/bin/python),.venv/bin/python,$(if $(wildcard .venv/Scripts/python.exe),.venv/Scripts/python.exe,python))

test: flutter-test backend-test

flutter-test:
	flutter test --no-pub

backend-test:
	$(PYTHON) -m pytest backend/tests

analyze:
	flutter analyze --no-pub

build-web:
	flutter build web --release --no-pub

build-apk:
	flutter build apk --release

docker-build:
	docker build -t synchro:local .
