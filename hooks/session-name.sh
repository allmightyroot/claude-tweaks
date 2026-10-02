#!/bin/bash
# SessionStart hook: give every Claude Code session a short, memorable name, so
# that with several sessions open at once you can say "ask Glados" instead of
# "the session in the other repo, the one doing the firewall thing".
#
# The name is stored per session in ~/.claude/session-names/<session_id>, so it
# survives compaction and `claude --resume`. The status line script reads the
# same file, and Claude renames itself (when asked) by rewriting that file.
# /clear starts a new session ID and therefore gets a new name.
#
# A newly assigned name is also set as the session title, which is the name
# other sessions use to message this one (local peers and Remote Control
# sessions on other machines alike), so "message Glados" just works.
#
# Each host prefers its own slice of NAMES (picked by hashing the hostname), so
# sessions on different machines rarely get the same name without needing any
# shared state. CLAUDE_SESSION_NAME_SLOTS (default 4) sets how many slices;
# set CLAUDE_SESSION_NAME_SLOT=0..SLOTS-1 per host to guarantee no overlap.
#
# Requires: jq. Portable to macOS's bash 3.2 (no shuf/mapfile/GNU stat).

NAMES_DIR="$HOME/.claude/session-names"

# Short, easy-to-type, and distinct from each other. Edit freely. Avoid words
# you already use for something else (hostnames, project names) or a session
# name becomes ambiguous the moment you say it.
NAMES=(
  # Skyrim (places, people, creatures)
  Riften Whiterun Dawnstar Markarth Solitude Falkreath Ivarstead Riverwood
  Morthal Windhelm Helgen Lydia Serana Esbern Brynjolf Cicero Kodlak
  Aela Farkas Vilkas Mjoll Barbas Nazeem Belethor Faendal Sanguine Meridia
  Azura Hircine Sovngarde Mudcrab Skeever Sweetroll Horker Spriggan Wabbajack
  # Addams Family
  Gomez Morticia Wednesday Pugsley Fester Lurch Thing Itt Grandmama
  # Star Wars
  Chopper Artoo Threepio Kaytoo Huyang Grogu Chewie Ewok Jawa Porg Hoth Endor
  Dagobah Kessel Jakku Ahsoka Hera Sabine Ezra Kanan Zeb Lando Wedge Ackbar
  Bossk Kyber Beskar Bantha Rancor Sarlacc Tauntaun Mynock
  # (In)famous AIs
  Glados Wheatley Murderbot Art Hal Jarvis Friday Ultron Edi Legion Cortana
  Data Lore Bishop Mother Kitt Bender Marvin Eddie Deepthought Shodan Tars
  Case Baymax Walle Eve Auto Samantha Ava Mike Gerty Joshua Colossus Robby
)

input=$(cat)
host=$(hostname -s 2>/dev/null || hostname)
session_id=$(printf '%s' "$input" | jq -r '.session_id // empty')
case "$session_id" in
  ""|*[!A-Za-z0-9_-]*) exit 0 ;;  # no ID, or one unsafe to use as a filename
esac

mkdir -p "$NAMES_DIR"
name_file="$NAMES_DIR/$session_id"

if [ -s "$name_file" ]; then
  name=$(head -n 1 "$name_file")
else
  # Prune names from sessions untouched for 30+ days, then avoid any name held
  # by a session active in the last week, so concurrent sessions never collide.
  find "$NAMES_DIR" -type f -mtime +30 -delete 2>/dev/null
  taken=" $(find "$NAMES_DIR" -type f -mtime -7 -exec head -n 1 {} \; 2>/dev/null | tr '\n' ' ') "

  slots=${CLAUDE_SESSION_NAME_SLOTS:-4}
  case "$slots" in ""|*[!0-9]*|0) slots=4 ;; esac
  slot=${CLAUDE_SESSION_NAME_SLOT:-$(( $(printf '%s' "$host" | cksum | cut -d' ' -f1) % slots ))}
  case "$slot" in ""|*[!0-9]*) slot=0 ;; esac

  # Free names in this host's slice first, then free names anywhere.
  mine=(); free=(); i=0
  for n in "${NAMES[@]}"; do
    case "$taken" in
      *" $n "*) ;;
      *) free+=("$n"); [ $((i % slots)) -eq $((slot % slots)) ] && mine+=("$n") ;;
    esac
    i=$((i + 1))
  done
  [ ${#mine[@]} -gt 0 ] && free=("${mine[@]}")
  [ ${#free[@]} -gt 0 ] || free=("${NAMES[@]}")  # all taken: allow a repeat
  name=${free[$((RANDOM % ${#free[@]}))]}
  printf '%s\n' "$name" > "$name_file"
  new_name=1
fi
touch "$name_file"  # mark active, so this name stays reserved while in use

# Set the title only for a new name, so a later /rename sticks across resume
# and compaction instead of being reset here.
jq -n --arg name "$name" --arg file "$name_file" --arg host "$host" \
  --argjson new "${new_name:-0}" '{
  systemMessage: ("Session name: " + $name),
  hookSpecificOutput: ({
    hookEventName: "SessionStart",
    additionalContext: (
      "This Claude Code session is named " + $name + ", running on host " + $host + ". The user often runs several Claude Code sessions at once, possibly on several machines, and uses these names to tell them apart.\n"
      + "- When the user asks your name, it is " + $name + ". Use it when referring to yourself to or about other sessions, and when naming owners in status tables.\n"
      + "- When the user refers to another session by a name, that is another Claude Code session, not a person.\n"
      + "- Other sessions message you by your session title, which starts out as " + $name + ". When another session asks who you are, reply with your name, host (" + $host + ") and working directory.\n"
      + "- If the user asks you to rename yourself, write just the new name (one word, one line) to " + $file + " - the status line picks it up right away - and ask the user to also run `/rename <new name>` so other sessions can message you by it. Do not rename yourself unprompted."
    )
  } + (if $new == 1 then {sessionTitle: $name} else {} end))
}'
