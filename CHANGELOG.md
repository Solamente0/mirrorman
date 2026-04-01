# Changelog

All notable changes to MirrorMan will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

---

## [1.0.0] — 2025-01-01

### Added
- Initial release of MirrorMan
- Support for Python (pip), Node.js (npm), Docker, Go, Rust (Cargo), Java (Maven), Ruby (RubyGems), Linux package managers
- Smart mirror speed scanner with real latency measurement
- DNS server latency scanner
- Permanent and temporary mirror configuration
- `mirrorman use` command for one-time mirror usage without system changes
- Custom mirror support via `mirrorman add`
- Shell alias installation (`mirrorman alias install`)
- Quick aliases: `pip-cn`, `npm-cn`, `go-cn`
- Beautiful standalone HTML web interface (RTL, Persian)
- PowerShell support for Windows
- JSON-based mirror database for easy updates
- Applied mirrors tracking in `~/.config/mirrorman/applied.json`
- Backup support for Cargo config
- jq + python3 dual-backend for JSON parsing

### Infrastructure
- `data/mirrors.json` — centralized mirror database
- `bin/mirrorman.sh` — main Bash script
- `bin/mirrorman.ps1` — Windows PowerShell script
- `web/index.html` — standalone web UI
- `README.md` — full documentation
- `CONTRIBUTING.md` — contribution guide

---

## [Unreleased]

### Planned
- `conda`/`mamba` support
- PHP Composer mirrors
- .NET NuGet mirrors
- Auto-update checker
- GitHub Actions CI
- Mirror health monitoring
