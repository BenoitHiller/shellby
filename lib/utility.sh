#!/bin/bash

###########
# general #
###########

# kill the specified process and all of its children
#
# The leaf processes are killed first, then it works up to the input
#
# @. a list of pid numbers. quoting does not matter
function killtree {
  local joinedPids=$(sed -E 's/\s+/,/g' <<< $@)

  local -ra children=( $(pgrep -P "$joinedPids") )
  if [ ${#children[@]} -ne 0 ]; then
    killtree ${children[@]}
  fi
  kill -TERM $@
}

# parse out the metadata from a privmsg
#
# supports a number of other similar messages as well
#
# 1.inputString the whole irc command as one string
#
# stdout. FROMNICK FROMNICK/CHANNEL CMD USERNAME HOSTNAME
# returns. 1 if the input was not parsed and 0 otherwise
function getIRCInfo {
  local -r inputString="$1"

  local -a infoArray=( $( sed -E 's/^:?([^!]+)!([^@]+)@(\S+)\s+(\S+)\s+(\S+)\s+.*/\1 \5 \4 \2 \3/' <<< "$inputString" ) )

  if [ "${#infoArray[@]}" -ne 5 ]; then
    return 1
  fi

  if [[ ! ${infoArray[1]} =~ ^# ]] ; then
    infoArray[1]="${infoArray[0]}"
  fi

  echo "${infoArray[@]}"
  return 0
}

# get the message after the initial mention
#
# 1.inputString the whole irc command as one string
# 2.nick optional nick to parse
#
# stdout. the string message text
function getMessageNoNick {
  local -r inputString="$1"
  local -r nick="$2"

  local nickPattern
  if [ -n "$nick" ]; then
    nickPattern="$nick\W?\s*"
  fi

  sed -E "s/^(\S+\s+){3}:(.*)/\2/I;s/^$nickPattern//" <<< "$inputString"
}
