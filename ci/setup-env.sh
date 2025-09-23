#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CI_TMP_DIR=${CI_TMP_DIR:-"$ROOT_DIR/ci/tmp"}
CI_BIN_DIR="$ROOT_DIR/ci/bin"
CONFIG_FILE_PATH="$CI_TMP_DIR/config.ci.yml"
VAULT_FILE_PATH="$CI_TMP_DIR/vault.ci.yml"
LOG_FILE_PATH="$CI_TMP_DIR/sot-cli.log"

mkdir -p "$CI_TMP_DIR" "$CI_BIN_DIR"

# Provide a mock ansible-vault implementation for test environments. This keeps
# the vault workflow non-interactive while still exercising the shell logic.
cat <<'MOCK' > "$CI_BIN_DIR/ansible-vault"
#!/usr/bin/env bash
set -euo pipefail
command=$1
shift || true
case "$command" in
  edit|view)
    echo "[ci] ansible-vault $command $*" >&2
    exit 0
    ;;
  encrypt|decrypt)
    echo "[ci] ansible-vault $command $*" >&2
    exit 0
    ;;
  *)
    echo "[ci] ansible-vault unsupported command: $command" >&2
    exit 0
    ;;
esac
MOCK
chmod +x "$CI_BIN_DIR/ansible-vault"

export PATH="$CI_BIN_DIR:$PATH"
if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "$CI_BIN_DIR" >> "$GITHUB_PATH"
fi

# Default secret fallbacks keep local executions deterministic while the
# workflows inject real secrets through GitHub Actions.
VAULT_SECRET_VALUE=${SOT_VAULT_SECRET:-"local-ci-secret"}
VAULT_MAIL_VALUE=${SOT_VAULT_MAIL:-"ci@example.com"}
BRANCH_NAME=${SOT_BRANCH:-"ci"}

cat > "$CONFIG_FILE_PATH" <<EOF_CONFIG
system_name: "ci-system"
username: "ci-user"
ssh_port: "2222"
log_level: "debug"
log_file: "$LOG_FILE_PATH"
use_defaults: "true"
tools: "ansible docker sdkman"
clone_dir: "$ROOT_DIR"
modules_dir: "$ROOT_DIR/modules"
scripts_dir: "$ROOT_DIR/scripts"
pipelines_dir: "$ROOT_DIR/ci/pipelines"
opt_data_dir: "$CI_TMP_DIR"
systemlink_path: "$CI_TMP_DIR/SOT"
vault_file: "$VAULT_FILE_PATH"
vault_secret: "$VAULT_SECRET_VALUE"
vault_content: "$ROOT_DIR/setup/vault_template.j2"
vault_mail: "$VAULT_MAIL_VALUE"
branch: "$BRANCH_NAME"
aat_enabled: "false"
tid_enabled: "false"
runner_enabled: "false"
EOF_CONFIG

# Ensure referenced artefacts exist so CLI commands succeed.
mkdir -p "$ROOT_DIR/ci/pipelines" "$(dirname "$LOG_FILE_PATH")"
: > "$LOG_FILE_PATH"
cat <<'VAULT' > "$VAULT_FILE_PATH"
---
api_key: dummy
VAULT
chmod 600 "$VAULT_FILE_PATH"

export CONFIG_FILE="$CONFIG_FILE_PATH"
export vault_file="$VAULT_FILE_PATH"
export vault_secret="$VAULT_SECRET_VALUE"
export opt_data_dir="$CI_TMP_DIR"
export clone_dir="$ROOT_DIR"
export log_file="$LOG_FILE_PATH"
export branch="$BRANCH_NAME"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "CONFIG_FILE=$CONFIG_FILE_PATH"
    echo "vault_file=$VAULT_FILE_PATH"
    echo "vault_secret=$VAULT_SECRET_VALUE"
    echo "opt_data_dir=$CI_TMP_DIR"
    echo "clone_dir=$ROOT_DIR"
    echo "log_file=$LOG_FILE_PATH"
    echo "branch=$BRANCH_NAME"
  } >> "$GITHUB_ENV"
fi
