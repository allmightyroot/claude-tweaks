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

  free=()
  for n in "${NAMES[@]}"; do
    case "$taken" in *" $n "*) ;; *) free+=("$n") ;; esac
  done
  [ ${#free[@]} -gt 0 ] || free=("${NAMES[@]}")  # all taken: allow a repeat
  name=${free[$((RANDOM % ${#free[@]}))]}
  printf '%s\n' "$name" > "$name_file"
fi
touch "$name_file"  # mark active, so this name stays reserved while in use

jq -n --arg name "$name" --arg file "$name_file" '{
  systemMessage: ("Session name: " + $name),
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: (
      "This Claude Code session is named " + $name + ". The user often runs several Claude Code sessions at once and uses these names to tell them apart.\n"
      + "- When the user asks your name, it is " + $name + ". Use it when referring to yourself to or about other sessions, and when naming owners in status tables.\n"
      + "- When the user refers to another session by a name, that is another Claude Code session, not a person.\n"
      + "- If the user asks you to rename yourself, write just the new name (one word, one line) to " + $file + " - the status line picks it up right away. Do not rename yourself unprompted."
    )
  }
}'
