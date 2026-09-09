# Changelog

All notable telegram-bot-api changes are documented here.

The `## <tag>` section of this file *is* the GitHub Release body: the release
workflow copies it verbatim and refuses a tag that has no section. Write it
for whoever has to decide whether to upgrade.

See [`docs/versioning.md`](docs/versioning.md) for what the numbers mean and
[`docs/releases.md`](docs/releases.md) for how a release is published.

## Unreleased

### Changed

- One versioning and release document for the whole family. `docs/versioning.md`
  and `docs/releases.md` are now byte-identical across every Asterfield
  repository apart from two clearly marked sections: this repository's own
  version line, and the surface where a change here breaks something. They spell
  out what each of the three numbers means, what the `-alpha.N` suffix counts,
  when alpha becomes beta and when it is legitimate to skip to rc or run a
  pre-release in production.
- The document explains why this repository does not use `1.2.3` — the server's
  version is Telegram's and is verified rather than chosen — and how
  `v<bot api>-<build>` maps onto the shared rules. The branch rule is the same
  as everywhere else.

### Added

- `docs/releases.md` gained a **Deploying** section, and `AGENTS.md` points at it.
  Releasing was documented; deploying was not, in any repository in the family —
  the process stopped at "deploy it" and never said how. That gap mattered more
  after the stacks moved from building on the host to pulling a published image,
  because the procedure changed on the same day. The section names this stack's
  host directory, its env file, the variable that selects the image, the networks
  it needs, and what a rollback actually is.

- A version line of this repository's own, `v<bot api>-<build>`, and the
  release workflow that publishes it. The image carried `:10.3` and
  `:commit-<sha>`, and neither is something to roll back to: the first moves on
  every rebuild, and the second names the upstream commit, which does not change
  when the base image or the entrypoint here does. Two builds that run
  differently could carry both. A release re-tags the digest the build workflow
  already pushed and verified -- it never rebuilds, because a rebuild is not
  guaranteed to produce the same bytes and the point is to name bytes that were
  tested. See [`docs/versioning.md`](docs/versioning.md).

- `deploy/probe.sh`, which asks a server which methods it implements using a bot
  that serves nothing. A server answers nothing without a valid token, so until
  now the only way to test one was to move a real bot onto it -- and moving a
  bot means logging it out of the server it leaves, which is a one-way step.
- A weekly drift check. The pin does not move on its own -- that is the point
  of a pin, and it is also how the previous server sat on Bot API 7.11 for two
  years. The job compares the pinned version against upstream's sources and
  against what Telegram has published, and opens an issue when they disagree.

## v10.3-1 - 2026-09-08

First Asterfield build. Bot API 10.3.

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
