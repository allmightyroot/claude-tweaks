#!/bin/bash
# Claude Code status line: session name, current directory (+ git branch), model.
#
#   Glados │ claude-config (main) │ Opus 5.5
#
# The session name comes from ~/.claude/session-names/<session_id>, written by
# hooks/session-name.sh, so a rename shows up on the next refresh.
#
# Optional: export CLAUDE_SESSION_NAME_TMUX=1 to also name the tmux window
# after the session. Off by default because it overrides window names you set
# yourself, and other tmux session managers may want to own them.
#
# Requires: jq.

input=$(cat)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')

name=""
case "$session_id" in
  ""|*[!A-Za-z0-9_-]*) ;;
  *) [ -s "$HOME/.claude/session-names/$session_id" ] &&
       name=$(head -n 1 "$HOME/.claude/session-names/$session_id") ;;
esac

if [ -n "$name" ] && [ "${CLAUDE_SESSION_NAME_TMUX:-}" = 1 ] && [ -n "${TMUX_PANE:-}" ]; then
  current=$(command tmux display-message -p -t "$TMUX_PANE" '#W' 2>/dev/null)
  [ "$current" = "$name" ] || command tmux rename-window -t "$TMUX_PANE" "$name" 2>/dev/null
fi

# Bright, bold colors that stay readable on dark backgrounds.
bold_cyan=$'\033[1;96m'; yellow=$'\033[93m'; dim=$'\033[2m'; reset=$'\033[0m'
sep="${dim} │ ${reset}"

out=""
[ -n "$name" ] && out="${bold_cyan}${name}${reset}${sep}"
if [ -n "$dir" ]; then
  out="${out}${dir##*/}"
  branch=$(git -C "$dir" branch --show-current 2>/dev/null)
  [ -n "$branch" ] && out="${out} ${yellow}(${branch})${reset}"
fi
[ -n "$model" ] && out="${out}${sep}${model}"

printf '%s\n' "$out"
