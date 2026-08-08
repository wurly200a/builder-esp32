# syntax=docker/dockerfile:1.7
#
# builder-esp32 (UID非依存版)
#
# 変更点:
#   1. ツール類を $HOME/.espressif ではなく /opt/espressif に配置 (IDF_TOOLS_PATH)
#   2. 起動時に entrypoint がコンテナ内 ubuntu ユーザーの UID/GID を
#      マウント先 (/workspaces) の所有者に合わせる (gosu)
#   3. 環境設定を ~/.bashrc ではなく /etc/profile.d/ に配置
#   4. 最終 USER は root のまま (entrypoint が gosu で降格する)
#
# 使い方:
#   docker run --rm -it -v ${PWD}:/workspaces -w /workspaces <image>
#   ※ --user は付けないこと
#

FROM ubuntu:24.04 AS base

# ベースイメージ側の既定ユーザーに左右されないよう明示する
USER root

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"

# ツールの共有インストール先 (ホーム配下に置かないのが肝)
ENV IDF_PATH=/opt/esp-idf
ENV IDF_TOOLS_PATH=/opt/espressif

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

# 実行時に UID/GID を付け替えるために使用
RUN apt install -y gosu

# 任意の UID から git を実行しても "dubious ownership" にならないように
RUN git config --system --add safe.directory '*'

# ツール置き場を作成 (イメージビルド中は ubuntu が書き込む)
RUN mkdir -p ${IDF_TOOLS_PATH} && chown ${USER_NAME}:${GROUP_NAME} ${IDF_TOOLS_PATH}

# ---- clangd ラッパー (全バージョン共通) ----
RUN set -e; \
    cat > /usr/local/bin/clangd-with-idf <<'EOF' && chmod +x /usr/local/bin/clangd-with-idf
#!/usr/bin/env bash
set -euo pipefail
# Load ESP-IDF environment (adds esp-clang/clangd to PATH)
source /opt/esp-idf/export.sh >/dev/null 2>&1
LOG=/tmp/clangd.log
: > "$LOG" || { echo "cannot write $LOG" >&2; exit 1; }
exec clangd --background-index --header-insertion-decorators=0 --query-driver="/opt/espressif/tools/*/*/bin/*,/opt/esp-idf/tools/*/*/bin/*,/usr/bin/*" "$@" --log=verbose 2>>"$LOG"
EOF

# ---- entrypoint (全バージョン共通) ----
RUN set -e; \
    cat > /usr/local/bin/entrypoint.sh <<'EOF' && chmod +x /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -e

USER_NAME="${CONTAINER_USER:-ubuntu}"
REF_DIR="${UID_SOURCE_DIR:-/workspaces}"

# 既定はマウント先ディレクトリの所有者に合わせる
if [ -e "$REF_DIR" ]; then
    TARGET_UID="$(stat -c '%u' "$REF_DIR")"
    TARGET_GID="$(stat -c '%g' "$REF_DIR")"
else
    TARGET_UID=1000
    TARGET_GID=1000
fi

# 環境変数による明示指定を優先
TARGET_UID="${HOST_UID:-$TARGET_UID}"
TARGET_GID="${HOST_GID:-$TARGET_GID}"

# マウント先が root 所有だった場合は既定値へフォールバック
if [ "$TARGET_UID" = "0" ]; then
    TARGET_UID=1000
    TARGET_GID=1000
fi

if [ "$(id -u)" = "0" ]; then
    CUR_UID="$(id -u "$USER_NAME")"
    CUR_GID="$(id -g "$USER_NAME")"

    if [ "$CUR_GID" != "$TARGET_GID" ]; then
        groupmod -o -g "$TARGET_GID" "$USER_NAME"
    fi
    if [ "$CUR_UID" != "$TARGET_UID" ]; then
        usermod -o -u "$TARGET_UID" -g "$TARGET_GID" "$USER_NAME"
    fi
    if [ "$CUR_UID" != "$TARGET_UID" ] || [ "$CUR_GID" != "$TARGET_GID" ]; then
        # ツールは /opt にあるのでホームだけ直せばよい (高速)
        chown -R "$TARGET_UID:$TARGET_GID" "/home/$USER_NAME"
    fi

    # シリアルポート等を渡された場合、そのデバイスのグループに参加させる
    for dev in ${EXTRA_DEVICES:-/dev/ttyACM0 /dev/ttyUSB0}; do
        if [ -e "$dev" ]; then
            DEV_GID="$(stat -c '%g' "$dev")"
            DEV_GRP="$(getent group "$DEV_GID" | cut -d: -f1)"
            if [ -z "$DEV_GRP" ]; then
                DEV_GRP="devgrp${DEV_GID}"
                groupadd -o -g "$DEV_GID" "$DEV_GRP" 2>/dev/null || true
            fi
            usermod -aG "$DEV_GRP" "$USER_NAME" 2>/dev/null || true
        fi
    done

    export HOME="/home/$USER_NAME"
    exec gosu "$USER_NAME" "$@"
fi

# すでに非 root で起動された場合はそのまま実行
exec "$@"
EOF

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# /etc/profile.d を読ませるためログインシェルで起動する
CMD ["bash", "-l"]


#------------------------------------------------------------------------------
FROM base AS esp-idf-v4.4

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"
ARG ESP_IDF_VERSION=v4.4.5

RUN apt install -y python3-pip python3-setuptools python3-virtualenv clangd

# Get ESP-IDF
RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}
# ESP-IDF Set up the tools (IDF_TOOLS_PATH=/opt/espressif へ導入される)
RUN cd /opt/esp-idf && ./install.sh esp32

USER root
# 任意の UID から読み書きできるようにしておく
RUN chmod -R a+rwX ${IDF_TOOLS_PATH}

RUN set -e; \
    cat > /etc/profile.d/esp-idf.sh <<EOF
export IDF_PATH=/opt/esp-idf
export IDF_TOOLS_PATH=/opt/espressif
if [ -n "\$PS1" ]; then
    . /opt/esp-idf/export.sh
    PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w\$ '
else
    . /opt/esp-idf/export.sh >/dev/null 2>&1
fi
EOF

# 最終 USER は root のまま (entrypoint が gosu で降格する)
USER root


#------------------------------------------------------------------------------
FROM base AS esp-idf-v5.2

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"
ARG ESP_IDF_VERSION=v5.2.3

RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

USER root
RUN chmod -R a+rwX ${IDF_TOOLS_PATH}

RUN set -e; \
    cat > /etc/profile.d/esp-idf.sh <<EOF
export IDF_PATH=/opt/esp-idf
export IDF_TOOLS_PATH=/opt/espressif
if [ -n "\$PS1" ]; then
    . /opt/esp-idf/export.sh
    PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w\$ '
else
    . /opt/esp-idf/export.sh >/dev/null 2>&1
fi
EOF

USER root


#------------------------------------------------------------------------------
FROM base AS esp-idf-v5.3

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"
ARG ESP_IDF_VERSION=v5.3.1

RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

USER root
RUN chmod -R a+rwX ${IDF_TOOLS_PATH}

RUN set -e; \
    cat > /etc/profile.d/esp-idf.sh <<EOF
export IDF_PATH=/opt/esp-idf
export IDF_TOOLS_PATH=/opt/espressif
if [ -n "\$PS1" ]; then
    . /opt/esp-idf/export.sh
    PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w\$ '
else
    . /opt/esp-idf/export.sh >/dev/null 2>&1
fi
EOF

USER root


#------------------------------------------------------------------------------
FROM base AS esp-idf-v5.5

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"
ARG ESP_IDF_VERSION=v5.5.1

RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

USER root
RUN chmod -R a+rwX ${IDF_TOOLS_PATH}

RUN set -e; \
    cat > /etc/profile.d/esp-idf.sh <<EOF
export IDF_PATH=/opt/esp-idf
export IDF_TOOLS_PATH=/opt/espressif
if [ -n "\$PS1" ]; then
    . /opt/esp-idf/export.sh
    PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w\$ '
else
    . /opt/esp-idf/export.sh >/dev/null 2>&1
fi
EOF

USER root


#------------------------------------------------------------------------------
FROM base AS esp-idf-v6.0

ARG USER_NAME="ubuntu"
ARG GROUP_NAME="ubuntu"
ARG ESP_IDF_VERSION=v6.0.2

RUN cd /opt && git clone -b ${ESP_IDF_VERSION} --recursive https://github.com/espressif/esp-idf.git

USER ${USER_NAME}
RUN cd /opt/esp-idf && ./install.sh esp32 && python3 ./tools/idf_tools.py install esp-clang

USER root
RUN chmod -R a+rwX ${IDF_TOOLS_PATH}

RUN set -e; \
    cat > /etc/profile.d/esp-idf.sh <<EOF
export IDF_PATH=/opt/esp-idf
export IDF_TOOLS_PATH=/opt/espressif
if [ -n "\$PS1" ]; then
    . /opt/esp-idf/export.sh
    PS1='(docker)esp-idf-${ESP_IDF_VERSION}:\w\$ '
else
    . /opt/esp-idf/export.sh >/dev/null 2>&1
fi
EOF

USER root
