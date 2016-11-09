declare -r TMP_MAN_FOLDER="$bufferDir/web/man"
declare -ri MAX_CACHE_SIZE="$((10*1024*1024))"
declare -r MAN_REGEX='^[a-zA-Z0-9_-]+$'
declare -r MAN_SECTION_REGEX='^[0-9]/[a-zA-Z0-9_-]+$'

serveMan() {
  local file="${3#/man/}"

  local section
    
  if [[ "$file" =~ $MAN_SECTION_REGEX ]]; then
    section="${file:0:1}"
    file="${file:2}"
  elif [[ ! "$file" =~ $MAN_REGEX ]]; then
    return 1
  fi

  mkdir -p "$TMP_MAN_FOLDER" &>/dev/null

  local manFile="$(man -M "$botShare/man/" -w "$file")"
  local hashName="$(md5sum <<< "$manFile" | head -c 10)"
  local cacheFile="$TMP_MAN_FOLDER/$hashName"

  local -i cachedTime=0
  if [[ -f "$cacheFile" ]]; then
    cacheTime="$(stat -c %Y "$cacheFile")"
  fi
  local -i changeTime="$(stat -c %Y "$manFile")"

  if ((cachedTime == 0 || cachedTime > changeTime )); then
    trimCache "$TMP_MAN_FOLDER" "$MAX_CACHE_SIZE"

    if [[ -n "$section" ]]; then
      MANWIDTH=80 man -M "$botShare/man/" "$section" "$file" > "$cacheFile"
    else
      MANWIDTH=80 man -M "$botShare/man/" "$file" > "$cacheFile"
    fi
  fi

  serveFile "$TMP_MAN_FOLDER" "$hashName"
  return $?
}
