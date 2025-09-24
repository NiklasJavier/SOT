#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/../.." && pwd)

>&2 echo "[compat] 'SOT integrations validate_sync' is deprecated. Use 'SOT aat validate' and 'SOT tid validate'."

status=0
if ! "$ROOT_DIR/aat/validate.sh" "$@"; then
  status=1
fi
if ! "$ROOT_DIR/tid/validate.sh" "$@"; then
  status=1
fi

exit "$status"
