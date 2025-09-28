FROM ubuntu:24.04 AS base

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

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

RUN tee /etc/profile.d/esp-idf.sh >/dev/null <<'EOF'
export IDF_PATH=/opt/esp-idf
[ -r /opt/esp-idf/export.sh ] && . /opt/esp-idf/export.sh >/dev/null 2>&1 || :
for d in "$HOME/.espressif/tools/esp-clang"/*/esp-clang/bin \
         "$HOME/.espressif/tools/xtensa-esp-elf"/*/xtensa-esp32s3-elf/bin
do
  [ -d "$d" ] || continue
  case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH";; esac
done
export PATH
EOF

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc

FROM base AS esp-idf-v5.2

# Get ESP-IDF
ARG ESP_IDF_VERSION=v5.2.3
RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

RUN tee /etc/profile.d/esp-idf.sh >/dev/null <<'EOF'
export IDF_PATH=/opt/esp-idf
[ -r /opt/esp-idf/export.sh ] && . /opt/esp-idf/export.sh >/dev/null 2>&1 || :
for d in "$HOME/.espressif/tools/esp-clang"/*/esp-clang/bin \
         "$HOME/.espressif/tools/xtensa-esp-elf"/*/xtensa-esp32s3-elf/bin
do
  [ -d "$d" ] || continue
  case ":$PATH:" in *":$d:"*) ;; *) PATH="$d:$PATH";; esac
done
export PATH
EOF

USER ${USER_NAME}

# ESP-IDF Set up the tools
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

RUN echo "export IDF_PATH=/opt/esp-idf" >> /home/${USER_NAME}/.bashrc && \
    echo "source /opt/esp-idf/export.sh" >> /home/${USER_NAME}/.bashrc && \
    echo "PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w${PS1}'" >> /home/${USER_NAME}/.bashrc
