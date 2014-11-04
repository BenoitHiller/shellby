#!/bin/bash

source "$botDir/lib/utility.sh"

# root names for the command input files
declare -A pipes
# md5s of the command files (stored as: md5 <TAB> filename)
declare -A md5s
# uneccessary copy of $$
declare this=$$

# the pid and pipefile for the most recent pipeline cap
declare capPid
declare capPipe

######################
# loading and piping #
######################

# reload a command file
#
# 1.file the file to reload
# 2.output the output pipe
function replacePipe {
  local -r file="$1"
  local -r output="$2"

  local -r pName="${pipes[$file]}"
  local -r commandName="$(basename "$file")"
  local checksum="$( md5sum "$coreFile")"
  md5s["$coreFile"]="$checksum"

  exec {IN}<"$bufferDir/$pName.i"
  killtree $(pgrep -P $this -x "$commandName")
  stdbuf -oL "$file" <&$IN | tee "$output" | sed -u "s/^/<</" &
  echo reloading $file >&2
}

# Start a single command for the first time
#
# This does not attach the input pipe for you, just creates it.
#
# 1.coreFile the file to start
# 2.output the output pipe for the command
function startCommand {
  local -r coreFile="$1"
  local -r output="$2"

  local pName="$( md5sum <<< "$coreFile" | cut -d " " -f 1 )"
  local checksum="$( md5sum "$coreFile")"
  local commandName="$(basename "$coreFile")"

  pipes["$coreFile"]="$pName"
  md5s["$coreFile"]="$checksum"

  mkfifo "$bufferDir/$pName.i"
  stdbuf -oL "$coreFile" < "$bufferDir/$pName.i" | tee "$output" | sed -u "s/^/<</" &
  echo starting $coreFile >&2
}

# pipes the input into the outputs and caps the pipeline
#
# the cap file pid is saved in a global variable
#
# 1.input the input pipe
# @:2.outputs the output pipes
function pipeInput {
  local -r input="$1"
  local -ra outputs=( "${@:2}" )

  capPipe=$(mktemp -u "$bufferDir/cap.XXXXXXXX")
  mkfifo "$capPipe"
  grep --line-buffered "^" "$input" | tee "${outputs[@]}" "$capPipe" > /dev/null &
  cap < "$capPipe" &
  capPid=$(pgrep -P $this -x cap)
}

######################
# command management #
######################

# function to send SIGHUP to each running command
function reloadAllConfig {
  for file in "${!md5s[@]}"; do
    local commandName="$(basename "$file")"
    local pid=$(pgrep -P $this -x "$commandName")
    if [ -n "$pid" ]; then
      kill -HUP $pid
    fi
  done
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
    startCommand "$coreFile" "$output"
  done < <(find -L "$dir" -mindepth 1 -maxdepth 1 -type f -executable | sort)

  local pipePaths=( ${pipes[@]/#/$bufferDir/} )
  pipeInput "$input" "${pipePaths[@]/%/.i}"

}

# Watch a directory for added commands or changed commands.
# 
# When a command modified, it will be killed and its pipes will be reused by
# the new process.
#
# When new commands are added the "cap" at the end of the old pipeline is
# removed, the new commands are plumbed with the cap's input and a new cap is
# placed on the end of the pipeline.
#
# 1.dir the directory to watch
# 2.output the output pipe
# 3.input the input pipe
function watchFiles {
  local -r dir="$1"
  local -r output="$2"
  local -r input="$3"

  while true; do
    local -a newInputs=()
    sleep 10

    while read coreFile; do
      local savedChecksum="${md5s[$coreFile]}"

      # no checksum. Start a new command
      if [ -z "$savedChecksum" ]; then
        startCommand "$coreFile" "$output"
        # add the new input pipe to an array to be plumbed at the end of the loop
        newInputs+=("$bufferDir/${pipes[$coreFile]}.i")

      # check to see if we want to reload
      elif ! md5sum -c <<< "$savedChecksum" >/dev/null 2>&1; then
        replacePipe "$coreFile" "$output"
      fi
    done < <(find -L "$dir" -mindepth 1 -maxdepth 1 -type f -executable | sort)

    # plumb the array of new input pipes if it isn't empty
    if [ ${#newInputs[@]} -ne 0 ]; then
      local oldPipe="$capPipe"
      exec {CAP}< "$oldPipe"

      killtree $capPid
      pipeInput "$oldPipe" "${newInputs[@]}"

      exec {CAP}>&-
    fi
  done
}
