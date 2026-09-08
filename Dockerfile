# SPDX-License-Identifier: Apache-2.0
# Telegram Bot API server, built from tdlib/telegram-bot-api sources.
#
# Pinned to an exact upstream commit, not a tag or a branch: this image runs
# with the tokens of every bot on the host and sees all of their messages, so
# what goes into it is decided here and nowhere else. The td submodule is
# pinned transitively by that commit.
ARG ALPINE_VERSION=3.24

FROM alpine:${ALPINE_VERSION} AS build

# Upstream commit. Bump deliberately, together with EXPECTED_BOT_API below.
ARG BOT_API_COMMIT=e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1
# Bot API version that commit declares. The build fails if the two disagree,
# so an unnoticed bump cannot ship under the old version number.
ARG EXPECTED_BOT_API=10.3
# TDLib compilation is memory-hungry: roughly 1.5-2 GB per job. Four fits a
# 16 GB runner; lower it on a smaller machine.
ARG BUILD_JOBS=4

RUN apk add --no-cache alpine-sdk linux-headers git cmake gperf zlib-dev openssl-dev

WORKDIR /src
RUN git clone https://github.com/tdlib/telegram-bot-api.git . \
 && git checkout --detach "${BOT_API_COMMIT}" \
 && git submodule update --init --recursive \
 && echo "telegram-bot-api $(git rev-parse HEAD)" \
 && echo "td              $(git -C td rev-parse HEAD)"

RUN declared=$(grep -oE 'version_ = "[0-9]+\.[0-9]+"' telegram-bot-api/telegram-bot-api.cpp | grep -oE '[0-9]+\.[0-9]+') \
 && if [ "$declared" != "${EXPECTED_BOT_API}" ]; then \
      echo "pinned commit declares Bot API $declared, expected ${EXPECTED_BOT_API}"; exit 1; \
    fi \
 && echo "Bot API $declared"

RUN cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=/out \
 && cmake --build build --target install -j "${BUILD_JOBS}" \
 && strip /out/bin/telegram-bot-api

FROM alpine:${ALPINE_VERSION}

ARG BOT_API_COMMIT
ARG EXPECTED_BOT_API
LABEL org.opencontainers.image.title="telegram-bot-api" \
      org.opencontainers.image.description="Telegram Bot API server built from pinned tdlib sources" \
      org.opencontainers.image.source="https://github.com/FreshLabDev/telegram-bot-api" \
      org.opencontainers.image.licenses="BSL-1.0" \
      org.opencontainers.image.version="${EXPECTED_BOT_API}" \
      org.freshlab.upstream.commit="${BOT_API_COMMIT}"

RUN apk add --no-cache openssl libstdc++ \
 && addgroup -g 101 -S telegram-bot-api \
 && adduser -S -D -H -u 101 -G telegram-bot-api -s /sbin/nologin telegram-bot-api

COPY --from=build /out/bin/telegram-bot-api /usr/local/bin/telegram-bot-api
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# The server drops privileges to uid 101 itself, after binding, so files it
# writes are owned by 101 and a bot container running as that uid can read
# them — and delete them, which a --local server never does on its own.
ENV TELEGRAM_WORK_DIR=/var/lib/telegram-bot-api \
    TELEGRAM_TEMP_DIR=/tmp/telegram-bot-api

EXPOSE 8081/tcp 8082/tcp
ENTRYPOINT ["/entrypoint.sh"]
