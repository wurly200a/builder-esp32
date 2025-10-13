FROM ubuntu:24.04 AS base

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"

# basic
FROM base AS esp-idf-v4.4

# ESP-IDF Prerequisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git wget flex bison gperf python3 python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 \
    python3-pip python3-setuptools python3-virtualenv clangd && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Get ESP-IDF
ARG ESP_IDF_VERSION=v4.4.5
RUN cd /opt && git clone --depth 1 -b ${ESP_IDF_VERSION} --recursive --shallow-submodules https://github.com/espressif/esp-idf.git

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc

USER root
RUN set -e; \
    rm -rf /home/${USER_NAME}/.espressif/dist /home/${USER_NAME}/.cache || true; \
    rm -rf /root/.cache || true; \
    rm -rf /opt/esp-idf/.git /opt/esp-idf/examples || true; \
    cat > /usr/local/bin/clangd-with-idf <<'EOF' && chmod +x /usr/local/bin/clangd-with-idf
#!/usr/bin/env bash
set -euo pipefail
# Load ESP-IDF environment (adds esp-clang/clangd to PATH)
source /opt/esp-idf/export.sh >/dev/null 2>&1
LOG=/tmp/clangd.log
: > "$LOG" || { echo "cannot write $LOG" >&2; exit 1; }
exec clangd --background-index --header-insertion-decorators=0 --query-driver="/home/*/.espressif/tools/*/*/bin/*,/opt/esp-idf/tools/*/*/bin/*,/usr/bin/*" "$@" --log=verbose 2>>"$LOG"
EOF
USER ${USER_NAME}

FROM base AS esp-idf-v5.3

# ESP-IDF Prerequisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git wget flex bison gperf python3 python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Get ESP-IDF
ARG ESP_IDF_VERSION=v5.3.1
RUN cd /opt && git clone --depth 1 -b ${ESP_IDF_VERSION} --recursive --shallow-submodules https://github.com/espressif/esp-idf.git

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc

USER root
RUN set -e; \
    rm -rf /home/${USER_NAME}/.espressif/dist /home/${USER_NAME}/.cache || true; \
    rm -rf /root/.cache || true; \
    rm -rf /opt/esp-idf/.git /opt/esp-idf/examples || true; \
    cat > /usr/local/bin/clangd-with-idf <<'EOF' && chmod +x /usr/local/bin/clangd-with-idf
#!/usr/bin/env bash
set -euo pipefail
# Load ESP-IDF environment (adds esp-clang/clangd to PATH)
source /opt/esp-idf/export.sh >/dev/null 2>&1
LOG=/tmp/clangd.log
: > "$LOG" || { echo "cannot write $LOG" >&2; exit 1; }
exec clangd --background-index --header-insertion-decorators=0 --query-driver="/home/*/.espressif/tools/*/*/bin/*,/opt/esp-idf/tools/*/*/bin/*,/usr/bin/*" "$@" --log=verbose 2>>"$LOG"
EOF
USER ${USER_NAME}

FROM base AS esp-idf-v5.2

# ESP-IDF Prerequisites
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git wget flex bison gperf python3 python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

# Get ESP-IDF
ARG ESP_IDF_VERSION=v5.2.3
RUN cd /opt && git clone --depth 1 -b ${ESP_IDF_VERSION} --recursive --shallow-submodules https://github.com/espressif/esp-idf.git

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc

USER root
RUN set -e; \
    rm -rf /home/${USER_NAME}/.espressif/dist /home/${USER_NAME}/.cache || true; \
    rm -rf /root/.cache || true; \
    rm -rf /opt/esp-idf/.git /opt/esp-idf/examples || true; \
    cat > /usr/local/bin/clangd-with-idf <<'EOF' && chmod +x /usr/local/bin/clangd-with-idf
#!/usr/bin/env bash
set -euo pipefail
# Load ESP-IDF environment (adds esp-clang/clangd to PATH)
source /opt/esp-idf/export.sh >/dev/null 2>&1
LOG=/tmp/clangd.log
: > "$LOG" || { echo "cannot write $LOG" >&2; exit 1; }
exec clangd --background-index --header-insertion-decorators=0 --query-driver="/home/*/.espressif/tools/*/*/bin/*,/opt/esp-idf/tools/*/*/bin/*,/usr/bin/*" "$@" --log=verbose 2>>"$LOG"
EOF
USER ${USER_NAME}

FROM esp-idf-v5.3 AS esp-idf-v5.3-nuttx

USER root

# NuttX Prerequisites
# NuttX Kconfig frontend
# NuttX Toolchain
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bison flex gettext texinfo libncurses5-dev libncursesw5-dev xxd \
    gperf automake libtool pkg-config build-essential gperf genromfs \
    libgmp-dev libmpc-dev libmpfr-dev libisl-dev binutils-dev libelf-dev \
    libexpat-dev gcc-multilib g++-multilib picocom u-boot-tools util-linux \
    zip unzip \
    kconfig-frontends \
    gcc-arm-none-eabi binutils-arm-none-eabi && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*

USER ${USER_NAME}
