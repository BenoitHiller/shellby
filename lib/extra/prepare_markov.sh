#!/bin/bash
#
# Script to prepare a corpus for use with the markov preprocessor.
#
# Takes the corpus on stdin and outputs the list of words to stdout.

sed -E 's/^[^   ]+	//;s/[{}]//g;s/^/{ /g;s/^M|\./ } { /g;s/$/ }/;s/[^a-zA-Z:.;?!,'"'"'0-9{}-]+/\n/g;s/--/\n/g' | sed '/^$/d'
