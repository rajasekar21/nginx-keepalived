#!/usr/bin/env bash
set -euo pipefail

TYPE="${1:-unknown}"
NAME="${2:-unknown}"
STATE="${3:-unknown}"

logger -t keepalived-notify "instance=${NAME} type=${TYPE} state=${STATE} host=$(hostname -f 2>/dev/null || hostname)"
