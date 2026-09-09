# Release Process

Every Asterfield repository releases the same way. This document is identical in
all of them; only the verification section is specific to telegram-bot-api.

See [`versioning.md`](versioning.md) for what the numbers mean. This repository
has no pre-release line, so every tag here is a release and every tag goes on
`main`.

## The changelog is the release notes

`CHANGELOG.md` is the source of truth for history, and the release workflow reads
it directly — the GitHub Release body is the `## <tag>` section, copied verbatim.
There is no second place to write release notes, and no step where the two can
disagree.

Which means the changelog has to be written for somebody else to read:

- Put unreleased changes under `## Unreleased`, in the section that fits:
  `Added`, `Changed`, `Fixed`, `Removed`, `Security`, `Breaking`,
  `Known Limitations`.
- Record what matters to a user, an operator, or the next person deciding
  whether to upgrade. Not every refactor.
- Say what changed and why it mattered, concretely. "Fixed a bug" tells nobody
  anything.
- Call out anything an operator must act on — a new or renamed environment
  variable, a migration, a changed deployment assumption — explicitly, in its
  own entry.
- Exactly one `## Unreleased` section, always at the top. Two of them means the
  next release renames the wrong one.

## Publishing a release

There is no pre-release line here. A release does not build anything: it names a
digest the build workflow already pushed and verified, so the proving happens
before the tag, with `deploy/probe.sh` against a server no real bot is on.

**Merge to `main` and push it before tagging.** GitHub runs a workflow from the
file present on the tagged ref, and `release.yml` lives on `dev` until that
merge. A tag pushed to `main` first would find no workflow there: the tag would
appear, no release would be created, no image tag would move, and nothing would
say so.

Then wait for the build that merge starts. Changing the Dockerfile or the build
workflow triggers one, and it takes up to two hours; the release resolves the
image by this repository's commit, so it refuses until that build has finished
rather than publishing the previous one.


A stable version is tagged on `main`, on the merge commit.

1. The build being promoted must already have been exercised with
   `deploy/probe.sh` against the probe bot. A real bot cannot be used for this:
   a token is logged in on exactly one server at a time, so moving one to test
   a build is a step that cannot be taken back.
2. On `dev`, rename `## Unreleased` to the stable version and push.
3. Merge into `main` with a merge commit, so the tag has something to sit on:

   ```sh
   git checkout main
   git merge --no-ff dev
   git push origin main
   ```

4. Tag the merge commit and push the tag:

   ```sh
   git tag -a v1.2.3 -m "v1.2.3"
   git push origin v1.2.3
   ```

5. Deploy it, and check the running version says what it should.

## Rolling back

Set `BOT_API_IMAGE` to the previous release's digest and bring the stack up
again. The digest is in that release's notes, and the image is still in GHCR.

Do not retag and do not delete a published release. A version that was published
is a fact about what existed, and every deployment that pinned its digest is a
record that would be made wrong by rewriting it.

## Deploying

The host is WS04. Every stack lives in `/opt/stacks/<stack>` and is driven by the
`ws04` CLI, which exists on the operator's machine and reaches the host over the
LAN. Nothing here is built on the host any more: a stack pulls the image the
release workflow published and runs that. If you find a `build:` section in a
production manifest, that is a bug, not a shortcut.

### One deploy

```sh
ws04 deploy telegram-bot-api-next --dry-run --yes    # prints what it would do, changes nothing
ws04 deploy telegram-bot-api-next --yes
```

`deploy` snapshots the stack's compose, env and image ids into
`/opt/stacks/.ws04/deploy-snapshots/telegram-bot-api-next/<timestamp>`, pulls, brings the stack
up, waits up to ninety seconds for the container to report healthy, and **rolls
back on its own** if it does not. The snapshot is kept either way.

### Pointing the stack at a version

The image is chosen by one variable in the stack's env file on the host, not by
anything in this repository:

```sh
BOT_API_IMAGE=ghcr.io/freshlabdev/telegram-bot-api@sha256:<digest>
```

Pin the **digest**, not the tag. A tag can be moved; a digest names one build
that was tested, so a rollback is one line with nothing to rebuild, and
`docker inspect` on the running container answers which commit it came from. The
digest of a release is in its GitHub Release notes. To read it off the host that
will run it, pull the tag once and ask the daemon:

```sh
docker pull ghcr.io/freshlabdev/telegram-bot-api:<tag>
docker inspect --format '{{index .RepoDigests 0}}' ghcr.io/freshlabdev/telegram-bot-api:<tag>
```

That first pull is not a formality. Deploying straight to
`ghcr.io/freshlabdev/telegram-bot-api@sha256:<digest>` on a host that has never fetched
the tag has answered `403` on a blob, and a single pull by tag cleared it every
time; the cause was never pinned down, so treat pull-then-pin as the recipe
rather than an optimisation. It also means the layers are already local when the
stack comes up.

Without a shell on the host, the API answers the same question:

```sh
gh api /orgs/FreshLabDev/packages/container/telegram-bot-api/versions \
  --jq '.[] | select(.metadata.container.tags[]? == "<tag>") | .name'
```

The variable has no default. An unset one stops the stack with a message naming
it, rather than quietly starting something else.

### Rolling back

Set `BOT_API_IMAGE` to the previous digest and deploy again. That is the whole
rollback — the images are still on the host, and nothing is rebuilt. Then publish
a patch that fixes what went wrong; never retag or delete the bad release.

### What this stack needs to exist

| | |
|:--|:--|
| Stack | `telegram-bot-api-next` — `/opt/stacks/telegram-bot-api-next` |
| Manifest | [`deploy/compose.yaml`](deploy/compose.yaml) in this repository |
| Env file | `.env` on the host, never in git |
| Networks | `telegram_bot_api_net`, where it also answers to the alias `telegram-bot-api` |

This container holds the token of every bot on the host and sees all of their
messages. A bot token is logged in on exactly one server at a time, so moving a
bot between servers is a one-way step: prove a build with `deploy/probe.sh` and
the probe bot first, never by pointing a real bot at it.

A release here re-tags a digest the build workflow already pushed and verified;
it never rebuilds. So deploying is always pinning a digest that has been run.

### Checking what is running

```sh
ws04 container list                    # health of everything
ws04 logs telegram-bot-api-next --since 1h
ws04 container inspect telegram-bot-api-next     # includes the image digest
```

The bot also reports its own version — from the About card in Telegram, and from
its health endpoint where it has one. Those two and `docker inspect` should
agree; if they do not, something was deployed by hand.

## Verification

```sh
sh -n entrypoint.sh
docker compose -f deploy/compose.yaml config
```

Before tagging, point `deploy/probe.sh` at the built server using the probe
bot — a bot that serves nothing, so it can be moved onto an untested server
without unplugging anything that works:

```sh
./deploy/probe.sh                                   # the default method set
./deploy/probe.sh http://other:8081 sendRichMessage # one method, another server
```

A bot token is logged in on exactly one server at a time, so moving a real bot
to test a build is a one-way step. Use the probe bot instead.
