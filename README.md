# claude-tweaks

Small, independent add-ons for Claude Code. Each one is a hook or status line
script that `install.sh` wires into `~/.claude/settings.json`.

## Install

Requires `jq`.

```
git clone <this repo> && cd claude-tweaks
./install.sh
```

Then start a new Claude Code session. Re-run `install.sh` after a `git pull` to
update. It backs up `settings.json` first, and leaves an existing status line
alone (with a notice) rather than replacing it.

## What's in it

### Session names

Gives each Claude Code session a short, memorable name (`Glados`, `Riften`,
`Chewie`...) and shows it in the status line, so with several sessions open at
once you can say "ask Glados" instead of "the one in the other repo".

```
Glados │ my-project (main) │ Opus 5.5
```

- `hooks/session-name.sh` - SessionStart hook. Picks a name not used by any
  session active in the past week and stores it in
  `~/.claude/session-names/<session_id>`, so it survives compaction and
  `--resume` (`/clear` starts a new session and gets a new name). It also tells
  Claude its own name, so you can ask a session who it is or ask it to rename
  itself.
- `statusline/statusline.sh` - status line showing `name │ dir (branch) │ model`.
  `export CLAUDE_SESSION_NAME_TMUX=1` to also name the tmux window after the
  session (off by default, since it overrides window names you set yourself).

To customize the names, edit the `NAMES` array in `hooks/session-name.sh` and
re-run `install.sh`. Avoid words you already use for hostnames or projects, or a
name becomes ambiguous when you say it.

## Uninstall

Delete the `session-name.sh` SessionStart entry and the `statusLine` entry from
`~/.claude/settings.json`, and remove `~/.claude/hooks/session-name.sh`,
`~/.claude/statusline.sh`, and `~/.claude/session-names/`.

## License

MIT - see [LICENSE](LICENSE).
