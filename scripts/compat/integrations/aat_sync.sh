#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

>&2 echo "[compat] 'SOT integrations aat_sync' is deprecated. Use 'SOT aat sync' instead."
exec "$ROOT_DIR/aat/sync.sh" "$@"
