# Checks if the type of a variable matches the specified type
checkType() {
  local -r variable="$1"
  local -r type="$2"

  declare -p "$variable" 2>/dev/null | grep -qE "^declare -$type"
  return $?
}

# parseArgs.sh
#
# This is an argument parser that dumps the results into two arrays.
#
# A wrapper is provided that splits the arguments properly first.

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

  local char
  local parameterName

  if checkType assignableParameters a; then
    for parameter in "${assignableParameters[@]}"; do
      parameterSet["$parameter"]=
    done
  fi

  local -r shortOption="-+([a-zA-Z])"
  local -r longOption="--+([a-zA-Z])"

  if checkType argMap A && checkType vargs a; then

    argMap=()
    vargs=()

    while (($# > 0)); do
      arg="$1"
      shift
      
      case "$arg" in
        $shortOption )
          if "$getNext"; then
            argMap["$previous"]=
          fi

          if ((${#arg} == 2)); then
            char="${arg:1:1}"
            if [[ -n "${!parameterSet[@]}" ]] && [[ "${parameterSet[$char]+_}" ]]; then
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
              if [[ -n "$previous" ]]; then
                argMap["$previous"]=
              fi
              if [[ -n "${!parameterSet[@]}" ]] && [[ "${parameterSet[$i]+_}" ]]; then
                previous="$i"
                getNext=true
              else
                argMap["$i"]=
                previous=
                getNext=false
              fi
            done
          fi
          ;;
        -- ) 
          if "$getNext"; then
            argMap["$previous"]=
            previous=
            getNext=false
          fi
          vargs+=( "$@" )
          break
          ;;
        $longOption )
          if "$getNext"; then
            argMap["$previous"]=
          fi
          parameterName="${arg#--}"
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
