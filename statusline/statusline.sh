#!/bin/bash
# Claude Code status line: session name, host (over SSH), current directory
# (+ git branch and state), model, context window, and plan usage.
#
#   Glados@odahviing │ claude-config (main* ↑2) │ Opus 5.5 │ ctx 62% │ Usage: 5h 23% (2h10m) 7d 41% (3d4h)
#
# Git state: * = uncommitted changes, ↑N = commits not yet pushed to upstream,
# ↓N = commits upstream that you haven't pulled.
# Usage is the same 5-hour / 7-day plan limits that /usage shows, with the time
# until each resets in parentheses. Colors go green / yellow / red at 50% / 80%.
#
# Host: shown when the session runs over SSH. Set CLAUDE_STATUSLINE_HOST=always
# to show it everywhere, or =never to hide it.
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
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty | floor')
# Rate limits are only sent for Claude.ai subscribers, after the first API response.
five_h=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor')
five_h_reset=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty | floor')
seven_d=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty | floor')
seven_d_reset=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty | floor')

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
green=$'\033[92m'; red=$'\033[91m'
sep="${dim} │ ${reset}"

# pct_color PERCENT -> green < 50, yellow < 80, else red.
pct_color() {
  if [ "$1" -ge 80 ]; then printf '%s' "$red"
  elif [ "$1" -ge 50 ]; then printf '%s' "$yellow"
  else printf '%s' "$green"; fi
}

# until_reset EPOCH -> "2h10m", "3d4h", "45m"; empty if unknown or past.
until_reset() {
  [ -n "$1" ] || return 0
  local s=$(( $1 - $(date +%s) ))
  [ "$s" -gt 0 ] || return 0
  local d=$(( s / 86400 )) h=$(( s % 86400 / 3600 )) m=$(( s % 3600 / 60 ))
  if [ "$d" -gt 0 ]; then printf '%sd%sh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then printf '%sh%sm' "$h" "$m"
  else printf '%sm' "$m"; fi
}

# usage_part LABEL PERCENT RESET_EPOCH -> "5h 23% (2h10m)"
usage_part() {
  local left; left=$(until_reset "$3")
  printf '%s %s%s%%%s' "$1" "$(pct_color "$2")" "$2" "$reset"
  [ -n "$left" ] && printf ' %s(%s)%s' "$dim" "$left" "$reset"
}

out=""
[ -n "$name" ] && out="${bold_cyan}${name}${reset}"

case "${CLAUDE_STATUSLINE_HOST:-ssh}" in
  always) show_host=1 ;;
  never)  show_host= ;;
  *)      show_host=${SSH_CONNECTION:+1} ;;
esac
[ -n "$show_host" ] && out="${out}${dim}@$(hostname -s)${reset}"
[ -n "$out" ] && out="${out}${sep}"

if [ -n "$dir" ]; then
  out="${out}${dir##*/}"
  # One git call: branch, ahead/behind upstream, and whether the tree is dirty.
  gs=$(git --no-optional-locks -C "$dir" status --porcelain=v2 --branch 2>/dev/null)
  branch=$(printf '%s\n' "$gs" | sed -n 's/^# branch.head //p')
  if [ -n "$branch" ]; then
    [ "$branch" = "(detached)" ] && branch="detached"
    state=""
    printf '%s\n' "$gs" | grep -qv '^#' && state="*"
    ab=$(printf '%s\n' "$gs" | sed -n 's/^# branch.ab //p')
    ahead=${ab%% *}; ahead=${ahead#+}
    behind=${ab##* }; behind=${behind#-}
    [ "${ahead:-0}" -gt 0 ] && state="${state} ↑${ahead}"
    [ "${behind:-0}" -gt 0 ] && state="${state} ↓${behind}"
    out="${out} ${yellow}(${branch}${state})${reset}"
  fi
fi
[ -n "$model" ] && out="${out}${sep}${model}"

if [ -n "$ctx" ]; then
  out="${out}${sep}ctx $(pct_color "$ctx")${ctx}%${reset}"
fi

usage=""
[ -n "$five_h" ] && usage=$(usage_part 5h "$five_h" "$five_h_reset")
[ -n "$seven_d" ] && usage="${usage:+$usage }$(usage_part 7d "$seven_d" "$seven_d_reset")"
[ -n "$usage" ] && out="${out}${sep}Usage: ${usage}"

printf '%s\n' "$out"
