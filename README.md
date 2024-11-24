# builder-esp32
Builder for esp32 series

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
