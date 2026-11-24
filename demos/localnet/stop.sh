#!/usr/bin/env bash
#
# Stops the localnet started by demos/localnet/start.sh. The chain home is
# kept; the next start.sh wipes and recreates it.

set -euo pipefail

CONTAINER="${LOCALNET_CONTAINER:-injective-localnet}"

if docker rm -f "$CONTAINER" > /dev/null 2>&1; then
    echo "stopped $CONTAINER"
else
    echo "$CONTAINER is not running"
fi
