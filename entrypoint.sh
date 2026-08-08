#!/usr/bin/env bash
set -e

USER_NAME=ubuntu

# 作業ディレクトリの所有者に合わせる（環境変数で上書きも可）
if [ -d /workspaces ]; then
  DEFAULT_UID=$(stat -c '%u' /workspaces)
  DEFAULT_GID=$(stat -c '%g' /workspaces)
else
  DEFAULT_UID=1000
  DEFAULT_GID=1000
fi
TARGET_UID=${HOST_UID:-$DEFAULT_UID}
TARGET_GID=${HOST_GID:-$DEFAULT_GID}

if [ "$(id -u)" = "0" ] && [ "$TARGET_UID" != "0" ]; then
    CUR_UID=$(id -u  "$USER_NAME")
    CUR_GID=$(id -g  "$USER_NAME")

    [ "$CUR_GID" != "$TARGET_GID" ] && groupmod -o -g "$TARGET_GID" "$USER_NAME"
    [ "$CUR_UID" != "$TARGET_UID" ] && usermod  -o -u "$TARGET_UID" -g "$TARGET_GID" "$USER_NAME"

    # ホームだけ直せばよい（ツールは /opt にあるので chown -R が軽い）
    chown -R "$TARGET_UID:$TARGET_GID" "/home/$USER_NAME"

    exec gosu "$USER_NAME" "$@"
fi

exec "$@"
