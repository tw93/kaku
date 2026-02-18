# Shared shell state helpers for first-run and config updates.

read_config_version() {
	if [[ ! -f "$STATE_FILE" ]]; then
		printf '%s\n' "0"
		return
	fi

	local version
	version="$(sed -nE 's/.*"config_version"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$STATE_FILE" | head -n 1)"
	if [[ "$version" =~ ^[0-9]+$ ]]; then
		printf '%s\n' "$version"
	else
		printf '%s\n' "0"
	fi
}

persist_config_version() {
	local target_version="${1:-$CURRENT_CONFIG_VERSION}"
	mkdir -p "$CONFIG_DIR"

	local width height geometry_json
	width=""
	height=""
	geometry_json=""

	if [[ -f "$STATE_FILE" ]]; then
		width="$(sed -nE 's/.*"width"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$STATE_FILE" | head -n 1)"
		height="$(sed -nE 's/.*"height"[[:space:]]*:[[:space:]]*([0-9]+).*/\1/p' "$STATE_FILE" | head -n 1)"
	fi

	if [[ -z "$width" || -z "$height" ]] && [[ -f "$LEGACY_GEOMETRY_FILE" ]]; then
		local geometry
		geometry="$(tr -d '[:space:]' < "$LEGACY_GEOMETRY_FILE" || true)"
		local a b c d
		IFS=',' read -r a b c d <<< "$geometry"
		if [[ "${c:-}" =~ ^[0-9]+$ && "${d:-}" =~ ^[0-9]+$ ]]; then
			width="$c"
			height="$d"
		elif [[ "${a:-}" =~ ^[0-9]+$ && "${b:-}" =~ ^[0-9]+$ ]]; then
			width="$a"
			height="$b"
		fi
	fi

	if [[ -n "$width" && -n "$height" ]]; then
		geometry_json="$(printf ',\n  "window_geometry": {\n    "width": %s,\n    "height": %s\n  }' "$width" "$height")"
	fi

	printf "{\n  \"config_version\": %s%s\n}\n" "$target_version" "$geometry_json" >"$STATE_FILE"

	rm -f "$LEGACY_VERSION_FILE" "$LEGACY_GEOMETRY_FILE"
}

detect_login_shell() {
	if [[ -n "${SHELL:-}" && -x "${SHELL:-}" ]]; then
		printf '%s\n' "$SHELL"
		return
	fi

	local current_user resolved_shell passwd_entry
	current_user="${USER:-}"
	if [[ -z "$current_user" ]]; then
		current_user="$(id -un 2>/dev/null || true)"
	fi

	if [[ -n "$current_user" ]] && command -v dscl &>/dev/null; then
		resolved_shell="$(dscl . -read "/Users/$current_user" UserShell 2>/dev/null | awk '/UserShell:/ { print $2 }')"
		if [[ -n "$resolved_shell" && -x "$resolved_shell" ]]; then
			printf '%s\n' "$resolved_shell"
			return
		fi
	fi

	if [[ -n "$current_user" ]] && command -v getent &>/dev/null; then
		passwd_entry="$(getent passwd "$current_user" 2>/dev/null || true)"
		resolved_shell="${passwd_entry##*:}"
		if [[ -n "$resolved_shell" && -x "$resolved_shell" ]]; then
			printf '%s\n' "$resolved_shell"
			return
		fi
	fi

	if [[ -x "/bin/zsh" ]]; then
		printf '%s\n' "/bin/zsh"
	else
		printf '%s\n' "/bin/sh"
	fi
}
