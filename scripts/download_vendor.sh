#!/usr/bin/env bash
set -euo pipefail

# This script downloads plugin dependencies bundled into the Kaku App.
# CLI tools (starship/git-delta/lazygit) are installed via Homebrew at init time.

VENDOR_DIR="$(cd "$(dirname "$0")/../assets/vendor" && pwd)"
mkdir -p "$VENDOR_DIR"

echo "[0/4] Cleaning legacy vendor binaries..."
rm -f "$VENDOR_DIR/starship" "$VENDOR_DIR/delta" "$VENDOR_DIR/zoxide"
rm -rf "$VENDOR_DIR/completions" "$VENDOR_DIR/man"
rm -f "$VENDOR_DIR/README.md" "$VENDOR_DIR/CHANGELOG.md" "$VENDOR_DIR/LICENSE"

echo "[1/4] Cloning zsh-autosuggestions..."
AUTOSUGGEST_DIR="$VENDOR_DIR/zsh-autosuggestions"
if [[ ! -d "$AUTOSUGGEST_DIR" ]]; then
	git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$AUTOSUGGEST_DIR"
	rm -rf "$AUTOSUGGEST_DIR/.git"
else
	echo "zsh-autosuggestions already exists, skipping."
fi

echo "[2/4] Cloning zsh-syntax-highlighting..."
SYNTAX_DIR="$VENDOR_DIR/zsh-syntax-highlighting"
if [[ ! -d "$SYNTAX_DIR" ]]; then
	git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_DIR"
	rm -rf "$SYNTAX_DIR/.git"
else
	echo "zsh-syntax-highlighting already exists, skipping."
fi

echo "[3/4] Cloning zsh-completions..."
ZSH_COMPLETIONS_DIR="$VENDOR_DIR/zsh-completions"
if [[ ! -d "$ZSH_COMPLETIONS_DIR" ]]; then
	git clone --depth 1 https://github.com/zsh-users/zsh-completions.git "$ZSH_COMPLETIONS_DIR"
	rm -rf "$ZSH_COMPLETIONS_DIR/.git"
else
	echo "zsh-completions already exists, skipping."
fi

echo "[4/4] Cloning zsh-z..."
ZSH_Z_DIR="$VENDOR_DIR/zsh-z"
if [[ ! -d "$ZSH_Z_DIR" ]]; then
	git clone --depth 1 https://github.com/agkozak/zsh-z "$ZSH_Z_DIR"
	rm -rf "$ZSH_Z_DIR/.git"
else
	echo "zsh-z already exists, skipping."
fi

echo "Vendor dependencies downloaded to $VENDOR_DIR"
