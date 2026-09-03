#!/bin/bash

# Get directory
pushd . > '/dev/null';
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}";
export CMD_UTIL_HOME=$(realpath $(dirname "${BASH_SOURCE[0]}"))
echo "Sourcing cmd-util from $CMD_UTIL_HOME"

# Source tools
source ${CMD_UTIL_HOME}/bash/tools.sh
source ${CMD_UTIL_HOME}/bash/aliases.sh
export PATH="${PATH}:${CMD_UTIL_HOME}/bin:${CMD_UTIL_HOME}/bash"

# Optionally source prompt modification
[ ! -z "$CMD_UTIL_PROMPT" ] && source ${CMD_UTIL_HOME}/bash/prompt.sh
