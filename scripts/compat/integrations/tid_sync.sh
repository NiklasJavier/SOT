#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

>&2 echo "[compat] 'SOT integrations tid_sync' is deprecated. Use 'SOT tid sync' instead."
exec "$ROOT_DIR/tid/sync.sh" "$@"
