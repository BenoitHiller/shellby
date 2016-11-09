declare -r LOG_PASTE_DIR="$bufferDir/web/logpaste"
declare -r LOG_PASTE_REGEX='^([a-f0-9]+)\.(txt|html)$'

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
      esac
    fi
  fi
  return 1
}
