# Changelog

## Unreleased

### Added

- `deploy/probe.sh`, which asks a server which methods it implements using a bot
  that serves nothing. A server answers nothing without a valid token, so until
  now the only way to test one was to move a real bot onto it -- and moving a
  bot means logging it out of the server it leaves, which is a one-way step.
- A weekly drift check. The pin does not move on its own -- that is the point
  of a pin, and it is also how the previous server sat on Bot API 7.11 for two
  years. The job compares the pinned version against upstream's sources and
  against what Telegram has published, and opens an issue when they disagree.

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
- The deployment sets `TELEGRAM_VERBOSITY=1`, so the server at least reports
  its own errors; its default of 0 is FATAL-only and says nothing even when
  failing. The startup banner naming the Bot API version needs level 2, which
  also logs CPU usage every second, so the version is exposed as an image
  label instead — a server that cannot say what it is, is how one ends up two
  years behind unnoticed.
