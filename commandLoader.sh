#!/bin/bash

declare -A pid
declare -A pipes
declare -A md5s
declare this=$$
declare capPid
declare capPipe

function killtree {
  local joinedPids=$(sed -E 's/\s+/,/g' <<< $@)

  local -ra children=( $(pgrep -P "$joinedPids") )
  if [ ${#children[@]} -ne 0 ]; then
    killtree ${children[@]}
  fi
  kill -TERM $@
}

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
  done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -executable | sort)

  pipePaths=( ${pipes[@]/#/$bufferDir/} )
  capPipe=$(mktemp -u -p "$TMPDIR" -d cap.XXXXXXXX)
  mkfifo "$capPipe"
  grep --line-buffered "^" "$input" | tee "${pipePaths[@]/%/.i}" "$capPipe" > /dev/null &
  "$botDir/cap.sh" < "$capPipe" &
  capPid=$(pgrep -P $this -x cap.sh)

}

# put a process that throws out input on the end of the pipeline above and replace it
# to tack on new commands
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
        newInputs+=("$bufferDir/${pipes[$coreFile]}.i")

      # check to see if we want to reload
      elif ! md5sum -c <<< "$savedChecksum"; then
        replacePipe "$coreFile" "$output"
      fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type f -executable | sort)

    if [ ${#newInputs[@]} -ne 0 ]; then
      set -x
      local oldPipe="$capPipe"
      exec {CAP}< "$oldPipe"
      killtree $capPid
      capPipe=$(mktemp -u -p "$TMPDIR" -d cap.XXXXXXXX)
      mkfifo "$capPipe"
      grep --line-buffered "^" "$oldPipe" | tee "${newInputs[@]}" "$capPipe" > /dev/null &
      "$botDir/cap.sh" < "$capPipe" &
      capPid=$(pgrep -P $this -x cap.sh)
      exec {CAP}>&-
      set +x
    fi

  done
}
