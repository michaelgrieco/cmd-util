#!/bin/bash

# ghit - interactive git helper
# Usage: ghit [action] [files...]

# == helpers ==================================================================

actions=(clone pull history rebase commit branch branchd remote worktree)

_ghit_confirm() {
    # _ghit_confirm "prompt text": returns 0 for yes, 1 for no
    local prompt="$1"
    local reply
    read -rp "$prompt [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

_ghit_read_file() {
    # _ghit_read_file "prompt" result_var [required]
    # Prompts for a file path with readline tab completion.
    # Writes the entered value into the named variable.
    # If $3 is "required" and the user leaves it blank, prints an error and
    # returns 1.
    local prompt="$1"
    local -n _file_result="$2"
    local required="${3:-}"

    # Activate filename completion for this one read, then restore the
    # previous TAB binding so we don't leak the change into the shell.
    local _prev_tab
    _prev_tab=$(bind -q complete 2>/dev/null | awk '{print $NF}' | tr -d '"')
    bind 'TAB:complete-filename' 2>/dev/null
    read -rep "$prompt" -i "${_file_result}" _file_result
    bind "TAB:${_prev_tab:-complete}" 2>/dev/null

    if [[ "$required" == "required" && -z "$_file_result" ]]; then
        echo "ghit: no file provided." >&2
        return 1
    fi
}

_ghit_pick_action() {
    # $1: name of the variable in the caller to write the result into.
    # Using a nameref lets us print freely to stdout without $(...) eating it.
    local -n _result="$1"
    echo "Available actions:"
    local i
    for i in "${!actions[@]}"; do
        printf "  [%d] %s\n" "$((i + 1))" "${actions[$i]}"
    done
    echo ""
    local choice
    read -rp "Select an action [1-${#actions[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#actions[@]} )); then
        _result="${actions[$((choice - 1))]}"
    else
        _result=""
    fi
}

# == actions ==================================================================

_ghit_clone() {
    local url
    read -rp "Repository URL to clone: " url
    if [[ -z "$url" ]]; then
        echo "ghit clone: no URL provided." >&2
        return 1
    fi
    git clone "$url"
}

_ghit_pull() {
    echo "Running git pull..."
    git pull
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "git pull failed. This may be due to a force-push on the remote."
        if _ghit_confirm "Stash local changes, reset to the remote branch, and re-checkout locally?"; then
            local branch
            branch=$(git rev-parse --abbrev-ref HEAD)

            echo "Stashing local changes..."
            git stash

            echo "Fetching all remotes..."
            git fetch --all

            echo "Checking out remote HEAD (detached)..."
            git checkout "origin/$branch"

            echo "Deleting local branch '$branch'..."
            git branch -D "$branch"

            echo "Checking out '$branch' from remote..."
            git checkout "$branch"

            echo "Done. Local branch '$branch' now tracks origin/$branch."
        else
            echo "Aborted. No changes made."
            return $exit_code
        fi
    fi
}

_ghit_blame() {
    # Expects the file as $1 - caller must ensure it is non-empty.
    local file="$1"

    # Collect optional git blame arguments interactively.
    local extra_args=()

    local line_range
    read -rp "Line range (e.g. 10,20 10,+20 or leave blank to skip): " line_range
    if [[ -n "$line_range" ]]; then
        extra_args+=("-L" "$line_range")
    fi

    local rev
    read -rp "Starting revision / commit (leave blank to skip): " rev
    if [[ -n "$rev" ]]; then
        extra_args+=("$rev")
    fi

    if _ghit_confirm "Show only the root commit for each line (--root)?"; then
        extra_args+=("--root")
    fi

    if _ghit_confirm "Show long commit hashes (-l)?"; then
        extra_args+=("-l")
    fi

    if _ghit_confirm "Detect moved/copied lines within the file (-M)?"; then
        extra_args+=("-M")
    fi

    if _ghit_confirm "Detect moved/copied lines across files (-C)?"; then
        extra_args+=("-C")
    fi

    if _ghit_confirm "Ignore whitespace changes (-w)?"; then
        extra_args+=("-w")
    fi

    echo ""
    echo "Running: git blame ${extra_args[*]} -- $file"
    git blame "${extra_args[@]}" -- "$file"
}

_ghit_history() {
    # Optional first argument: a file to scope all operations to.
    local file="$1"
    if [[ -z "$file" ]]; then
        _ghit_read_file "File path (leave blank to operate on the whole repo): " file
    fi

    local sub_actions=("blame" "log" "diff for commit" "diff HEAD vs ref")
    echo ""
    echo "History operations:"
    local i
    for i in "${!sub_actions[@]}"; do
        printf "  [%d] %s\n" "$((i + 1))" "${sub_actions[$i]}"
    done
    echo ""

    local choice
    read -rp "Select an operation [1-${#sub_actions[@]}]: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#sub_actions[@]} )); then
        echo "ghit history: invalid selection." >&2
        return 1
    fi

    case "$choice" in
        1)  # == blame ======================================================)
            if [[ -z "$file" ]]; then
                _ghit_read_file "File to blame: " file required || return 1
            fi
            _ghit_blame "$file"
            ;;

        2)  # == log ========================================================)
            log_args=("--name-only")
            if [[ -n "$file" ]]; then
                # --follow tracks renames across the history
                log_args+=("--follow")
            fi

            local log_fmt
            read -rp "Format (oneline/short/medium/full - leave blank for default): " log_fmt
            if [[ -n "$log_fmt" ]]; then
                log_args+=("--format=$log_fmt")
            fi

            local log_n
            read -rp "Limit number of commits (leave blank for no limit): " log_n
            if [[ -n "$log_n" ]]; then
                log_args+=("-n" "$log_n")
            fi

            echo ""
            if [[ -n "$file" ]]; then
                echo "Running: git log ${log_args[*]} -- $file"
                git log "${log_args[@]}" -- "$file"
            else
                echo "Running: git log ${log_args[*]}"
                git log "${log_args[@]}"
            fi
            ;;

        3)  # == diff for a specific commit ==================================)
            local hash
            read -rp "Commit hash to show diff for: " hash
            if [[ -z "$hash" ]]; then
                echo "ghit history: no commit hash provided." >&2
                return 1
            fi

            echo ""
            if [[ -n "$file" ]]; then
                echo "Running: git diff ${hash}^..${hash} -- $file"
                git diff "${hash}^..${hash}" -- "$file"
            else
                echo "Running: git diff ${hash}^..${hash}"
                git diff "${hash}^..${hash}"
            fi
            ;;

        4)  # == aggregate diff between HEAD and a hash or branch ============)
            local ref
            read -rp "Compare HEAD against (hash or branch name): " ref
            if [[ -z "$ref" ]]; then
                echo "ghit history: no ref provided." >&2
                return 1
            fi

            echo ""
            if [[ -n "$file" ]]; then
                echo "Running: git diff ${ref}..HEAD -- $file"
                git diff "${ref}..HEAD" -- "$file"
            else
                echo "Running: git diff ${ref}..HEAD"
                git diff "${ref}..HEAD"
            fi
            ;;
    esac
}

_ghit_rebase() {
    # Check for uncommitted changes (staged or unstaged) and offer to handle
    # them before rebase touches the working tree.
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "You have uncommitted changes."
        echo "  [1] stash them"
        echo "  [2] commit them"
        echo "  [3] continue anyway"
        echo ""
        local wc_choice
        read -rp "How would you like to proceed? [1-3]: " wc_choice
        case "$wc_choice" in
            1)
                git stash
                ;;
            2)
                _ghit_commit || return 1
                ;;
            3)
                ;;
            *)
                echo "ghit rebase: invalid choice, aborting." >&2
                return 1
                ;;
        esac
        echo ""
    fi

    local interactive_flag=""
    if _ghit_confirm "Run an interactive rebase (-i)?"; then
        interactive_flag="-i"
    fi

    local target
    read -rp "Rebase onto (branch, commit, or upstream - leave blank to use upstream): " target

    if [[ -n "$target" ]]; then
        git rebase $interactive_flag "$target"
    else
        git rebase $interactive_flag
    fi
}

_ghit_commit() {
    local hook=".git/hooks/pre-commit"

    # Offer git add -p whenever there are unstaged changes.
    if ! git diff --quiet; then
        echo "There are unstaged changes in the working tree."
        if _ghit_confirm "Run 'git add -p' to stage changes interactively?"; then
            git add -p
        fi
    fi

    # Stage + hook loop: keep iterating until the hook passes or the user bails.
    while true; do
        # Run the pre-commit hook if present.
        if [[ -x "$hook" ]]; then
            echo ""
            echo "Running pre-commit hook..."
            "$hook"
            local hook_exit=$?
            if [[ $hook_exit -ne 0 ]]; then
                echo ""
                echo "Pre-commit hook failed (exit $hook_exit)."
                if _ghit_confirm "The hook may have auto-fixed files. Stage changes and retry?"; then
                    echo ""
                    git add -p
                    continue
                else
                    echo "Aborting commit." >&2
                    return $hook_exit
                fi
            fi
            echo "Pre-commit hook passed."
        fi

        # Hook passed (or absent) — exit the loop.
        break
    done

    # Prompt for commit message.
    echo ""
    commit_flags=""
    local message
    echo "Commit message (enter 'amend') to amend the last commit)"
    read -rp "> " message
    if [[ -z "$message" ]]; then
        echo "ghit commit: empty commit message, aborting." >&2
        return 1
    elif [ "$message" == "amend" ]; then
        commit_flags="$commit_flags --amend"
    fi

    git commit -m $commit_flags "$message"
}

_ghit_select_branch() {
    # _ghit_select_branch result_var [prompt] [extra_option_label]
    # Displays a numbered list of local branches and writes the chosen branch
    # name into result_var. Optionally appends one extra labelled entry (e.g.
    # "[n] create a new branch"); if chosen, writes "" into result_var and
    # returns 2 so the caller can distinguish it from a normal selection.
    local -n _branch_result="$1"
    local prompt="${2:-Select a branch: }"
    local extra_label="${3:-}"

    local branches=()
    while IFS= read -r line; do
        branches+=("${line#\* }")
    done < <(git branch 2>/dev/null)

    if [[ ${#branches[@]} -eq 0 ]]; then
        echo "ghit: not inside a git repository." >&2
        return 1
    fi

    echo "Local branches:"
    local i raw_lines=()
    while IFS= read -r line; do
        raw_lines+=("$line")
    done < <(git branch)
    for i in "${!raw_lines[@]}"; do
        printf "  [%d] %s\n" "$((i + 1))" "${raw_lines[$i]}"
    done
    if [[ -n "$extra_label" ]]; then
        printf "  [n] %s\n" "$extra_label"
    fi
    echo ""

    local choice
    read -rp "$prompt" choice

    if [[ -n "$extra_label" && ( "$choice" == "n" || "$choice" == "N" ) ]]; then
        _branch_result=""
        return 2
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#branches[@]} )); then
        _branch_result="${branches[$((choice - 1))]}"
        return 0
    else
        echo "ghit: invalid selection." >&2
        return 1
    fi
}

_ghit_branch() {
    local selected
    _ghit_select_branch selected \
        "Select a branch or 'n' to create one: " \
        "create a new branch"
    local rc=$?

    if [[ $rc -eq 2 ]]; then
        # == create a new branch ===============================================
        local new_branch
        read -rp "New branch name: " new_branch
        if [[ -z "$new_branch" ]]; then
            echo "ghit branch: no branch name provided." >&2
            return 1
        fi

        git checkout -b "$new_branch"
        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo "ghit branch: failed to create branch '$new_branch'." >&2
            return $exit_code
        fi

        echo ""
        if _ghit_confirm "Push '$new_branch' to origin?"; then
            git push -u origin "$new_branch"
        fi

    elif [[ $rc -eq 0 ]]; then
        # == checkout existing branch ==========================================
        git checkout "$selected"
    else
        return $rc
    fi
}

_ghit_branchd() {
    local selected
    _ghit_select_branch selected "Select a branch to delete: "
    local rc=$?
    [[ $rc -ne 0 ]] && return $rc

    local current
    current=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$selected" == "$current" ]]; then
        echo "ghit branchd: cannot delete the currently checked-out branch '$selected'." >&2
        return 1
    fi

    # Try a safe delete first.
    git branch -d "$selected"
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "'$selected' is not fully merged."
        if _ghit_confirm "Force delete '$selected' with -D?"; then
            git branch -D "$selected"
            exit_code=$?
        else
            echo "Aborted."
            return $exit_code
        fi
    fi

    # Only offer remote deletion if the local delete succeeded.
    if [[ $exit_code -eq 0 ]]; then
        echo ""
        if _ghit_confirm "Also delete '$selected' from origin?"; then
            git push origin --delete "$selected"
        fi
    fi
}

_ghit_remote() {
    echo "Remotes:"
    local remotes
    remotes=$(git remote -v 2>/dev/null)
    if [[ -z "$remotes" ]]; then
        echo "  (none)"
    else
        # git remote -v prints two lines per remote (fetch + push); deduplicate
        # into a tidy name -> URL table.
        git remote -v | awk '
            !seen[$1]++ { printf "  %-20s %s\n", $1, $2 }
        '
    fi
    echo ""

    if _ghit_confirm "Add a new remote?"; then
        local name
        read -rp "Remote name: " name
        if [[ -z "$name" ]]; then
            echo "ghit remote: no name provided." >&2
            return 1
        fi

        local url
        read -rp "Remote URL: " url
        if [[ -z "$url" ]]; then
            echo "ghit remote: no URL provided." >&2
            return 1
        fi

        git remote add "$name" "$url"
        echo "Added remote '$name' -> $url"
    fi
}

_ghit_worktree() {
    # NOTE: for 'cd' to an existing worktree to affect the calling shell this
    # script must be sourced (e.g. via an alias: alias ghit='. ghit.sh').

    # Collect existing worktrees (skip the first line which is the main tree).
    local wt_lines=()
    while IFS= read -r line; do
        wt_lines+=("$line")
    done < <(git worktree list --porcelain 2>/dev/null | awk '
        /^worktree / { path=$2 }
        /^branch /   { branch=$2; printf "%s\t%s\n", path, branch }
        /^HEAD /     && !branch { printf "%s\t(detached)\n", path }
    ')

    if [[ ${#wt_lines[@]} -eq 0 ]]; then
        echo "ghit worktree: not inside a git repository." >&2
        return 1
    fi

    echo "Worktrees:"
    local i
    for i in "${!wt_lines[@]}"; do
        local wt_path wt_branch
        wt_path="${wt_lines[$i]%%$'\t'*}"
        wt_branch="${wt_lines[$i]##*$'\t'}"
        # Strip refs/heads/ prefix for display.
        wt_branch="${wt_branch#refs/heads/}"
        printf "  [%d] %-40s %s\n" "$((i + 1))" "$wt_path" "$wt_branch"
    done
    printf "  [n] create a new worktree\n"
    echo ""

    local choice
    read -rp "Select a worktree or 'n' to create one: " choice

    if [[ "$choice" == "n" || "$choice" == "N" ]]; then
        # == create a new worktree =============================================
        local wt_path
        _ghit_read_file "Path for new worktree: " wt_path required || return 1

        # Let the user pick an existing branch or name a new one.
        echo ""
        echo "  [1] use an existing branch"
        echo "  [2] create a new branch"
        echo ""
        local bc_choice
        read -rp "Branch for new worktree [1-2]: " bc_choice

        local wt_branch
        case "$bc_choice" in
            1)
                _ghit_select_branch wt_branch "Select a branch: "
                [[ $? -ne 0 ]] && return 1
                git worktree add "$wt_path" "$wt_branch"
                ;;
            2)
                read -rp "New branch name: " wt_branch
                if [[ -z "$wt_branch" ]]; then
                    echo "ghit worktree: no branch name provided." >&2
                    return 1
                fi
                git worktree add -b "$wt_branch" "$wt_path"
                ;;
            *)
                echo "ghit worktree: invalid choice." >&2
                return 1
                ;;
        esac

        local exit_code=$?
        if [[ $exit_code -ne 0 ]]; then
            echo "ghit worktree: failed to create worktree." >&2
            return $exit_code
        fi

        echo ""
        if _ghit_confirm "Change directory to new worktree '$wt_path'?"; then
            cd "$wt_path"
        fi

    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#wt_lines[@]} )); then
        # == cd to existing worktree ===========================================
        local dest
        dest="${wt_lines[$((choice - 1))]%%$'\t'*}"
        cd "$dest"
    else
        echo "ghit worktree: invalid selection." >&2
        return 1
    fi
}

# == main entry point =========================================================

ghit() {
    local action="$1"
    shift || true   # remaining args passed to sub-commands where applicable

    if [[ -z "$action" ]]; then
        _ghit_pick_action action
        if [[ -z "$action" ]]; then
            echo "ghit: no valid action selected." >&2
            return 1
        fi
    fi

    case "$action" in
        clone)    _ghit_clone    "$@" ;;
        pull)     _ghit_pull     "$@" ;;
        history)  _ghit_history  "$@" ;;
        rebase)   _ghit_rebase   "$@" ;;
        commit)   _ghit_commit   "$@" ;;
        branch)   _ghit_branch   "$@" ;;
        branchd)  _ghit_branchd  "$@" ;;
        remote)   _ghit_remote   "$@" ;;
        worktree) _ghit_worktree "$@" ;;
        *)
            echo "ghit: unknown action '$action'." >&2
            echo "Valid actions: ${actions[*]}" >&2
            return 1
            ;;
    esac
}

# When executed as a script (not sourced), invoke ghit and exit with its status.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    ghit "$@"
    exit $?
fi
