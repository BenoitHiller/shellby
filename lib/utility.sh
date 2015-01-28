#!/bin/bash

#########
# Regex #
#########

# This is a perl style regex. Sorry
declare -r urlRegex='\b((?:https?:(?:/{1,3}|[a-z0-9%]))(?:[^\s()<>{}[]]+|([^\s()]?([^\s()]+)[^\s()]?)|([^\s]+?))+(?:([^\s()]?([^\s()]+)[^\s()]?)|([^\s]+?)|[^\s`!()[]\{\};:'"'"'".,<>?«»“”‘’]))'

###########
# general #
###########

# kill the specified process and all of its children
#
# The leaf processes are killed first, then it works up to the input
#
# @. a list of pid numbers. quoting does not matter
killtree() {
  local -a safePids=()
  for arg in "$@"; do
    if (($arg > 0)); then
      safePids+=( "$arg" )
    fi
  done
  if ((${#safePids[@]} > 0)); then
    local joinedPids=$(sed -E 's/\s+/,/g' <<< "${safePids[@]}")

    local -ra children=( $(pgrep -P "$joinedPids") )
    if [[ ${#children[@]} != 0 ]]; then
      killtree ${children[@]}
    fi
    kill -TERM ${safePids[@]}
  fi
}

# If stdin is empty print an error message
#
# 1.message the message to print
ifEmpty() {
  local -r message="$1"

  if read -r line; then
    cat <(echo "$line") -
  else
    echo "$message"
  fi
}

# Gets a random message from a message file
#
# 1.file the name of the message file to get from
# @:1. the parameters to pass to printf
getMessage() {
  local -r file="$1"
  shift
  printf "$(shuf -n 1 "$botShare/messages/$file")" "$@"
}
