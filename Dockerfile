FROM ubuntu:24.04 AS base

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"

# basic
RUN apt update -y

# NuttX Prerequisites
RUN apt install -y \
    bison flex gettext texinfo libncurses5-dev libncursesw5-dev xxd \
    gperf automake libtool pkg-config build-essential gperf genromfs \
    libgmp-dev libmpc-dev libmpfr-dev libisl-dev binutils-dev libelf-dev \
    libexpat-dev gcc-multilib g++-multilib picocom u-boot-tools util-linux \
    zip unzip

# NuttX Kconfig frontend
RUN apt install -y kconfig-frontends

# NuttX Toolchain
RUN apt install -y gcc-arm-none-eabi binutils-arm-none-eabi

# ESP-IDF Prerequisites
RUN apt install -y git wget flex bison gperf python3 python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0

FROM base AS esp-idf-v5.3

# Get ESP-IDF
ARG ESP_IDF_VERSION=v5.3.1
RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc

USER root
RUN set -eux; \
  cat >/usr/local/bin/espidf-entrypoint.sh <<'EOF' && chmod +x /usr/local/bin/espidf-entrypoint.sh
#!/usr/bin/env bash
set -e
# Always load ESP-IDF environment (PATH, tools, etc.)
if [ -f /opt/esp-idf/export.sh ]; then
  # shellcheck disable=SC1091
  source /opt/esp-idf/export.sh >/dev/null 2>&1 || true
fi
# Ensure clangd is reachable even if not on PATH yet
if ! command -v clangd >/dev/null 2>&1; then
  for p in \
    /home/*/.espressif/tools/esp-clang/*/esp-clang/bin/clangd \
    /opt/esp-idf/tools/llvm/bin/clangd \
    /usr/local/bin/clangd /usr/bin/clangd; do
    if [ -x "$p" ]; then
      export PATH="$(dirname "$p"):$PATH"
      break
    fi
  done
fi
exec "$@"
EOF
ENTRYPOINT ["/usr/local/bin/espidf-entrypoint.sh"]
USER ${USER_NAME}

FROM base AS esp-idf-v5.2

# Get ESP-IDF
ARG ESP_IDF_VERSION=v5.2.3
RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc

USER root
RUN set -eux; \
  cat >/usr/local/bin/espidf-entrypoint.sh <<'EOF' && chmod +x /usr/local/bin/espidf-entrypoint.sh
#!/usr/bin/env bash
set -e
if [ -f /opt/esp-idf/export.sh ]; then
  source /opt/esp-idf/export.sh >/dev/null 2>&1 || true
fi
if ! command -v clangd >/dev/null 2>&1; then
  for p in \
    /home/*/.espressif/tools/esp-clang/*/esp-clang/bin/clangd \
    /opt/esp-idf/tools/llvm/bin/clangd \
    /usr/local/bin/clangd /usr/bin/clangd; do
    if [ -x "$p" ]; then
      export PATH="$(dirname "$p"):$PATH"
      break
    fi
  done
fi
exec "$@"
EOF
ENTRYPOINT ["/usr/local/bin/espidf-entrypoint.sh"]
USER ${USER_NAME}
