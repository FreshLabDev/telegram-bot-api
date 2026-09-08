#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
set -eu

# api_id and api_hash are read by the server straight from the environment, so
# they never appear in argv, in the process list, or in a log line.
if [ -z "${TELEGRAM_API_ID:-}" ] || [ -z "${TELEGRAM_API_HASH:-}" ]; then
	echo "TELEGRAM_API_ID and TELEGRAM_API_HASH are required (obtain them at https://my.telegram.org)" >&2
	exit 1
fi

work_dir="${TELEGRAM_WORK_DIR:-/var/lib/telegram-bot-api}"
temp_dir="${TELEGRAM_TEMP_DIR:-/tmp/telegram-bot-api}"
files_dir="${TELEGRAM_FILES_DIR:-}"

mkdir -p "$work_dir" "$temp_dir"
chown telegram-bot-api:telegram-bot-api "$work_dir" "$temp_dir"
if [ -n "$files_dir" ]; then
	mkdir -p "$files_dir"
	chown telegram-bot-api:telegram-bot-api "$files_dir"
fi

set -- --dir="$work_dir" --temp-dir="$temp_dir" \
	--http-port="${TELEGRAM_HTTP_PORT:-8081}" \
	--username=telegram-bot-api --groupname=telegram-bot-api

# In local mode the server hands over an absolute path from getFile and serves
# no files over HTTP. That is the mode that lifts the size limits.
if [ "${TELEGRAM_LOCAL:-0}" = "1" ] || [ "${TELEGRAM_LOCAL:-}" = "true" ]; then
	set -- "$@" --local
fi
# Keeping media out of the working directory means a bot can be given its own
# media directory without the binlogs that hold every bot's session.
if [ -n "$files_dir" ]; then
	set -- "$@" --files-dir="$files_dir"
fi
if [ -n "${TELEGRAM_STAT_PORT:-}" ]; then
	set -- "$@" --http-stat-port="$TELEGRAM_STAT_PORT"
fi
if [ -n "${TELEGRAM_VERBOSITY:-}" ]; then
	set -- "$@" --verbosity="$TELEGRAM_VERBOSITY"
fi
if [ -n "${TELEGRAM_MAX_CONNECTIONS:-}" ]; then
	set -- "$@" --max-connections="$TELEGRAM_MAX_CONNECTIONS"
fi
if [ -n "${TELEGRAM_MAX_WEBHOOK_CONNECTIONS:-}" ]; then
	set -- "$@" --max-webhook-connections="$TELEGRAM_MAX_WEBHOOK_CONNECTIONS"
fi
if [ -n "${TELEGRAM_PROXY:-}" ]; then
	set -- "$@" --proxy="$TELEGRAM_PROXY"
fi

# Safe to print: credentials are not in this list.
echo "starting: telegram-bot-api $*"
exec telegram-bot-api "$@"
