#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

>&2 echo "[compat] 'SOT vault' is deprecated. Use 'SOT vault open'."
exec "$SCRIPT_DIR/vault/open.sh" "$@"
