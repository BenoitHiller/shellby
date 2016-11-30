declare -r PASTE_REGEX='^[a-f0-9]+$'
declare -r PASTE_DIR="$bufferDir/web/paste"

servePastes() {
  local file="${3#/paste/}"

  if [[ "$file" =~ $PASTE_REGEX ]]; then
    local -r target="$(find "$PASTE_DIR" -type f -print0 | grep -Fzx -m 1 "$PASTE_DIR/$file")"
    if [[ -n "$target" && -f "$target" ]]; then
      render "$botLib/web/paste.html" <"$target" | sendResponsePipe 200
      return 0
    fi
  fi
  return 1
}
