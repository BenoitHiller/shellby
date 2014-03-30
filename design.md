# Overview

The general idea is that for each of the components of the bot there will be a directory of scripts that have that input streamed in to stdin.

To distribute the IO to the various readers I will use a temporary file and have them all tail -F it. It will probably make most sense to use a temporary directory in /tmp.

# Top level parsers

Will be spawned by the top level bot. Which will run in a loop and check for new or changed scripts.
