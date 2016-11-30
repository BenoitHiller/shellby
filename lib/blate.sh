#!/bin/bash

e() {
  local -r joined="$@"
  printf "%s" "$joined"
}

p() {
  printf "$@"
}

# split the template file
#
# separates the file into alternating segments of not code, then code
#
# 1.file the file to split
split() {
  local -r file="$1"
  
  awk '
    BEGIN {
      RS="{{|}}"
      last=""
    }
    {
      if ((RT == "{{" && $0 ~ /^{/) || (RT == "}}" && $0 ~ /^}/) ) {
        last += $0;
      } else {
        if (NR > 1) {
          printf("%s\0", last);
        }
        last = $0
      }
    }
    END {
      printf("%s\0", last);
    }
  ' "$file"
}

# evaluate the output of split
#
# evaluates every second line and echos the rest
evaluate() {
  local raw=true
  while read -r -d $'\0' line; do
    if $raw; then
      raw=false
      printf '%s' "$line"
    else
      raw=true
      if [[ -n "$line" ]]; then
        eval "$line" <&3
      fi
    fi
  done
}

compile() {
  local raw=true
  while read -r -d $'\0' line; do
    if $raw; then
      raw=false
      printf 'printf "%%s" %q\n' "$line"
    else
      raw=true
      if [[ -n "$line" ]]; then
        printf '%s\n' "$line"
      fi
    fi
  done
}

# Render a template file
#
# 1.file the file to render
render() {
  local -r file="$1"

  source <(split "$file" | compile)
}
