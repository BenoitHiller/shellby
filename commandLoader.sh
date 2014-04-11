#!/bin/bash

declare -A pid
declare -A pipes
declare this=$$

# kill a command
function doubleTap {
  local -r file="$1"
  
  local pid="${pids[$file]}"
  children=$(ps -ho pid --ppid $pid | xargs 2>/dev/null)
  grandchildren=$(ps -ho pid --ppid "$children" | xargs 2>/dev/null)
  kill -TERM $pid $children $grandchildren # maybe choose a better signal. Probably shoud be -$pid 

  echo stopping handler: $file 1>&2
  echo handler stop :"${file#$botDir/}" >> "$bufferDir/events"
  wait $pid
  local -i count=0
  while [ "$count" -lt 20 ] && ps --pid "$children $grandchildren" >/dev/null 2>&1; do
    sleep 1
    count=$count+1 
  done
}

# reload a command file
#
# 1.file the file to reload
# 2.output the output pipe
function replacePipe {
  local -r file="$1"
  local -r output="$2"

  local -r pName="${pipes[$file]}"
  local -r pPid="${pid[$file]}"
  local -r commandName="$(basename "$file")"

  exec {IN}<"$bufferDir/$pName.i"
  kill -TERM $(pgrep -P $this -x "$commandName")
  stdbuf -oL "$file" <&$IN | tee "$output" | sed -u "s/^/<</" &
  echo reloading $file >&2
}

# start a folder of processes with pipes
#
# 1.dir the directory containing the commands
# 2.output the output pipe
# 3.input the input pipe
function managePipes {
  local -r dir="$1"
  local -r output="$2"
  local -r input="$3"

  while read coreFile; do
    local pName="$( md5sum "$coreFile" | cut -d " " -f 1 )"
    local commandName="$(basename "$coreFile")"
    pipes["$coreFile"]="$pName"
    mkfifo "$bufferDir/$pName.i"
    stdbuf -oL "$coreFile" < "$bufferDir/$pName.i" | tee "$output" | sed -u "s/^/<</" &
    echo starting $coreFile >&2
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -executable | sort)

  pipePaths=( ${pipes[@]/#/$bufferDir/} )
  grep --line-buffered "^" "$input" | tee "${pipePaths[@]/%/.i}" > /dev/null &
  teePid=$!

  #trap "kill -TERM $teePid $catPid ${pid[@]}; exit 1" SIGTERM
}
