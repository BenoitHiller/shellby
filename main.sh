#!/bin/bash

###############
# load config #
###############

declare -r botDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 
source $botDir/config

declare -r bufferDir=$(mktemp -p "$TMPDIR" -d streambot.XXXXXX)

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

source $botDir/commandLoader.sh

######################
# initialize buffers #
######################

declare -i MB=$((2 * 1024 * 1024))

makeBuffer "$bufferDir/rawInput" $MB
makeBuffer "$bufferDir/rawOutput" $MB
makeBuffer "$bufferDir/noticeInput" $MB
makeBuffer "$bufferDir/events" $MB
makeBuffer "$bufferDir/channel" $MB
makeBuffer "$bufferDir/self" $MB
makeBuffer "$bufferDir/private" $MB

watchFiles &

#################
# start the bot #
#################

# initialize the handlers
commandWatcher "$botDir/commands/" "$bufferDir/rawInput" "$bufferDir/rawOutput" &
commandWatcher "$botDir/events/" "$bufferDir/events" "$bufferDir/rawOutput" &

# start the connection and connect the handler input and output
(tail -n 0 -F $bufferDir/rawOutput 2>/dev/null | netcat $TARGETSERVER $PORT > $bufferDir/rawInput) &

# add the handler output to the rawlog
(tail -n 0 -F $bufferDir/rawOutput 2>/dev/null | stdbuf -oL sed 's/^/<< /' >> $PWD/rawlog) &

# just sit there until killed
wait
