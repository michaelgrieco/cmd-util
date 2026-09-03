#!/bin/bash
# Copy these into your .bashrc file

# general aliases
alias pinfo='ps -Flww -p'

# cmd-util scripts
CMD_UTIL_HOME="${HOME}/bin/cmd-util"
alias wd='${CMD_UTIL_HOME}/bash/wd.sh'
#alias cwd='cd $(${CMD_UTIL_HOME}/bash/wd.sh echo)'
alias cwd='$(command -v deactivate &> /dev/null) && deactivate; cd $(${CMD_UTIL_HOME}/bash/wd.sh echo); ( [ -f .venv/bin/activate ] && echo -n "Source .venv/bin/activate? [n|y] n: " && read ny && [ "$ny" == "y" ] ) && source .venv/bin/activate;'
alias pushwd='pushd $(${CMD_UTIL_HOME}/bash/wd.sh echo)'
alias bjob='${CMD_UTIL_HOME}/bash/bjob.sh'
alias help='less ${CMD_UTIL_HOME}/bash/bash.txt'
alias ntee='${CMD_UTIL_HOME}/bash/named_tee.sh'

# backtracking
alias b='cd ../'
alias bb='cd ../../'
alias bbb='cd ../../../'
alias bbbb='cd ../../../../'

