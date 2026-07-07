# Changelog

All notable changes, reconstructed from git history on 2026-06-16 (no prior changelog existed). Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## 2026-07-07

### Added
- Linux/WSL support for the companion toolstack. `install.sh` gained a dependency preflight (`jq`/`git`/`python3`) with an OS-aware install hint, and creates `~/.claude` before writing settings. README documents platform support + requirements.

### Changed
- `launchd/install.sh` detects non-macOS hosts (Linux/WSL) and skips cleanly instead of crashing on `launchctl` — the launchd fleet stays macOS-only. It also `sed`-substitutes the hardcoded `/Users/kayla` in each plist for the current user's `$HOME` on deploy (closes the long-standing "needs a sed pass" gap, portable across mac accounts).
- `launchd/bin/health-check.sh`: guard the `launchctl list` block behind a `command -v` check (no-ops on non-macOS).
- `launchd/bin/memory-keeper-backup.sh`: `$HOME`-relative error-log path in the failure trap instead of hardcoded `/Users/kayla`.

## 2026-05-21

### Changed
- `update-meeting-cache`: bump fallback-summary truncation 25 → 50 chars (da572fa).

## 2026-05-14

### Changed
- launchd migration: finish the `~/Desktop/personal` cron → launchd move (1f36169).
- Migrate `validate-workspace-structure` from cron (a5175f8); migrate `cleanup-stale-artifacts` + `auto-organize-screengrabs` (29471ca); add `stale-git-lock-cleanup` + backfill `sync-claude-stack-cron` / `update-meeting-cache` (5b2be9a).
- gitignore `__pycache__` (3dec743).

## 2026-05-13

### Added
- Real-time notifications + new helpers: push-guard, health-check, pr-touches-atom (2d61c13).
- Wrapper scripts + plists captured from `~/.local/bin` + `~/Library/LaunchAgents` (6b3de9c).

## 2026-05-06

### Changed
- Update README + repo description (bc6e004).

### Fixed
- List-aware `deep_merge` + manifest accuracy (9325897).
- Security: jq filter injection, mktemp race, and type validation (36fbc79).

#### Initial
- `claude-setup` stub repo (e5c4f45).
