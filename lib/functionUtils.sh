declare watchedFunctionName
declare watchedFunctionPid

# Helper to manage the saved function.
#
# Only call this from startAndWatch.
startFunction() {
  if [[ -n "$watchedFunctionPid" ]]; then
    local tempPid="$watchedFunctionPid"
    watchedFunctionPid=

    killtree "$tempPid"
    wait "$tempPid"
  fi

  "$watchedFunctionName" <&0 &
  local -r newPid="$!"
  watchedFunctionPid="$newPid"
}

# Runs the specified function restarting it when SIGHUP is recieved
#
# Only run this once per subshell as multiple instances will clobber each other.
# This function will also wait forever when started.
#
# 1. the name of the function to run. Assigned to global variable.
startAndWatch() {
  watchedFunctionName="$1"

  startFunction

  trap startFunction SIGHUP 

  while true; do
    if [[ -n "$watchedFunctionPid" ]]; then
      wait $watchedFunctionPid
      if (($? != 0)); then
        return
      fi
    fi
    sleep 5
  done
}
