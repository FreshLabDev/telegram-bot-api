# Changelog

## Unreleased

## Bot API 10.3 - 2026-09-08

First FreshLab build.

- Built from `tdlib/telegram-bot-api@e3e9dd8` (2026-08-25), td submodule
  `bc9c263`, on Alpine 3.24. The version the sources declare is checked
  against the pin at build time, and the pushed image is run with `--version`
  to confirm it agrees.
- Credentials are read from the environment by the server itself, so they
  never appear in argv.
- `TELEGRAM_FILES_DIR` support (Bot API 10.3). Media can now live outside the
  working directory, which is what lets a bot be given its own media directory
  without any `td.binlog` — its own or another bot's — coming along with it.
- Published to `ghcr.io/freshlabdev/telegram-bot-api`, no `latest` tag:
  deployments pin a digest.
- The deployment sets `TELEGRAM_VERBOSITY=1`. The server's own default is 0,
  which is FATAL-only: it logs nothing at all, including the line that names
  the Bot API version it started as. A server that cannot say what it is, is
  how one ends up two years behind unnoticed.
