#!/bin/bash

###########
# general #
###########

# kill the specified process and all of its children
#
# The leaf processes are killed first, then it works up to the input
#
# @. a list of pid numbers. quoting does not matter
killtree() {
  local joinedPids=$(sed -E 's/\s+/,/g' <<< $@)

  local -ra children=( $(pgrep -P "$joinedPids") )
  if [ ${#children[@]} -ne 0 ]; then
    killtree ${children[@]}
  fi
  kill -TERM $@
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
  if [ -n "$nick" ]; then
    nickPattern="$nick\W?\s*"
  fi

  sed -E "s/^(\S+\s+){3}:(.*)/\2/I;s/^$nickPattern//" <<< "$inputString"
}

# Checks if the type of a variable matches the specified type
checkType() {
  local -r variable="$1"
  local -r type="$2"

  declare -p "$variable" 2>/dev/null | grep -qE "^declare -$type"
  return $?
}

# resplit the passed parameters taking into account quoting
#
# @. parameters to split
resplitAndParse() {
  local -a splitArgs=()
  while IFS= read -r -d $'\0' arg; do
    splitArgs[i++]="$arg"
  done < <(printf "%s " "$@" | sed 's/ $//' | resplit.awk)
  parseArgs "${splitArgs[@]}"
}

declare -A argMap=()
declare -a vargs=()

# Parses the input arguments into a hashmap
#
# Any found parameters are placed into the argMap associative array
# The remaining arguments are placed into the vargs array
#
# @. the arguments to parse
parseArgs() {
  local arg
  local getNext=false
  local previous
  local i
  local -A parameterSet=()
  shopt -s extglob

  if checkType assignableParameters a; then
    for parameter in "${assignableParameters[@]}"; do
      parameterSet["$parameter"]=
    done
  fi

  local -r pattern1="-+([a-zA-Z])"
  local -r pattern2="--+([a-zA-Z])"

  if checkType argMap A && checkType vargs a; then

    argMap=()
    vargs=()

    while (( $# > 0 )); do
      arg="$1"
      shift
      
      case "$arg" in
        $pattern1 )
          if "$getNext"; then
            argMap["$previous"]=
          fi

          if (( "${#arg}" == 2 )); then
            local char="${arg:1:1}"
            if [[ -n "${parameterSet[@]}" ]] && [[ "${parameterSet[$char]+_}" ]]; then
              previous="$char"
              getNext=true
            else
              argMap["$char"]=
              previous=
              getNext=false
            fi
          else
            previous=
            getNext=false
            # the following code is safe due to the invariant that i is [a-zA-Z]{1}
            for i in $(grep -o . <<< "${arg#-}"); do
              # add empty key
              argMap[$i]=
            done
          fi
          ;;
        -- ) 
          if "$getNext"; then
            argMap["$previous"]=
            previous=
            getNext=false
          fi
          # do not parse any more parameters
          while (( $# > 0 )); do
            vargs+=( "$1" )
            shift  
          done
          ;;
        $pattern2 )
          if "$getNext"; then
            argMap["$previous"]=
          fi
          local parameterName="${arg#--}"
          if [[ -n "${parameterSet[@]}" ]] && [[ "${parameterSet[$char]+_}" ]]; then
            previous="$parameterName"
            getNext=true 
          else
            previous=
            getNext=false 
            argMap["$parameterName"]=
          fi
          ;;
        * )
          if "$getNext"; then
            argMap["$previous"]="$arg"
            previous=
            getNext=false
          else
            vargs+=( "$arg" )
          fi
          ;;
      esac
           
    done
    if "$getNext"; then
      argMap["$previous"]=
    fi
  fi

  shopt -u extglob
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

  local -a infoArray=( $( sed -E 's/^:?([^!]+)!([^@]+)@(\S+)\s+(\S+)\s+(\S+)\s+.*/\1 \5 \4 \2 \3/' <<< "$inputString" ) )

  if [ "${#infoArray[@]}" -ne 5 ]; then
    return 1
  fi

  local -r channelRegex="^#"

  if [[ ! ${infoArray[1]} =~ $channelRegex ]] ; then
    infoArray[1]="${infoArray[0]}"
  fi

  echo "${infoArray[@]}"
  return 0
}
