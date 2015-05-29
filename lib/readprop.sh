#!/bin/bash
#
# This library enables you to read a roughly standard properties file into an
# associative array.
#
# It stores the properties into a global properties array. Sorry.
#
# It will more or less preserve the comments and spacing of the original file,
# though it will strip out leading space.

set -f

declare -r TRAILING_SLASH='\$'
declare -r COMMENT='^!#'
declare -r NEWLINE=$'\n'
declare -A properties=()
declare -A beforeProperty=()
declare -i lastChange=0

# read all of the properties in a file
#
# 1.propertyFile the file to read from
readProperties() {
  local -r propertyFile="$1"

  lastChange="$(stat --printf %Y "$propertyFile")"


  local line
  local filler
  local continuation
  local innerBreak=false 

  local propertyName
  local propertyValue

  if [[ -s "$propertyFile" ]]; then
    shopt -q extglob
    local -i extGlob="$?"
    shopt -s extglob

    while ! "$innerBreak" && IFS= read -r line; do
      line="${line##*([[:space:]])}"
      if [[ -n "$line" && "$line" =~ [=:] && ! "$line" =~ $COMMENT ]]; then
        while ! "$innerBreak" && [[ "$line" =~ $TRAILING_SLASH ]]; do
          IFS= read -r continuation
          if (( $? != 0 )); then
            innerBreak=true
          else
            line+="${continuation##*([[:space:]])}"
          fi
        done
        propertyName="${line%%*([[:space:]])[=:]*}"
        propertyValue="${line##+([^=:])*([[:space:]])[=:]*([[:space:]])}"
        properties["$propertyName"]="$propertyValue"
        beforeProperty["$propertyName"]="$filler"
        filler=
      else
        filler+="$line$NEWLINE"
      fi
    done < "$propertyFile"
    beforeProperty["$NEWLINE"]="$filler"

    if (( extGlob == 1 )); then
      shopt -u extglob
    fi
  else
    return 1
  fi
}

# Write the properties array back to the file.
#
# 1.propertyFile the properties file to write to
writeProperties() {
  local -r propertyFile="$1"

  {
    for key in "${!properties[@]}"; do
      printf "%s" "${beforeProperty[$key]}"
      printf "%s\n" "$key = ${properties[$key]}"
    done
    printf "%s" "${beforeProperty["$NEWLINE"]}"
  } > "$propertyFile"

  printf -v lastChange "%(%s)T"
}

# Read the properties file only if the file has changed
#
# 1.propertyFile the file to read from
updatePropertyCache() {
  local -r propertyFile="$1"

  if [[ -f "$propertyFile" ]]; then
    local lastModified="$(stat --printf %Y "$propertyFile")"
    if ((lastChange < lastModified)); then
      readProperties "$propertyFile" 
    fi
  fi
}

# Set a single property without clobbering other changes
#
# So if the file has changed it will read back the properties before writing to
# the file.
#
# 1.propertyName the property to set
# 2.propertyValue the desired value
# 3.propertyFile the properties file to write to
setProperty() {
  local -r propertyName="$1"
  local -r propertyValue="$2"
  local -r propertyFile="$3"

  updatePropertyCache "$propertyFile"

  properties["$propertyName"]="$propertyValue"
  writeProperties "$propertyFile"
}
