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
