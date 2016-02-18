#
# irc.sh
#
# functions to help parsing the IRC protocol.

declare -r IRC_NICK="[[:alpha:]][][[:alnum:]\\\`^{}]{0,15}"

# lowercase nicks
normalizeNicks() {
  tr "[A-Z]]\\\[" "[a-z]}|{"
}

# get the message after the initial mention
#
# 1.inputString the whole irc command as one string
# 2.nick optional nick to parse
#
# stdout. the string message text
getMessageNoNick() {
  local -r inputString="$1"
  local -r nick="$2"

  local nickPattern
  if [[ -n "$nick" ]]; then
    nickPattern="$nick\W?\s*"
  fi

  sed -E "s/^(\S+\s+){3}:(.*)/\2/I;s/^$nickPattern//" <<< "$inputString"
}


# parse out the metadata from a privmsg
#
# supports a number of other similar messages as well
#
# 1.inputString the whole irc command as one string
#
# stdout. FROMNICK FROMNICK/CHANNEL CMD USERNAME HOSTNAME
# returns. 1 if the input was not parsed and 0 otherwise
getIRCInfo() {
  local -r inputString="$1"

  local -a infoArray=( $(sed -E 's/^:?([^![:space:]]+)(!([^@[:space:]]+)@(\S+))?\s+(\S+)\s+(\S+)(\s+.*)?/\1 \6 \5 \3 \4/' <<< "$inputString") )

  if ((${#infoArray[@]} < 2)); then
    return 1
  fi

  local -r channelRegex="^#"

  if [[ ! ${infoArray[1]} =~ $channelRegex ]] ; then
    infoArray[1]="${infoArray[0]}"
  fi
  local infoText="${infoArray[@]}"

  printf "%s" "$infoText"
  return 0
}

# get fields from space separated data
#
# 1.line the line to split
# @:1. the list of fields to print on separate lines 
getFields() {
  local -r line="$1"
  shift 
  local -ra fields=( $line )
  for i in "$@"; do
    printf "%s\n" "${fields[$i]}" 
  done
}
