# Changelog

All notable changes, reconstructed from git history on 2026-06-16 (no prior changelog existed). Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

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
