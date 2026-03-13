#!/bin/bash
# Kaku Fish Setup Script
# This script configures a Fish environment using Kaku resources.
# It is designed to be safe: it backs up existing configurations and can be re-run.

set -euo pipefail

UPDATE_ONLY=false
for arg in "$@"; do
	case "$arg" in
	--update-only)
		UPDATE_ONLY=true
		;;
	esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${KAKU_INIT_INTERNAL:-0}" != "1" ]]; then
	if [[ -n "${KAKU_BIN:-}" && -x "${KAKU_BIN}" ]]; then
		exec "${KAKU_BIN}" init "$@"
	fi

	for candidate in \
		"$SCRIPT_DIR/../MacOS/kaku" \
		"/Applications/Kaku.app/Contents/MacOS/kaku" \
		"$HOME/Applications/Kaku.app/Contents/MacOS/kaku"; do
		if [[ -x "$candidate" ]]; then
			exec "$candidate" init "$@"
		fi
	done
fi

if [[ -d "$SCRIPT_DIR/vendor" ]]; then
	RESOURCES_DIR="$SCRIPT_DIR"
elif [[ -d "$SCRIPT_DIR/../vendor" ]]; then
	RESOURCES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [[ -d "/Applications/Kaku.app/Contents/Resources/vendor" ]]; then
	RESOURCES_DIR="/Applications/Kaku.app/Contents/Resources"
elif [[ -d "$HOME/Applications/Kaku.app/Contents/Resources/vendor" ]]; then
	RESOURCES_DIR="$HOME/Applications/Kaku.app/Contents/Resources"
else
	echo -e "${YELLOW}Error: Could not locate Kaku resources (vendor directory missing).${NC}"
	exit 1
fi

VENDOR_DIR="$RESOURCES_DIR/vendor"
if [[ -n "${KAKU_VENDOR_DIR:-}" && -d "${KAKU_VENDOR_DIR}" ]]; then
	VENDOR_DIR="${KAKU_VENDOR_DIR}"
fi

KAKU_TARGET_SHELL="${KAKU_TARGET_SHELL:-fish}"

USER_CONFIG_DIR="$HOME/.config/kaku/fish"
KAKU_FISH_FILE="$USER_CONFIG_DIR/kaku.fish"
FISH_CONFIG_DIR="$HOME/.config/fish"
FISH_CONFIG_FILE="$FISH_CONFIG_DIR/config.fish"
KAKU_TMUX_DIR="$HOME/.config/kaku/tmux"
KAKU_TMUX_FILE="$KAKU_TMUX_DIR/kaku.tmux.conf"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
YAZI_CONFIG_DIR="$HOME/.config/yazi"
YAZI_CONFIG_FILE="$YAZI_CONFIG_DIR/yazi.toml"
YAZI_KEYMAP_FILE="$YAZI_CONFIG_DIR/keymap.toml"
YAZI_THEME_FILE="$YAZI_CONFIG_DIR/theme.toml"
YAZI_FLAVORS_DIR="$YAZI_CONFIG_DIR/flavors"
YAZI_WRAPPER_FILE="$USER_CONFIG_DIR/bin/yazi"
YAZI_YAZI_THEME_MARKER_START="# ===== Kaku Yazi Flavor (managed) ====="
YAZI_YAZI_THEME_MARKER_END="# ===== End Kaku Yazi Flavor (managed) ====="
TOOL_INSTALL_SCRIPT="$SCRIPT_DIR/install_cli_tools.sh"
if [[ ! -f "$TOOL_INSTALL_SCRIPT" ]]; then
	TOOL_INSTALL_SCRIPT="$RESOURCES_DIR/install_cli_tools.sh"
fi
if [[ -d "$SCRIPT_DIR/yazi-flavors" ]]; then
	KAKU_YAZI_FLAVOR_SOURCE_DIR="$SCRIPT_DIR/yazi-flavors"
else
	KAKU_YAZI_FLAVOR_SOURCE_DIR="$RESOURCES_DIR/yazi-flavors"
fi
YAZI_KEYMAP_DEFAULTS=(
	'  { on = "e", run = "open", desc = "Edit or open selected files" },'
	'  { on = "o", run = "open", desc = "Edit or open selected files" },'
	'  { on = "<Enter>", run = "enter", desc = "Enter the child directory" },'
)

KAKU_FISH_SOURCE_LINE='if test -f "$HOME/.config/kaku/fish/kaku.fish"; . "$HOME/.config/kaku/fish/kaku.fish"; end # Kaku Fish Integration'
BACKUP_SUFFIX=".kaku-backup-$(date +%s)"
FISH_CONFIG_BACKED_UP=0

ensure_dirs() {
	mkdir -p "$USER_CONFIG_DIR"
	mkdir -p "$USER_CONFIG_DIR/bin"
	mkdir -p "$KAKU_TMUX_DIR"
	mkdir -p "$FISH_CONFIG_DIR"
	mkdir -p "$YAZI_CONFIG_DIR"
}

backup_config_once() {
	if [[ -f "$FISH_CONFIG_FILE" ]] && [[ "$FISH_CONFIG_BACKED_UP" -eq 0 ]]; then
		cp "$FISH_CONFIG_FILE" "${FISH_CONFIG_FILE}${BACKUP_SUFFIX}"
		FISH_CONFIG_BACKED_UP=1
	fi
}

write_fish_integration_file() {
	cat <<'EOF' >"$KAKU_FISH_FILE"
# Kaku Fish Integration
set -gx KAKU_FISH_DIR "$HOME/.config/kaku/fish"
set -gx KAKU_SHELL fish
set -gx KAKU_SHELL_INTEGRATION_ACTIVE 1
set -gx KAKU_TERM "kaku"
set -gx CLICOLOR 1
set -gx LSCOLORS "gxfxcxdxbxegedabagacad"

set -l _kaku_bin_dir "$KAKU_FISH_DIR/bin"
if not contains -- "$_kaku_bin_dir" $PATH
	set -gx PATH "$_kaku_bin_dir" $PATH
end

if command -q starship; and status --is-interactive
	starship init fish | source
end

bind ctrl-r history-search-backward
bind ctrl-s history-search-forward

bind -M insert ctrl-r history-search-backward
bind -M insert ctrl-s history-search-forward
bind -M default up history-search-backward
bind -M default down history-search-forward
EOF
}

normalize_fish_config_line() {
	backup_config_once

	local tmp
	tmp="$(mktemp "${TMPDIR:-/tmp}/kaku-fish-config.XXXXXX")"

	if [[ ! -f "$FISH_CONFIG_FILE" ]]; then
		touch "$FISH_CONFIG_FILE"
	fi

	grep -vF "# Kaku Fish Integration" "$FISH_CONFIG_FILE" >"$tmp" || true

	if ! grep -qF "# Kaku Fish Integration" "$tmp"; then
		if [[ -s "$tmp" ]] && [[ -n "$(tail -c 1 "$tmp" || true)" ]]; then
			echo >>"$tmp"
		fi
	fi
	echo "$KAKU_FISH_SOURCE_LINE" >>"$tmp"

	mv "$tmp" "$FISH_CONFIG_FILE"
}

ensure_tmux_integration() {
	mkdir -p "$KAKU_TMUX_DIR"
	cat <<'EOF' >"$KAKU_TMUX_FILE"
# Kaku tmux Integration - DO NOT EDIT MANUALLY
# This file is managed by Kaku.app. Any changes may be overwritten.

set -g mouse on
bind-key -n S-WheelUpPane if-shell -F '#{pane_in_mode}' 'send-keys -X -N 5 scroll-up' 'copy-mode -e -u'
bind-key -n S-WheelDownPane if-shell -F '#{pane_in_mode}' 'send-keys -X -N 5 scroll-down' ''
EOF
}

default_kaku_config_path() {
	if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
		printf '%s\n' "${XDG_CONFIG_HOME}/kaku/kaku.lua"
	else
		printf '%s\n' "${HOME}/.config/kaku/kaku.lua"
	fi
}

active_kaku_config_path() {
	if [[ -n "${KAKU_CONFIG_FILE:-}" ]]; then
		printf '%s\n' "${KAKU_CONFIG_FILE}"
	else
		default_kaku_config_path
	fi
}

system_kaku_flavor() {
	local flavor="kaku-dark"
	if command -v defaults >/dev/null 2>&1; then
		local appearance
		appearance="$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)"
		if [[ "$appearance" != "Dark" ]]; then
			flavor="kaku-light"
		fi
	fi
	printf '%s\n' "$flavor"
}

resolve_kaku_flavor_from_config() {
	local config_file="$1"
	local system_flavor
	system_flavor="$(system_kaku_flavor)"

	if [[ -f "$config_file" ]]; then
		local scheme_line
		scheme_line="$(
			awk '
				/^[[:space:]]*--/ { next }
				/^[[:space:]]*config\.color_scheme[[:space:]]*=/ { print; exit }
			' "$config_file"
		)"
		if [[ -n "$scheme_line" ]]; then
			if [[ "$scheme_line" == *"Kaku Light"* ]]; then
				printf '%s\n' "kaku-light"
				return
			fi
			if [[ "$scheme_line" == *"Kaku Dark"* || "$scheme_line" == *"Kaku Theme"* ]]; then
				printf '%s\n' "kaku-dark"
				return
			fi
			if [[ "$scheme_line" == *"'Auto'"* || "$scheme_line" == *'"Auto"'* ]]; then
				printf '%s\n' "$system_flavor"
				return
			fi
			if [[ "$scheme_line" == *get_appearance* ]]; then
				printf '%s\n' "$system_flavor"
				return
			fi
			printf '%s\n' "kaku-dark"
			return
		fi
	fi

	printf '%s\n' "kaku-dark"
}

current_kaku_yazi_flavor() {
	resolve_kaku_flavor_from_config "$(active_kaku_config_path)"
}

is_legacy_kaku_yazi_theme_file() {
	if [[ ! -f "$YAZI_THEME_FILE" ]]; then
		return 1
	fi

	if grep -Fq '# Kaku-aligned theme for Yazi 26.x' "$YAZI_THEME_FILE"; then
		return 0
	fi
	local normalized expected
	normalized="$(sed -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$YAZI_THEME_FILE")"
	expected=$'[mgr]\nborder_symbol = "│"\nborder_style = { fg = "#555555" }\n[indicator]\npadding = { open = "", close = "" }'
	[[ "$normalized" == "$expected" ]]
}

kaku_yazi_theme_block() {
	local flavor="${1:-$(current_kaku_yazi_flavor)}"
	cat <<EOF
$YAZI_YAZI_THEME_MARKER_START
[flavor]
dark = "$flavor"
light = "$flavor"
$YAZI_YAZI_THEME_MARKER_END
EOF
}

ensure_kaku_yazi_theme() {
	local managed_flavor
	managed_flavor="$(current_kaku_yazi_flavor)"
	if [[ ! -f "$YAZI_THEME_FILE" ]] || is_legacy_kaku_yazi_theme_file; then
		cat <<EOF >"$YAZI_THEME_FILE"
"\$schema" = "https://yazi-rs.github.io/schemas/theme.json"

# Kaku manages the [flavor] section below so Yazi matches the current Kaku theme.
# Add your own theme overrides in other sections if needed.
$(kaku_yazi_theme_block "$managed_flavor")
EOF
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Initialized yazi theme ${NC}(managed Kaku flavor: $managed_flavor)${NC}"
		return
	fi

	if grep -Eq '^[[:space:]]*\[flavor\][[:space:]]*$' "$YAZI_THEME_FILE" && ! grep -Fq "$YAZI_YAZI_THEME_MARKER_START" "$YAZI_THEME_FILE"; then
		echo -e "  ${BLUE}•${NC} ${BOLD}Config${NC}      Preserved existing yazi [flavor] section${NC}"
		return
	fi

	local tmp_theme
	tmp_theme="$(mktemp "${TMPDIR:-/tmp}/kaku-yazi-theme.XXXXXX")"

	awk -v start="$YAZI_YAZI_THEME_MARKER_START" -v end="$YAZI_YAZI_THEME_MARKER_END" '
		index($0, start) { skip = 1; next }
		index($0, end) { skip = 0; next }
		!skip { print }
	' "$YAZI_THEME_FILE" >"$tmp_theme"

	{
		cat "$tmp_theme"
		printf '\n'
		kaku_yazi_theme_block "$managed_flavor"
		printf '\n'
	} >"${tmp_theme}.next"

	mv "${tmp_theme}.next" "$YAZI_THEME_FILE"
	rm -f "$tmp_theme"
	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Updated yazi theme ${NC}(managed Kaku flavor: $managed_flavor)${NC}"
}

sync_kaku_yazi_flavors() {
	if [[ ! -d "$KAKU_YAZI_FLAVOR_SOURCE_DIR" ]]; then
		echo -e "${YELLOW}Warning: bundled Yazi flavors are missing at $KAKU_YAZI_FLAVOR_SOURCE_DIR.${NC}"
		return
	fi

	mkdir -p "$YAZI_FLAVORS_DIR"
	local flavor source_dir target_dir
	for flavor in kaku-dark.yazi kaku-light.yazi; do
		source_dir="$KAKU_YAZI_FLAVOR_SOURCE_DIR/$flavor"
		target_dir="$YAZI_FLAVORS_DIR/$flavor"
		if [[ ! -d "$source_dir" ]]; then
			echo -e "${YELLOW}Warning: missing bundled Yazi flavor $source_dir.${NC}"
			continue
		fi

		if [[ ! -f "$source_dir/flavor.toml" ]]; then
			echo -e "${YELLOW}Warning: flavor.toml missing in $source_dir.${NC}"
			continue
		fi

		mkdir -p "$target_dir"
		cp "$source_dir/flavor.toml" "$target_dir/flavor.toml"
	done

	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Refreshed Kaku yazi flavors ${NC}(dark + light)${NC}"
}

install_yazi_wrapper() {
	cat <<'EOF' >"$YAZI_WRAPPER_FILE"
#!/bin/bash
set -euo pipefail

YAZI_THEME_FILE="${HOME}/.config/yazi/theme.toml"
MARKER_START="# ===== Kaku Yazi Flavor (managed) ====="
MARKER_END="# ===== End Kaku Yazi Flavor (managed) ====="
WRAPPER_PATH="${BASH_SOURCE[0]}"
WRAPPER_DIR="$(cd "$(dirname "$WRAPPER_PATH")" && pwd)"

system_kaku_flavor() {
	local flavor="kaku-dark"
	if command -v defaults >/dev/null 2>&1; then
		local appearance
		appearance="$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)"
		if [[ "$appearance" != "Dark" ]]; then
			flavor="kaku-light"
		fi
	fi
	printf '%s\n' "$flavor"
}

default_kaku_config_path() {
	if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
		printf '%s\n' "${XDG_CONFIG_HOME}/kaku/kaku.lua"
	else
		printf '%s\n' "${HOME}/.config/kaku/kaku.lua"
	fi
}

active_kaku_config_path() {
	if [[ -n "${KAKU_CONFIG_FILE:-}" ]]; then
		printf '%s\n' "${KAKU_CONFIG_FILE}"
	else
		default_kaku_config_path
	fi
}

resolve_kaku_flavor_from_config() {
	local config_file="$1"
	local system_flavor
	system_flavor="$(system_kaku_flavor)"

	if [[ -f "$config_file" ]]; then
		local scheme_line
		scheme_line="$(
			awk '
				/^[[:space:]]*--/ { next }
				/^[[:space:]]*config\.color_scheme[[:space:]]*=/ { print; exit }
			' "$config_file"
		)"
		if [[ -n "$scheme_line" ]]; then
			if [[ "$scheme_line" == *"Kaku Light"* ]]; then
				printf '%s\n' "kaku-light"
				return
			fi
			if [[ "$scheme_line" == *"Kaku Dark"* || "$scheme_line" == *"Kaku Theme"* ]]; then
				printf '%s\n' "kaku-dark"
				return
			fi
			if [[ "$scheme_line" == *"'Auto'"* || "$scheme_line" == *'"Auto"'* ]]; then
				printf '%s\n' "$system_flavor"
				return
			fi
			if [[ "$scheme_line" == *get_appearance* ]]; then
				printf '%s\n' "$system_flavor"
				return
			fi
			printf '%s\n' "kaku-dark"
			return
		fi
	fi

	printf '%s\n' "kaku-dark"
}

current_flavor() {
	resolve_kaku_flavor_from_config "$(active_kaku_config_path)"
}

managed_block() {
	local flavor="$1"
	cat <<BLOCK
$MARKER_START
[flavor]
dark = "$flavor"
light = "$flavor"
$MARKER_END
BLOCK
}

ensure_theme() {
	local flavor="$1"
	mkdir -p "$(dirname "$YAZI_THEME_FILE")"

	if [[ ! -f "$YAZI_THEME_FILE" ]]; then
		cat <<BLOCK >"$YAZI_THEME_FILE"
"\$schema" = "https://yazi-rs.github.io/schemas/theme.json"

# Kaku manages the [flavor] section below so Yazi matches the current Kaku theme.
$(managed_block "$flavor")
BLOCK
		return
	fi

	if grep -Eq '^[[:space:]]*\[flavor\][[:space:]]*$' "$YAZI_THEME_FILE" && ! grep -Fq "$MARKER_START" "$YAZI_THEME_FILE"; then
		return
	fi

	local tmp_theme
	tmp_theme="$(mktemp "${TMPDIR:-/tmp}/kaku-yazi-wrapper.XXXXXX")"
	awk -v start="$MARKER_START" -v end="$MARKER_END" '
		index($0, start) { skip = 1; next }
		index($0, end)   { skip = 0; next }
		!skip { print }
	' "$YAZI_THEME_FILE" >"$tmp_theme"

	{
		cat "$tmp_theme"
		printf '\n'
		managed_block "$flavor"
		printf '\n'
	} >"${tmp_theme}.next"

	mv "${tmp_theme}.next" "$YAZI_THEME_FILE"
	rm -f "$tmp_theme"
}

resolve_real_yazi() {
	local candidate
	for candidate in /opt/homebrew/bin/yazi /usr/local/bin/yazi; do
		if [[ -x "$candidate" && "$candidate" != "$WRAPPER_PATH" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	local path_entry
	IFS=':' read -r -a path_entries <<< "${PATH:-}"
	for path_entry in "${path_entries[@]}"; do
		[[ -z "$path_entry" || "$path_entry" == "$WRAPPER_DIR" ]] && continue
		candidate="$path_entry/yazi"
		if [[ -x "$candidate" && "$candidate" != "$WRAPPER_PATH" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done

	return 1
}

main() {
	local flavor real_bin
	flavor="$(current_flavor)"
	ensure_theme "$flavor"

	if ! real_bin="$(resolve_real_yazi)"; then
		echo "yazi not found. Install it with: brew install yazi" >&2
		exit 127
	fi

	exec "$real_bin" "$@"
}

main "$@"
EOF
	chmod +x "$YAZI_WRAPPER_FILE"
	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Installed yazi wrapper ${NC}(theme sync before launch)${NC}"
}

ensure_yazi_base_config() {
	if [[ -f "$YAZI_CONFIG_FILE" ]]; then
		return
	fi

	cat <<EOF >"$YAZI_CONFIG_FILE"
[mgr]
ratio = [3, 3, 10]

[preview]
max_width = 2000
max_height = 2400

[opener]
edit = [
  { run = "\${EDITOR:-vim} %s", desc = "edit", for = "unix", block = true },
]
EOF
	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Initialized yazi.toml ${NC}(~/.config/yazi/yazi.toml)${NC}"
}

ensure_yazi_preview_size_defaults() {
	if [[ ! -f "$YAZI_CONFIG_FILE" ]]; then
		return
	fi

	local preview_block
	preview_block="$(awk '
		BEGIN { in_preview = 0 }
		/^[[:space:]]*\[preview\][[:space:]]*$/ { in_preview = 1; next }
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ { in_preview = 0 }
		in_preview { print }
	' "$YAZI_CONFIG_FILE")"

	local has_preview_section=false
	local has_max_width=false
	local has_max_height=false

	if grep -Eq '^[[:space:]]*\[preview\][[:space:]]*$' "$YAZI_CONFIG_FILE"; then
		has_preview_section=true
	fi
	if grep -Eq '^[[:space:]]*max_width[[:space:]]*=' <<<"$preview_block"; then
		has_max_width=true
	fi
	if grep -Eq '^[[:space:]]*max_height[[:space:]]*=' <<<"$preview_block"; then
		has_max_height=true
	fi

	if [[ "$has_preview_section" == "false" ]]; then
		cat <<EOF >>"$YAZI_CONFIG_FILE"

[preview]
max_width = 2000
max_height = 2400
EOF
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Added default Yazi preview size ${NC}(2000x2400)${NC}"
		return
	fi

	if [[ "$has_max_width" == "true" ]] && [[ "$has_max_height" == "true" ]]; then
		return
	fi

	local tmp_yazi
	tmp_yazi="$(mktemp "${TMPDIR:-/tmp}/kaku-yazi-preview.XXXXXX")"
	awk -v need_width="$has_max_width" -v need_height="$has_max_height" '
		/^[[:space:]]*\[preview\][[:space:]]*$/ {
			print
			if (need_width != "true") {
				print "max_width = 2000"
			}
			if (need_height != "true") {
				print "max_height = 2400"
			}
			next
		}
		{ print }
	' "$YAZI_CONFIG_FILE" >"$tmp_yazi"
	mv "$tmp_yazi" "$YAZI_CONFIG_FILE"
	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Completed Yazi preview size defaults ${NC}(2000x2400)${NC}"
}

ensure_yazi_edit_opener() {
	if [[ ! -f "$YAZI_CONFIG_FILE" ]]; then
		return
	fi

	if grep -Eq '^[[:space:]]*edit[[:space:]]*=' "$YAZI_CONFIG_FILE"; then
		return
	fi

	if grep -Eq '^[[:space:]]*\[opener\][[:space:]]*$' "$YAZI_CONFIG_FILE"; then
		local tmp_yazi
		tmp_yazi="$(mktemp "${TMPDIR:-/tmp}/kaku-yazi-edit.XXXXXX")"
		awk '/^[[:space:]]*\[opener\][[:space:]]*$/ {
			print
			print "edit = ["
			print "  { run = \"${EDITOR:-vim} %s\", desc = \"edit\", for = \"unix\", block = true },"
			print "]"
			next
		}
		{ print }' "$YAZI_CONFIG_FILE" >"$tmp_yazi"
		mv "$tmp_yazi" "$YAZI_CONFIG_FILE"
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Added default Yazi edit opener under existing [opener] section"
		return
	fi

	cat <<EOF >>"$YAZI_CONFIG_FILE"

[opener]
edit = [
  { run = "\${EDITOR:-vim} %s", desc = "edit", for = "unix", block = true },
]
EOF
	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Added default Yazi edit opener ${NC}(vim)${NC}"
}

ensure_yazi_keymap() {
	if [[ -f "$YAZI_KEYMAP_FILE" ]]; then
		return
	fi

	cat <<EOF >"$YAZI_KEYMAP_FILE"
"\$schema" = "https://yazi-rs.github.io/schemas/keymap.json"

[mgr]
prepend_keymap = [
$(printf '%s\n' "${YAZI_KEYMAP_DEFAULTS[@]}")
]
EOF
	echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Initialized yazi keymap ${NC}(~/.config/yazi/keymap.toml)${NC}"
}

install_kaku_terminfo() {
	if [[ "${KAKU_SKIP_TERMINFO_BOOTSTRAP:-0}" == "1" ]]; then
		return
	fi

	if infocmp kaku >/dev/null 2>&1; then
		return
	fi

	local target_dir="$HOME/.terminfo"
	local compiled_entry="$RESOURCES_DIR/terminfo/6b/kaku"
	local source_entry=""

	if [[ -f "$compiled_entry" ]]; then
		if mkdir -p "$target_dir/6b" 2>/dev/null && cp "$compiled_entry" "$target_dir/6b/kaku" 2>/dev/null; then
			if infocmp kaku >/dev/null 2>&1; then
				echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Installed kaku terminfo ${NC}(~/.terminfo)${NC}"
				return
			fi
		else
			echo -e "${YELLOW}Warning: could not copy compiled terminfo entry to ~/.terminfo, continuing.${NC}"
		fi
	fi

	for candidate in \
		"$RESOURCES_DIR/../termwiz/data/kaku.terminfo" \
		"$SCRIPT_DIR/../../termwiz/data/kaku.terminfo"; do
		if [[ -f "$candidate" ]]; then
			source_entry="$candidate"
			break
		fi
	done

	if [[ -n "$source_entry" ]]; then
		if ! command -v tic >/dev/null 2>&1; then
			echo -e "${YELLOW}Warning: tic not found, skipping kaku terminfo installation.${NC}"
			return
		fi

		mkdir -p "$target_dir"
		if tic -x -o "$target_dir" "$source_entry" >/dev/null 2>&1 && infocmp kaku >/dev/null 2>&1; then
			echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Installed kaku terminfo ${NC}(~/.terminfo)${NC}"
			return
		fi
	fi

	echo -e "${YELLOW}Warning: failed to install kaku terminfo automatically.${NC}"
}

ensure_starship_config() {
	if [[ -f "$STARSHIP_CONFIG" ]]; then
		return
	fi

	if [[ -f "$VENDOR_DIR/starship.toml" ]]; then
		mkdir -p "$(dirname "$STARSHIP_CONFIG")"
		cp "$VENDOR_DIR/starship.toml" "$STARSHIP_CONFIG"
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Initialized starship.toml ${NC}(~/.config/starship.toml)${NC}"
		return
	fi

	if [[ -n "${KAKU_VENDOR_DIR:-}" && -f "$KAKU_VENDOR_DIR/starship.toml" ]]; then
		mkdir -p "$(dirname "$STARSHIP_CONFIG")"
		cp "$KAKU_VENDOR_DIR/starship.toml" "$STARSHIP_CONFIG"
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Initialized starship.toml ${NC}(~/.config/starship.toml)${NC}"
	fi
}

ensure_dirs

if [[ ! -f "$KAKU_FISH_FILE" || "$UPDATE_ONLY" == "true" ]]; then
	write_fish_integration_file
	if grep -qF "# Kaku Fish Integration" "$KAKU_FISH_FILE"; then
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Refreshed Kaku fish integration file"
	else
		echo -e "  ${GREEN}✓${NC} ${BOLD}Config${NC}      Wrote Kaku fish integration file"
	fi
fi

normalize_fish_config_line
ensure_tmux_integration
install_kaku_terminfo
ensure_starship_config
ensure_yazi_base_config
ensure_yazi_preview_size_defaults
ensure_yazi_edit_opener
ensure_yazi_keymap
sync_kaku_yazi_flavors
ensure_kaku_yazi_theme
install_yazi_wrapper

if [[ -n "${KAKU_SKIP_TOOL_BOOTSTRAP:-}" ]]; then
	echo -e "${BLUE}Info:${NC} Tool bootstrap skipped by KAKU_SKIP_TOOL_BOOTSTRAP"
	exit 0
fi

if [[ -f "$TOOL_INSTALL_SCRIPT" ]]; then
	export KAKU_TARGET_SHELL="fish"
	if ! bash "$TOOL_INSTALL_SCRIPT"; then
		echo -e "${YELLOW}Warning: optional tool installation failed.${NC}"
	fi
else
	echo -e "${YELLOW}Info: install_cli_tools.sh not found, skipped.${NC}"
fi

echo -e "  ${GREEN}✓${NC} ${BOLD}Done${NC}      Kaku fish integration applied"
