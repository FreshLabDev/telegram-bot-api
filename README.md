<h1 align="center">telegram-bot-api</h1>

<p align="center"><strong>The Telegram Bot API server, built by us from pinned sources.</strong><br/>One container holds the tokens of every bot on the host and sees all of their messages. This is where what goes into it is decided.</p>

<p align="center">
  <a href="https://core.telegram.org/bots/api"><img src="https://img.shields.io/badge/bot%20api-10.3-26A5E4?style=for-the-badge&labelColor=0f172a" alt="Bot API 10.3"></a>
  <a href="Dockerfile"><img src="https://img.shields.io/badge/base-alpine%203.24-0D597F?style=for-the-badge&logo=alpinelinux&logoColor=white&labelColor=0f172a" alt="alpine"></a>
  <a href="NOTICE"><img src="https://img.shields.io/badge/upstream-BSL--1.0-334155?style=for-the-badge&labelColor=0f172a" alt="upstream license"></a>
</p>

---

## Why this exists

The shared server on WS04 was a third-party image pinned by digest in July
2025 and never moved. It was still Bot API 7.11 in September 2026 — nearly two
years behind — and answered `404 method not found` to every method Telegram
had shipped since. A bot written against 10.3 went quiet for a day without
producing a single error that said so.

Nothing about that was the image maintainer's fault. A pin that nobody moves
rots whoever built it. What changed here is ownership: the sources are pinned
to an exact upstream commit, the build is a workflow anyone can read, and the
version the binary reports is checked against the version we think we pinned —
twice, once at build time and once against the pushed image.

## What is pinned

```
tdlib/telegram-bot-api  e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1   2026-08-25
  └─ td (submodule)     bc9c263e2bfee06aaab41e82db51a103376030bc
Bot API                 10.3
```

Both live in `Dockerfile` as build arguments. Changing `BOT_API_COMMIT`
without changing `EXPECTED_BOT_API` fails the build if the commit declares a
different version, so a bump cannot ship quietly under the old number.

## Running it

The server takes its credentials from the environment, never from arguments,
so they stay out of `ps` and out of every log line:

```sh
docker run --rm \
  -e TELEGRAM_API_ID -e TELEGRAM_API_HASH \
  -e TELEGRAM_LOCAL=1 \
  -v ./data:/var/lib/telegram-bot-api \
  ghcr.io/freshlabdev/telegram-bot-api@sha256:...
```

| Variable | Default | What it does |
| --- | --- | --- |
| `TELEGRAM_API_ID`, `TELEGRAM_API_HASH` | — | Required. From my.telegram.org |
| `TELEGRAM_LOCAL` | `0` | `1` enables local mode: no download size limit, uploads to 2000 MB, and `getFile` answers with an absolute path |
| `TELEGRAM_WORK_DIR` | `/var/lib/telegram-bot-api` | Working directory: one subdirectory per bot, named after that bot's token, holding its `td.binlog` |
| `TELEGRAM_FILES_DIR` | unset | Media directory (Bot API 10.3+). Set it to keep media out of the working directory |
| `TELEGRAM_TEMP_DIR` | `/tmp/telegram-bot-api` | Temporary files |
| `TELEGRAM_HTTP_PORT` | `8081` | API port |
| `TELEGRAM_STAT_PORT` | unset | Statistics port. Reports uptime, bot count and memory — **not** the Bot API version |
| `TELEGRAM_VERBOSITY` | unset (server default `0`) | Log level. The server's own default is FATAL-only, so it prints **nothing** — not even which Bot API version it started as. Set it to `1` (WARNING) unless you enjoy silence |
| `TELEGRAM_MAX_CONNECTIONS`, `TELEGRAM_MAX_WEBHOOK_CONNECTIONS`, `TELEGRAM_PROXY` | unset | Passed through |

The server binds as root and then drops to uid 101, so files it writes are
owned by `101:101`. A bot container that reads them should run as that uid —
and it must be able to delete them, because a local server never reclaims a
file it produced.

### Local mode and files

`--local` is why this server exists, and it changes two things a bot has to
handle:

- `getFile` returns an absolute path on the server's own filesystem, and the
  `/file/bot<token>/…` route answers 404. The directory has to be mounted; it
  is not a download.
- With `TELEGRAM_FILES_DIR` set, media lives there instead of in the working
  directory. Mount a bot `<files dir>/<its token>` and it gets its own media
  and nothing else — no session state, its own or anyone's.

Never mount the parent of either directory into a bot. Both hold one
subdirectory per bot, each named after that bot's full token.

## Moving a bot onto this server

A token is logged in on one server at a time; upstream is explicit that a bot
logged in on two has no guarantee of receiving all updates. So:

1. Stop the bot.
2. `logOut` on the server it is leaving.
3. Create its media directory here before it starts:
   `mkdir -p <files dir>/<token> && chown 101:101 <files dir>/<token>`. Docker
   would otherwise create the missing bind source as `root`, and then neither
   the server nor the bot could write in it.
4. Point it at this one and mount that directory.
5. Start it.

Leaving for `https://api.telegram.org` works the same way, with a ten-minute
cooldown before the cloud server accepts the token again.

## License

Our files are Apache-2.0. The server they build is Telegram's, under BSL-1.0,
fetched at build time — see [NOTICE](NOTICE).
