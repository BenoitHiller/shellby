shopt -s extglob

set -f

###################
# RFC BNF Regexes #
###################

declare -r REQUEST_LINE_REGEX='^\S+ \S+ \S+$'
declare -r REQUEST_VERSION_REGEX='^\S+ \S+ HTTP\/1\.[10]$'
declare -r LWS='^[\t ]+'
declare -r TOKEN='[^()<>@,;:\"\/[.[.][.].]?={} \t]+'
declare -r TEXT='[[:print:]\t]'
declare -r VALID_HEADER="$TOKEN:$TEXT*"

# This does not validate IPs or match IPv6
declare -r IP='(([[:digit:]]*\.){3}[[:digit:]])'
declare -r PORT='([[:digit:]]*)'

declare -r PCHAR='([[:alnum:]:@&=+$,_.!~*'"'"'()-]|%[[:xdigit:]]{2})'
declare -r PATH_SEGMENT="$PCHAR*(;$PCHAR*)*"

declare -r QUERY="($PCHAR|[;\/?])*"

declare -r DOMAIN_LABEL='([[:alnum:]]|[[:alnum:]][[:alnum:]-]*[[:alnum:]])'
declare -r TOP_LABEL='([[:alpha:]]|[[:alpha:]][[:alnum:]-]*[[:alnum:]])'
declare -r HOSTNAME="(($DOMAIN_LABEL\.)*$TOP_LABEL\.?)"
declare -r HOST="($HOSTNAME|$IP)"
declare -r HOSTPORT="($HOST(:$PORT)?)"
declare -r ABS_PATH="((\/$PATH_SEGMENT)+$QUERY)"
declare -r URI="http:\/\/$HOSTPORT$ABS_PATH"

##################
# Status Reasons #
##################

declare -A REASONS=()
REASONS[100]="Continue"
REASONS[101]="Switching Protocols"
REASONS[200]="OK"
REASONS[201]="Created"
REASONS[202]="Accepted"
REASONS[203]="Non-Authoritative Information"
REASONS[204]="No Content"
REASONS[205]="Reset Content"
REASONS[206]="Partial Content"
REASONS[300]="Multiple Choices"
REASONS[301]="Moved Permanently"
REASONS[302]="Found"
REASONS[303]="See Other"
REASONS[304]="Not Modified"
REASONS[305]="Use Proxy"
REASONS[307]="Temporary Redirect"
REASONS[400]="Bad Request"
REASONS[401]="Unauthorized"
REASONS[402]="Payment Required"
REASONS[403]="Forbidden"
REASONS[404]="Not Found"
REASONS[405]="Method Not Allowed"
REASONS[406]="Not Acceptable"
REASONS[407]="Proxy Authentication Required"
REASONS[408]="Request Timeout"
REASONS[409]="Conflict"
REASONS[410]="Gone"
REASONS[411]="Length Required"
REASONS[412]="Precondition Failed"
REASONS[413]="Request Entity Too Large"
REASONS[414]="Request-URI Too Long"
REASONS[415]="Unsupported Media Type"
REASONS[416]="Requested Range Not Satisfiable"
REASONS[417]="Expectation Failed"
REASONS[500]="Internal Server Error"
REASONS[501]="Not Implemented"
REASONS[502]="Bad Gateway"
REASONS[503]="Service Unavailable"
REASONS[504]="Gateway Timeout"
REASONS[505]="HTTP Version Not Supported"
readonly REASONS

###################
# Other Constants #
###################

declare -ri GET_TIMEOUT=30

##################
# Variable Setup #
##################

# add lists for other types
declare -A getRoutes=()

#############
# Functions #
#############

uriUnescape() {
  gawk '
  BEGIN {
    FPAT="'"$PCHAR"'";
  }
  {
    for(i=1; i<=NF; i++) {
      if( $i ~ /%[[:xdigit:]]{2}/ ) {
        escaped = $i;
        sub(/%/, "0x", escaped);
        printf("%c", strtonum(escaped));
      } else {
        printf("%s", $i);
      }
    }
  }'
}

# echos text with windows newlines
#
# @.text the text to send
echorn() {
  local -r text="$@"
  if declare -p sentBytes &>/dev/null; then
    sentBytes+="${#text}"
  fi
  stdbuf -o0 printf "%s\r\n" "$text"
}

# adds a route to the specified routing table
#
# The routing function will be passed the following arguments when called:
#   1.method the request method
#   2.host the requested(local) host
#   3.file the requested file
# 
# Additionally the associative array queryVars will be set to contain a map of
# all of the passed query variables. They will already be urldecoded.
#
# The routing function is expected to return the following:
#   0 if the request was handled
#   1 if the handler cannot handle the request and would like it to 404
#
# This means that you should return 0 in most "failure" cases. The failure
# status is instead sent to the user.
#
# depSet:
# A getRoutes 
#
# 1.method the http method to route for
# 2.regex the regex to match against the file param
# 3.function the function to call on a match
addRoute() {
  local -r method="$1"
  local -r regex="$2"
  local -r function="$3"

  case "$method" in
    GET)
      getRoutes["$regex"]="$function"
    ;;
  esac
}


# logs the status line in common log format 
#
# depSet:
# $ NCAT_REMOTE_ADDR
#
# 1.requestLine the original request line
# 2.statusCode the status returned
# 3.sentBytes the total number of bytes sent to the client
logStatus() {
  local -r requestLine="$1"
  local -ri statusCode="$2"
  local -r sentBytes="$3"

  if [[ -z "$LOGGING" || "$LOGGING" == "true" ]]; then
    printf "%s - - [%(%d/%b/%Y:%H:%M:%S %z)T] \"%s\" %d %d\n" "$NCAT_REMOTE_ADDR" "$(date +%s)" "$requestLine" "$statusCode" "$sentBytes" >&2
  fi
}

# send a short or empty response to the server
#
# depSet:
# $ requestLine
#
# 1.statusCode the status code of the response
# 2.reason the reason text or nothing for the default
# 3.message optional response body
sendResponseShort() {
  local -ri statusCode="$1"
  local -r reason="${2:-${REASONS[$statusCode]}}"
  local -r message="$3"

  local -i sentBytes=0
  local -i contentLength="${#message}"

  echorn "HTTP/1.0 $statusCode $reason"
  echorn "Content-Length: $contentLength"
  echorn 
  echorn "$message"

  sentBytes+="$contentLength"

  logStatus "$requestLine" "$statusCode" "$sentBytes"

  return 0
}

# send a response to the server
#
# depSet:
# $ requestLine
#
# 1.statusCode the status code of the response
# 2.tempFile a file containing the message body
sendResponse() {
  local -ri statusCode="$1"
  local -r tempFile="$2"

  local -i sentBytes=0

  local -r reason="${REASONS[$statusCode]}"

  if ! declare -p responseHeaders &>/dev/null; then
    local -A responseHeaders=()
  fi
  local -i contentLength

  if [[ -f "$tempFile" ]]; then
    contentLength="$(wc -c <"$tempFile")"
    responseHeaders["Content-Length"]="$contentLength"
  else
    responseHeaders["Content-Length"]=0
  fi

  echorn "HTTP/1.0 $statusCode $reason"
  for header in "${!responseHeaders[@]}"; do
    echorn "$header: ${responseHeaders[$header]}"
  done
  echorn

  if [[ -f "$tempFile" ]]; then
    cat "$tempFile"
  fi

  sentBytes+="$contentLength"

  logStatus "$requestLine" "$statusCode" "$sentBytes"

  return 0
}

sendResponsePipe() {
  local -ri statusCode="$1"
  local -r contentLength="$2"

  # use a tmpfile for pipes of unknown length
  if [[ -z "$contentLength" ]]; then
    set -x
    local -r tmpFile="$(mktemp -p "$TMPDIR" webCache.XXXXXX)"
    stdbuf -o1000 cat >"$tmpFile"
    sendResponse "$statusCode" "$tmpFile"
    rm -f "$tmpFile"

    return 0
  fi

  local -i sentBytes=0

  local -r reason="${REASONS[$statusCode]}"

  if ! declare -p responseHeaders &>/dev/null; then
    local -A responseHeaders=()
  fi

  responseHeaders["Content-Length"]="$contentLength"

  echorn "HTTP/1.0 $statusCode $reason"
  for header in "${!responseHeaders[@]}"; do
    echorn "$header: ${responseHeaders[$header]}"
  done
  echorn

  cat -

  sentBytes+="$contentLength"

  logStatus "$requestLine" "$statusCode" "$sentBytes"

  return 0

}

# do not use, broken
sendResponseChunked() {
  local -ri statusCode="$1"
  local -r reason="${REASONS[$statusCode]}"

  local -i sentBytes=0

  if ! declare -p responseHeaders &>/dev/null; then
    local -A responseHeaders=()
  fi

  responseHeaders["Transfer-Encoding"]="chunked"
  echorn "HTTP/1.0 $statusCode $reason"
  for header in "${!responseHeaders[@]}"; do
    echorn "$header: ${responseHeaders[$header]}"
  done
  echorn

  local -r chunkFile="$(mktemp -p "$TMPDIR" chunkcache.XXXXXX)"
  head -c 4096 >"$chunkFile"
  while true; do
    head -c 4096 >"$chunkFile.next"
    if [[ ! -s "$chunkFile.next" ]]; then
      break;
    fi

    stdbuf -o0 printf "1000\r\n"
    stdbuf -o0 cat "$chunkFile"
    stdbuf -o0 printf "\r\n"
    sentBytes+=4096+2+4+2
    mv "$chunkFile.next" "$chunkFile"
  done

  local -i chunkLength="$(stat -c "%s" "$chunkFile")"
  stdbuf -o0 printf "%x\r\n" "$chunkLength"
  stdbuf -o0 cat "$chunkFile"
  stdbuf -o0 printf "\r\n"
  sentBytes+=4096+2+${#chunkLength}+2

  rm -f "$chunkFile" "$chunkFile.next" &>/dev/null

  echorn "0"
  echorn

  logStatus "$requestLine" "$statusCode" "$sentBytes"

  return 0
}

# find a matching route handler and call it
#
# depSet
# A getRoutes
#
# 1.method the http method
# 2.host the requested(local) host
# 3.file the file component of the query
# 4.query the query string
#
# returns:
# 0 on successful match
# 1 on 404
matchRoutes() {
  local -r method="$1"
  local -r host="$2"
  local -r file="$3"
  local -r query="$4"
  
  # Accessible By functions below.
  local -A queryVars=()
  local -a queryTemp=()
  IFS="&" read -a queryTemp <<< "${query#?}"

  for var in "${queryTemp[@]}"; do
    queryVars["${var%%=*}"]="$(uriUnescape <<< "${var#*=}")"
  done

  unset queryTemp

  case "$method" in
    GET)
      for pattern in "${!getRoutes[@]}"; do
        if grep -q -E "$pattern" <<< "$file"; then
          "${getRoutes[$pattern]}" "$method" "$host" "$file"
          return $?
        fi
      done
    ;;
  esac

  return 1
}

# process a get request
#
# The method reads the remaining lines of the request and passes the processed
# request info on to a handler.
#
# 1.requestLine the first line of the request
# 2.method the request method (HEAD or GET)
getRequest() {
  local -r requestLine="$1"
  local -r method="$2"

  local requestUri="${requestLine% *}"
  requestUri="${requestUri#* }"

  local -A headers=()
  local lastHeader
  local line
  local fieldName
  local fieldValue

  local -i startTime
  printf -v startTime "%(%s)T"
  local -i now

  local -i readResult

  while true; do
    IFS= read -r -t 10 line
    readResult=$? 
    if (( readResult > 128 )); then
      # timed out
      printf -v now "%(%s)T"
      if (( now - startTime > GET_TIMEOUT )); then
        # request has timed out
        sendResponseShort 408
        exit 1
      elif (( now < startTime )); then
        # system time changed...
        startTime=now
      else
        # try again
        continue
      fi
    elif (( readResult != 0 )); then
      # reached EOF
      break
    fi
    
    if [[ -z "$line" ]]; then
      # End of headers is denoted with an empty line.
      break
    fi
    
    # If this line starts with a continuation fold it into the previous line
    # and parse them both. This will replace any stored value for this header.
    if [[ "$line" =~ $LWS ]]; then
      line="$lastHeader ${line##*([\t ])}"
    fi

    if [[ "$line" =~ $VALID_HEADER ]]; then
      fieldName="${line%%:*}"
      fieldValue="${line#*:}"
    
      # It would be nice to preserve the case, but headers are supposedly
      # case-insensitive.
      headers["${fieldName,,}"]="${fieldValue##*([[:space:]])}"
    fi
    
    lastHeader="$line"
  done

  # Get the host and path
  local host
  local path
  local query
  local file

  if [[ "${headers[host]+_}" ]]; then
    host="${headers[host]}"
    path="$requestUri"
  elif [[ "$requestUri" =~ $URI ]]; then
    # If we have the whole URI in the requestUri, use that
    host="$(sed -E "s $URI \1 " <<< "$requestUri")"
    path="${requestUri#http://$host}"
  else
    path="$requestUri"
  fi

  # Pretty sure that a get with * is useless
  if [[ "$path" != '*' ]]; then
    query="$(sed -E "s/^(\/$PATH_SEGMENT)+//" <<< "$path" )"

    # The query must start with a ? as anything else would be matched as path.
    file="${path%%$query}"
  fi

  if ! matchRoutes GET "$host" "$file" "$query"; then
    sendResponseShort 404 "Not Found" "Not found: $file"
  fi

}

# start the server using all the specified matchers
runServer() {
  local requestLine
  local method

  # loop to wrap everything so that we keepalive
  while true; do
    # grab the request line
    if ! IFS= read -r -t "$GET_TIMEOUT" requestLine; then
      # we never got anything from the server
      exit 1
    fi
    
    if [[ ! "$requestLine" =~ $REQUEST_LINE_REGEX ]]; then
      sendResponseShort 400
      exit $?
    fi 

    if [[ ! "$requestLine" =~ $REQUEST_VERSION_REGEX ]]; then
      sendResponseShort 505
      exit $?
    fi

    # reset the count
    sentBytes=0

    method="${requestLine%% *}"

    case "$method" in
      GET)
        getRequest "$requestLine" GET
      ;;
      HEAD)
        getRequest "$requestLine" GET \
          | sed -E '/^\r?$/q'
      ;;
      *)
        sendResponseShort 405
        exit $?
      ;;
    esac

    if [[ "$DEBUG" == "true" ]]; then
      return 0
    fi

  done < <(stdbuf -oL dos2unix)
}

# function to serve a file if it exists
#
# 1.dir the directory the file has to be in
# 2.file the path to the file relative to dir
#
# returns:
# 0 if the file exists and was sent
# 1 if the file was not found
serveFile() {
  local -r dir="$(readlink -m "$1")"
  local -r file="$2"
  local -r target="$(find "$dir" -type f -print0 | grep -Fxz -m 1 "$dir/$file")"

  if [[ -n "$target" && -f "$target" ]]; then
    sendResponse 200 "$target"
    return 0
  fi
  return 1
}
