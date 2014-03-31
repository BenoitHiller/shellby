#!/bin/bash

declare -A pids
declare -A sizes
declare -A md5s

# Creates a buffer file and monitors it for a max size
function makeBuffer {
  local -r file="$1"
  local -r size="$2"

  touch "$file"
  sizes["$file"]=$size
}

function watchFiles {
  while true; do
    for file in "${!sizes[@]}"; do
      if [ "$(stat -c %s "$file")" -gt "${sizes[$file]}" ]; then
        rm "$file"
      fi
    done

    sleep 10
  done
}

# get the md5 for a command and put it in the hash
#
# 1. the file to update
function updateMd5 {
  md5s["$1"]="$(md5sum "$1")"
}

# check the stored hash for a file and return whether it is right
#
# 1. the file to check
function checkMd5 {
  md5sum -c <(echo "${md5s[$1]}") >/dev/null 2>&1
  return $?
}

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

# load/reload a command by filename
#
# 1.file the file to reload
# 2.input the buffer input file used by the process
# 3.output the output file used by the process
function reloadCommand {
  local -r file="$1"
  local -r input="$2"
  local -r output="$3"
  local pid="${pids[$file]}"

  if [ ! -z "$pid" ]; then
    doubleTap "$file"
  fi

  export bufferDir
  export botDir 
  # this should execute as a specific user. Or I could set up a chroot jail for a user.
  (
    tail -n 0 -F "$input" 2>/dev/null | stdbuf -oL $file >> "$output" 
  ) &
  pid=$!
  echo starting handler: $file pid: $pid 1>&2
  echo handler start :"${file#$botDir/}" >> "$bufferDir/events"
  pids["$file"]=$pid
}

function killAll {
  for file in "${!pids[@]}"; do
    doubleTap "$file"
  done
}

# Iterates over the top level command files and loads or reloads them as needed
#
# 1.targetPath path where the commands are
# 2.input the buffer input file for the path
# 3.output the output file for the path
function commandWatcher {
  local -r targetPath="$1"
  local -r input="$2"
  local -r output="$3"
  trap "killAll;exit 1" SIGTERM

  while true; do
     while read commandFile; do
      if ! checkMd5 "$commandFile"; then
        updateMd5 "$commandFile"
        reloadCommand "$commandFile" "$input" "$output"
      elif [ -z "${pids[$commandFile]}" ]; then
        updateMd5 "$commandFile"
        reloadCommand "$commandFile" "$input" "$output"
      fi
    done < <(find "$targetPath" -mindepth 1 -maxdepth 1 -type f -executable)

    sleep 10
  done
}
