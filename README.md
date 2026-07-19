# builder-esp32
Builder for esp32 series

## Published images

Images are built per ESP-IDF patch version and pushed to `ghcr.io/wurly200a/builder-esp32/<family>:<version>`
(e.g. `esp-idf-v5.5:5.5.5`). Each family also has a floating `:latest` tag that always points at its newest
patch version (e.g. `esp-idf-v5.5:latest` -> `esp-idf-v5.5:5.5.5`).

The set of patch versions to build is defined in [`esp-idf-versions.json`](./esp-idf-versions.json); the last
entry in each family's array is the one aliased to `:latest`. Adding a new patch version there is enough for CI
to build and publish it — already-published versions are never rebuilt.

## Build

```
docker build --target esp-idf-v5.3 -t ghcr.io/wurly200a/builder-esp32/esp-idf-v5.3:latest .
docker build --target esp-idf-v5.2 -t ghcr.io/wurly200a/builder-esp32/esp-idf-v5.2:latest .
```

## Run

```
docker run --rm -it -v ${PWD}:/mnt/work -w /mnt/work ghcr.io/wurly200a/builder-esp32/esp-idf-v5.3:latest
docker run --rm -it -v ${PWD}:/mnt/work -w /mnt/work ghcr.io/wurly200a/builder-esp32/esp-idf-v5.2:latest
```
