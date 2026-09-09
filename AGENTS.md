# AGENTS.md

This repository builds the Bot API server that every Asterfield bot talks to.
It holds their tokens and sees their messages. Treat changes accordingly.

## Rules

- Pin upstream by commit SHA, never by tag or branch. `BOT_API_COMMIT` and
  `EXPECTED_BOT_API` change in the same commit, and the build fails if the
  pinned sources declare a different version.
- Credentials come from the environment. Never pass `--api-id` or `--api-hash`
  as arguments: argv is visible in `ps` and in crash output.
- The entrypoint may print its argument list. Anything secret must therefore
  never become an argument.
- Do not add packages to the runtime image beyond what the binary links
  against. It is a network-facing process with every bot's credentials.
- No `latest` tag. Deployments pin a digest.

## Verification

```sh
sh -n entrypoint.sh
docker build -t telegram-bot-api:test .
docker run --rm --entrypoint telegram-bot-api telegram-bot-api:test --version
```

The last one must print the version in `EXPECTED_BOT_API`. CI runs the same
check against the pushed image.

## Upgrading

1. Read what changed upstream since the pinned commit.
2. Bump both build arguments, run the build, note the digest.
3. Deploy to the parallel stack first and probe it with a real bot before any
   other bot is moved onto it.

## Versioning

- This repository's versions are `v<bot api>-<build>`, not `1.2.3`; the first
  half is Telegram's and is verified, not chosen. See `docs/versioning.md`.
- Tags go on `main`. There is no pre-release line here: a release re-tags a
  digest the build workflow already pushed and verified, it never rebuilds.
- Prove a build with `deploy/probe.sh` and the probe bot before tagging. A
  token is logged in on one server at a time, so moving a real bot to test a
  build is a one-way step.

## Deploying

Do not invent a deploy. [`docs/releases.md`](docs/releases.md) has a **Deploying**
section describing this stack exactly: which host directory it lives in, which
env file names the image, which networks it needs, and how to roll back. Read it
before touching anything on the host.

Two rules that hold everywhere and are easy to get wrong:

- **Nothing is built on the host.** A production stack pulls the image the
  release workflow published. A `build:` section in a production manifest is a
  bug.
- **Pin the digest, not the tag.** A tag moves; a digest names one build that was
  tested, and a rollback becomes one line with nothing to rebuild.
