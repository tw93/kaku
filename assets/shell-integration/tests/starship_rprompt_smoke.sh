#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/kaku-starship-rprompt.XXXXXX")"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$tmp_dir/bin"
cat >"$tmp_dir/bin/starship" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
init)
  if [[ "${2:-}" != "zsh" ]]; then
    exit 1
  fi
  cat <<'OUT'
RPROMPT='$(echo fake-right-prompt)'
OUT
  ;;
prompt)
  if [[ "${2:-}" != "--right" ]]; then
    exit 1
  fi
  echo "fake-right-prompt"
  ;;
*)
  exit 1
  ;;
esac
EOF
chmod +x "$tmp_dir/bin/starship"

HOME="$tmp_dir/home"
ZDOTDIR="$HOME"
mkdir -p "$HOME"

PATH="$tmp_dir/bin:$PATH" \
HOME="$HOME" \
ZDOTDIR="$ZDOTDIR" \
KAKU_INIT_INTERNAL=1 \
KAKU_SKIP_TOOL_BOOTSTRAP=1 \
KAKU_SKIP_TERMINFO_BOOTSTRAP=1 \
bash "$REPO_ROOT/assets/shell-integration/setup_zsh.sh" --update-only >/dev/null

TERM=xterm-256color \
PATH="$tmp_dir/bin:$PATH" \
HOME="$HOME" \
ZDOTDIR="$ZDOTDIR" \
output="$(
zsh -f -c '
source "$HOME/.config/kaku/zsh/kaku.zsh"
RPROMPT='\''$(starship prompt --right)'\''
_kaku_fix_starship_rprompt
print -r -- "__KAKU_RPROMPT__:$RPROMPT"
' 2>&1
)"

case "$output" in
  *__KAKU_RPROMPT__:* ) ;;
  * )
    echo "$output" >&2
    exit 1
    ;;
esac

case "$output" in
  *"closing brace expected"* | *"bad pattern"* )
    echo "$output" >&2
    exit 1
    ;;
esac

echo "starship_rprompt smoke test passed"
