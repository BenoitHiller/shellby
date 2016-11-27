declare -r LOG_PASTE_DIR="$bufferDir/web/logpaste"
declare -r LOG_PASTE_REGEX='^([a-f0-9]+)\.(txt|html|json)$'
declare -r LOG_FILE_REGEX='^(([^/.]+)/[0-9]{4}/[0-9]{2}/[0-9]{2})\.(txt|html|json)$'

log_formatTxtLines() {
  local -r showHost="$1"
  if "$showHost"; then
    gawk -F "\r" '
      /^[0-9]+/{
        if ($5 ~ /message/) {
          printf("[%s] %s (%s@%s): %s\n", strftime("%Y-%m-%d %H:%M:%S",$1), $2, $3, $4, $6);
        } else if ( $5 ~ /notice/) {
          printf( "[%s] (notice) %s (%s@%s): %s\n", strftime("%Y-%m-%d %H:%M:%S",$1), $2, $3, $4, $6);
        } else if ( $5 ~ /action/) {
          print "[" strftime("%Y-%m-%d %H:%M:%S",$1) "]", "*", $2, $6
        } else {
          print $0
        }
      }
      /^[^0-9]/{print $0}
    '

  else
    gawk -F "\r" '
      /^[0-9]+/{
        if ($5 ~ /message/) {
          print "[" strftime("%Y-%m-%d %H:%M:%S",$1) "]", $2 ":", $6
        } else if ( $5 ~ /notice/) {
          print "[" strftime("%Y-%m-%d %H:%M:%S",$1) "] (notice)", $2 ":", $6
        } else if ( $5 ~ /action/) {
          print "[" strftime("%Y-%m-%d %H:%M:%S",$1) "]", "*", $2, $6
        } else {
          print $0
        }
      }
      /^[^0-9]/{print $0}
    '
  fi

}

log_formatHtmlLines() {
gawk -F "\r" '
  /^[0-9]+/{
    if ($5 ~ /action/) {
      printf("<div class=\"log-line log-%s\" data-username=\"%s\" data-hostname=\"%s\">[<span class=\"log-timestamp\">%s</span>] * <span class=\"log-nick\">%s</span> <span class=\"log-content\">%s</span></div>\n", $5, $3, $4,  strftime("%Y-%m-%d %H:%M:%S",$1), $2, $6);
    } else {
      printf("<div class=\"log-line log-%s\" data-username=\"%s\" data-hostname=\"%s\">[<span class=\"log-timestamp\">%s</span>] <span class=\"log-nick\">%s</span>: <span class=\"log-content\">%s</span></div>\n", $5, $3, $4,  strftime("%Y-%m-%d %H:%M:%S",$1), $2, $6);
    }
  }

  /^[^0-9]/{
    # group separators
    printf("</div>\n<div class=\"log-group\">\n")
  }
'

}

log_formatJsonLines() {
gawk -F "\r" '
  function escapeJson(string) {
    value = string
    gsub(/[\\"]/, "\\\\&", value)
    gsub(/\x00/, "\\u0000", value)
    gsub(/\x01/, "\\u0001", value)
    gsub(/\x02/, "\\u0002", value)
    gsub(/\x03/, "\\u0003", value)
    gsub(/\x04/, "\\u0004", value)
    gsub(/\x05/, "\\u0005", value)
    gsub(/\x06/, "\\u0006", value)
    gsub(/\x07/, "\\u0007", value)
    gsub(/\x08/, "\\u0008", value)
    gsub(/\x09/, "\\u0009", value)
    gsub(/\x0a/, "\\u000a", value)
    gsub(/\x0b/, "\\u000b", value)
    gsub(/\x0c/, "\\u000c", value)
    gsub(/\x0d/, "\\u000d", value)
    gsub(/\x0e/, "\\u000e", value)
    gsub(/\x0f/, "\\u000f", value)
    gsub(/\x10/, "\\u0010", value)
    gsub(/\x11/, "\\u0011", value)
    gsub(/\x12/, "\\u0012", value)
    gsub(/\x13/, "\\u0013", value)
    gsub(/\x14/, "\\u0014", value)
    gsub(/\x15/, "\\u0015", value)
    gsub(/\x16/, "\\u0016", value)
    gsub(/\x17/, "\\u0017", value)
    gsub(/\x18/, "\\u0018", value)
    gsub(/\x19/, "\\u0019", value)
    gsub(/\x1a/, "\\u001a", value)
    gsub(/\x1b/, "\\u001b", value)
    gsub(/\x1c/, "\\u001c", value)
    gsub(/\x1d/, "\\u001d", value)
    gsub(/\x1e/, "\\u001e", value)
    gsub(/\x1f/, "\\u001f", value)
    return value
  }

  BEGIN {
    printf("[")
  }

  /^[0-9]+/{
    if (lastMatch) {
      printf(",");
    }
    printf("\n{ \"type\": \"%s\", \"username\": \"%s\", \"hostname\": \"%s\", \"timestamp\": %d, \"nick\": \"%s\", \"content\": \"%s\"}", $5, escapeJson($3), escapeJson($4), $1, escapeJson($2), escapeJson($6));
    lastMatch=1
  }

  /^[^0-9]/{
    lastMatch=0
    printf("\n],\n[")
    # group separators
  }

  END {
    printf("\n]")
  }
'

}

serveLogPaste() {
  local file="${3#/log/paste/}"
  if [[ "$file" =~ $LOG_PASTE_REGEX ]]; then
    local format="${BASH_REMATCH[2]}"
    local file="${BASH_REMATCH[1]}"
    local -r target="$(find "$LOG_PASTE_DIR" -type f -print0 | grep -Fzx -m 1 "$LOG_PASTE_DIR/$file")"
    if [[ -n "$target" && -f "$target" ]]; then
      case "$format" in
        txt)
          local showHost
          if [[ "${queryVars[h]}" == true ]]; then
            showHost=true
          else
            showHost=false
          fi
          local -A responseHeaders=()
          responseHeaders["Content-Type"]="text/plain"
          log_formatTxtLines "$showHost" <"$target" \
            | sendResponsePipe 200
          return 0
          ;;
        html)
          escapeHtml <"$target" \
            | log_formatHtmlLines \
            | cat "$botLib/web/logheader.html" - "$botLib/web/logfooter.html"\
            | sendResponsePipe 200
          return 0
          ;;
        json)
          log_formatJsonLines  <"$target" \
            | cat <(echo "[") - <(echo "]") \
            | sendResponsePipe 200
          return 0
          ;;
      esac
    fi
  fi
  return 1
}

serveLog() {
  set -x
  local file="${3#/log/}"
  if [[ "$file" =~ $LOG_FILE_REGEX ]]; then
    local format="${BASH_REMATCH[3]}"
    local file="${BASH_REMATCH[1]}"
    local channel="${BASH_REMATCH[2]}"

    local -r target="$(find "$botLogs" -type f -print0 | grep -Fzx -m 1 "$botLogs/#${file}_message")"
    if [[ -n "$target" && -f "$target" ]]; then
      case "$format" in
        txt)
          local showHost
          if [[ "${queryVars[h]}" == true ]]; then
            showHost=true
          else
            showHost=false
          fi
          local -A responseHeaders=()
          responseHeaders["Content-Type"]="text/plain"
          log_formatTxtLines "$showHost" <"$target" \
            | sendResponsePipe 200
          return 0
          ;;
        html)
          escapeHtml <"$target" \
            | log_formatHtmlLines \
            | cat "$botLib/web/logheader.html" - "$botLib/web/logfooter.html"\
            | sendResponsePipe 200
          return 0
          ;;
        json)
          log_formatJsonLines  <"$target" \
            | sendResponsePipe 200
          return 0
          ;;
      esac
    fi
  fi
  return 1 
}
