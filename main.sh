#!/bin/bash

###############
# load config #
###############

declare -r botDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
export botDir
source $botDir/config

declare -r bufferDir=$(mktemp -p "$TMPDIR" -d streambot.XXXXXX)
export bufferDir

################
# toggle debug #
################

[ ! -z "$DEBUG" ] && set -x

#########################
# set up signal handler #
#########################

trap "rm -rf $bufferDir; exit 1" SIGINT SIGTERM EXIT

#####################
# load dependencies #
#####################

source "$botDir/commandLoader.sh"

#################
# start the bot #
#################

mkfifo "$bufferDir/toNetcat" "$bufferDir/fromNetcat"
managePipes "$botDir/commands/" "$bufferDir/toNetcat" "$bufferDir/fromNetcat"
stdbuf -oL netcat -i 1 $TARGETSERVER $PORT < "$bufferDir/toNetcat" | tee "$bufferDir/fromNetcat" | grep --line-buffered "^"  & 

echo started

trap reloadAllConfig SIGHUP

watchFiles "$botDir/commands/" "$bufferDir/toNetcat" "$bufferDir/fromNetcat"
wait
