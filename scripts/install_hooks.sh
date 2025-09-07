#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(git rev-parse --show-toplevel)
HOOK_DIR="$ROOT_DIR/.git/hooks"
SCRIPT="$ROOT_DIR/scripts/post_commit_sync.sh"

if [[ ! -x "$SCRIPT" ]]; then
  chmod +x "$SCRIPT"
fi

mkdir -p "$HOOK_DIR"
cat > "$HOOK_DIR/post-commit" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT=$(git rev-parse --show-toplevel)
"$REPO_ROOT/scripts/post_commit_sync.sh"
EOF
chmod +x "$HOOK_DIR/post-commit"

echo "Installed post-commit hook that syncs EPIC issues via gh."

