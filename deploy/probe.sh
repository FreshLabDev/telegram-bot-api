#!/usr/bin/env bash
# Ask a Bot API server which methods it implements, using a bot that serves
# nothing.
#
# The server answers nothing without a valid token: an invalid one gets 401 for
# every method, including ones that do not exist. So this needs a real token,
# and the whole point of the probe bot is that it is not a real bot -- it can
# be pointed at an untested server without unplugging anything that works.
#
#   ./probe.sh [base-url] [method ...]
#
# An existing method rejects an empty body on its parameters; a missing one
# answers "method not found". Every method asked for here must therefore be one
# that cannot act on an empty body -- never getMe, deleteWebhook or logOut.
#
# Exit status is 0 only when every method asked for is present.
set -euo pipefail

STACK="$(cd "$(dirname "$0")" && pwd)"
BASE="${1:-http://telegram-bot-api-next:8081}"
shift || true
METHODS=("$@")
if [ ${#METHODS[@]} -eq 0 ]; then
  METHODS=(sendMessage sendPhoto sendRichMessage editMessageText editEphemeralMessageText deleteEphemeralMessage answerCallbackQuery answerInlineQuery getFile)
fi

TOKEN="$(grep -E '^PROBE_BOT_TOKEN=' "$STACK/.env" | cut -d= -f2-)"
[ -n "$TOKEN" ] || { echo "PROBE_BOT_TOKEN missing from $STACK/.env" >&2; exit 1; }

# -i matters: without it the container gets no stdin and python reads nothing.
docker run --rm -i --network telegram_bot_api_net \
  -e BASE="$BASE" -e TOKEN="$TOKEN" -e METHODS="${METHODS[*]}" \
  python:3.13-alpine python - <<'PY'
import json, os, urllib.request, urllib.error

base = os.environ["BASE"].rstrip("/") + "/bot" + os.environ["TOKEN"] + "/"
missing, present, unknown = [], [], []
for method in os.environ["METHODS"].split():
    req = urllib.request.Request(base + method, data=b"{}",
                                 headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=15)
        present.append(method)  # accepted an empty body, so it exists
    except urllib.error.HTTPError as e:
        body = json.loads(e.read().decode() or "{}")
        description = (body.get("description") or "").lower()
        if e.code == 404 and "method not found" in description:
            missing.append(method)
        elif e.code in (401, 403):
            # An answer about the caller, not about the method.
            unknown.append((method, body.get("description")))
        else:
            present.append(method)
    except Exception as exc:
        unknown.append((method, type(exc).__name__))

for m in present:
    print(f"  present  {m}")
for m in missing:
    print(f"  MISSING  {m}")
for m, why in unknown:
    print(f"  unknown  {m}  ({why})")
print()
print("verdict:", "MISSING METHODS" if missing else ("INCONCLUSIVE" if unknown else "ok"))
raise SystemExit(1 if missing or unknown else 0)
PY
