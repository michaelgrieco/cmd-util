#!/bin/bash
# Copy these into your .bashrc file

# general aliases
alias pinfo='ps -Flww -p'
alias pinfo='ps -Flww -p'
alias rgrep='grep -Rns --color=auto'
alias regrep='egrep -Rns --color=auto'
alias find='find -L'

# cmd-util scripts
alias wd='${CMD_UTIL_HOME}/bash/wd.sh'
alias pushwd='pushd $(${CMD_UTIL_HOME}/bash/wd.sh echo)'
alias bjob='${CMD_UTIL_HOME}/bash/bjob.sh'
alias help='less ${CMD_UTIL_HOME}/bash/bash.txt'
alias ntee='${CMD_UTIL_HOME}/bash/named_tee.sh'

function cwd {
    command -v deactivate &> /dev/null && deactivate
    cd $(${CMD_UTIL_HOME}/bash/wd.sh echo)
    if [ -f .venv/bin/activate ]; then
        echo -n "Source .venv/bin/activate? (y/[n]): "
        read ny
        [ "$ny" == "y" ] && source .venv/bin/activate
    fi
}
export function cwd

# backtracking
alias b='cd ../'
alias bb='cd ../../'
alias bbb='cd ../../../'
alias bbbb='cd ../../../../'

