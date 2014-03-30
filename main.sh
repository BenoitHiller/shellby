#!/bin/bash

declare -r bufferDir=$(mktemp --tmpdir -d streambot.XXXXXX)
declare -A pids
declare -A md5s

function updateMd5 {
  md5s["$1"]="$(md5sum $1)"
}

function checkMd5 {
  md5sum $md5s["$1"] 2>&1 >/dev/null
  return $?
}

# load/reload a command by filename
#
# 1.file the file to reload
function reloadCommand {
  declare -r file="$1"
  declare pid="$pids["$file"]"

  if [ ! -z "$pid" ]; then
    kill $pid # maybe choose a better signal. Probably shoud be -$pid 

  # TODO: add else case to detect failures
  fi

  # this should execute as a specific user. Or I could set up a chroot jail for a user.
  tail -F $bufferDir/rawInput 2>/dev/null | env -i PATH=$PATH BUFFERDIR="$bufferDir" BOTDIR="$PWD" $file
  pid=$!
  pids["$file"]=$pid
}

# Iterates over the top level command files and loads or reloads them as needed
function commandWatcher {
  # find should filter for executable with maxdepth of 1
  find ./commands/ | while read commandFile; do
    if ! checkMd5 "$commandFile"; then
      updateMd5 "$commandFile"
      reloadCommand "$commandFile"
    elif [ -z "$pids["$commandFile"]" ]
      reloadCommand "$commandFile"
    fi
  done
}

commandWatcher
netcat $1 $2 > $bufferDir/rawInput &

wait
