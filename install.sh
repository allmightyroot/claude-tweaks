#!/bin/bash
# Installs the session-name hook and status line into ~/.claude and wires them
# into ~/.claude/settings.json. Idempotent - safe to re-run after a `git pull`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
HOOKS_DEST="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"

command -v jq >/dev/null 2>&1 || {
  echo "jq is required (brew install jq / apt install jq)." >&2
  exit 1
}

mkdir -p "$HOOKS_DEST"

cp "$SCRIPT_DIR/hooks/session-name.sh" "$HOOKS_DEST/session-name.sh"
chmod +x "$HOOKS_DEST/session-name.sh"
echo "installed session-name.sh -> $HOOKS_DEST/session-name.sh"

cp "$SCRIPT_DIR/statusline/statusline.sh" "$CLAUDE_DIR/statusline.sh"
chmod +x "$CLAUDE_DIR/statusline.sh"
echo "installed statusline.sh -> $CLAUDE_DIR/statusline.sh"

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d%H%M%S)"

hook_cmd="bash $HOOKS_DEST/session-name.sh 2>/dev/null"
jq --arg cmd "$hook_cmd" '
  .hooks.SessionStart //= [] |
  if ([.hooks.SessionStart[].hooks[]?.command] | index($cmd)) then
    .
  else
    .hooks.SessionStart += [{"hooks":[{"type":"command","command":$cmd,"statusMessage":"Naming this session..."}]}]
  end
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# Status line: set it unless one is already configured that isn't ours - never
# silently replace a status line set up some other way.
statusline_cmd="bash $CLAUDE_DIR/statusline.sh"
current_statusline=$(jq -r '.statusLine.command // empty' "$SETTINGS")
if [ -z "$current_statusline" ] || [ "$current_statusline" = "$statusline_cmd" ]; then
  jq --arg cmd "$statusline_cmd" '.statusLine = {"type":"command","command":$cmd,"padding":0}' \
    "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
else
  echo "statusLine already set to '$current_statusline' - left alone." >&2
fi

echo "Done. Prior settings.json backed up alongside settings.json.bak-*."
echo "Start a new Claude Code session to pick up the hook."
