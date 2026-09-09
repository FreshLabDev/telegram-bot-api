# Versioning

The server's own version is Telegram's: `EXPECTED_BOT_API` in the Dockerfile,
checked at build time against what the pinned sources declare and again against
what the pushed image reports. This repository's versions have to say something
else -- which *build* of that server an operator is running -- because the
things this repository owns change independently of Telegram: the base image,
the entrypoint, the labels, the pinned upstream commit within one Bot API
version.

## Shape

```text
v<bot api>-<build>
```

```text
v10.3-1    first build of the Bot API 10.3 server
v10.3-2    same Bot API version, something here changed
v10.4-1    the pin moved to Bot API 10.4
```

The build number restarts at 1 whenever the Bot API version changes. It is not
a patch level: `v10.3-2` is not a fix for `v10.3-1`, it is a different build of
the same server, and the changelog section says what differs.

## Why a build number at all

The image is tagged `:10.3` and `:commit-<sha>` by the build workflow. Neither
is enough to roll back to. `:10.3` moves every time the server is rebuilt, and
`:commit-<sha>` names the *upstream* commit, which does not change when this
repository changes the base image or the entrypoint. Two builds that differ in
what they run can therefore carry the same two tags.

Deployments pin a digest, and a digest is exact -- but a digest is not a name
anyone can hold in their head or read in a changelog. The release tag is that
name, and its GitHub Release records the digest it stands for.

## Rules

- Every release is tagged on `main`.
- A tag's Bot API part must equal `EXPECTED_BOT_API` in the Dockerfile at that
  commit. The release workflow refuses the tag otherwise.
- Releases re-tag the image the build workflow already pushed and verified;
  they never rebuild it. A rebuild from the same sources is not guaranteed to
  produce the same bytes, and the point of the release is to name bytes that
  were tested.
- No `latest` tag, ever. One container holds every bot's token; what it runs is
  chosen deliberately or not at all.
