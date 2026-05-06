#!/usr/bin/env bash
set -euo pipefail

if ! command -v systemctl >/dev/null 2>&1; then
    pgrep -x nginx >/dev/null
    exit $?
fi

systemctl is-active --quiet nginx
