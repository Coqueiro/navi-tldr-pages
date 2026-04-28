# AGENTS.md — navi-tldr-pages

## Project Overview

Fork of [denisidoro/navi-tldr-pages](https://github.com/denisidoro/navi-tldr-pages) that converts [tldr-pages](https://github.com/tldr-pages/tldr) into [navi](https://github.com/denisidoro/navi) cheatsheets.

- Remote `origin`: `git@github.com:Coqueiro/navi-tldr-pages.git`
- Remote `denisidoro`: upstream
- Default branch: `master` (not `main`)

## Repository Structure

```
scripts/translate       # Converts tldr .md -> navi .cheat format
scripts/update-and-sync.sh  # Automated weekly update pipeline
tldr/                   # Full clone of tldr-pages/tldr (subdir, not submodule)
pages/                  # Generated .cheat files (committed, not gitignored)
personal_pages/common/  # Custom cheatsheets (airflow, syntax_test, etc.)
logs/                   # Runtime logs from update script (gitignored)
```

## Automation

Weekly updates run via a local macOS `launchd` agent.

- **Plist**: `~/Library/LaunchAgents/com.lucas.navi-tldr-update.plist`
- **Schedule**: Every Monday at 09:00
- **Script**: `scripts/update-and-sync.sh`

### What the update script does

1. `git pull --ff-only` in `tldr/` to get latest upstream pages
2. Runs `scripts/translate` to regenerate all `.cheat` files
3. Commits and pushes to `origin master` only if changes exist
4. Syncs `.cheat` files to navi's local cheats dir via direct file copy

### Managing the agent

```bash
# Reload after plist changes
launchctl unload ~/Library/LaunchAgents/com.lucas.navi-tldr-update.plist
launchctl load ~/Library/LaunchAgents/com.lucas.navi-tldr-update.plist

# Force a manual run
launchctl start com.lucas.navi-tldr-update

# Check status (second column = last exit code, 0 = success)
launchctl list | grep navi-tldr

# View logs
ls -lt logs/update-*.log | head -5
cat logs/launchd-stderr.log
```

## Known Gotchas

### `navi repo add` hangs in non-interactive contexts
`navi repo add` uses HTTPS clone internally and prompts for credentials when run non-interactively (launchd, cron). The update script bypasses this by directly copying `.cheat` files to navi's cheats directory.

### Navi cheat file naming convention
Navi expects flat filenames with `__` as path separator: `pages__common__tar.cheat`. The `sed 's|/|__|g'` transform handles this. Do not use `tr '/' '_'` — it produces single underscores.

### Navi cheats directory
`~/Library/Application Support/navi/cheats/Coqueiro__navi-tldr-pages/`

### `scripts/translate` printf format string
The `printf` on line 77 must use `%s` format, not inline variable expansion, because some tldr filenames (like `%.md`) are interpreted as printf format specifiers.

### `scripts/translate` regex escaping in `sanitize_variables`
The `sanitize_variables` function uses `sed` to replace `{{variable}}` placeholders with navi `<variable>` syntax. Variable names extracted from tldr pages can contain regex metacharacters (e.g. `[-c|--continue]`), which causes `sed` "RE error: invalid character range" if not escaped. The fix escapes `[][\/*.^$|` before the sed substitution. Without this, ~8,464 pages using the `{{[-flag|--long-flag]}}` pattern produce empty cheat files.

### `tldr/` is a plain clone, not a git submodule
`git pull --ff-only` inside `tldr/` is the correct update method. Do not use `git submodule update`.

## Build & Validation

No test suite. Validate changes by:

1. Running `scripts/translate` and checking exit code
2. Running `scripts/update-and-sync.sh` end-to-end
3. Verifying cheat files appear in navi: `navi --query "tar"` (or any common command)
