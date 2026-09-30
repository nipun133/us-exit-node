#!/bin/sh
# Tailscale exit-node container for Render free web service.
# Required env: TS_AUTHKEY  (reusable, ephemeral auth key from the Tailscale admin console)
# Optional env: TS_HOSTNAME (default: us-exit), PORT (default: 8080)
set -eu

HEALTH_PORT="${PORT:-8080}"
TS_HOST="${TS_HOSTNAME:-us-exit}"
SOCK="/var/run/tailscale/tailscaled.sock"

log() { echo "[entrypoint] $*"; }

start_health_server() {
  # Read the request head first (avoids RST-truncated responses), then answer 200.
  socat TCP-LISTEN:"${HEALTH_PORT}",fork,reuseaddr SYSTEM:'read -r _; while read -r _ && [ -n "$_" ]; do :; done; printf "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok"' &
  echo $!
}

# --- health server ----------------------------------------------------------
mkdir -p /www
HEALTH_PID=$(start_health_server)
log "health server listening on :${HEALTH_PORT} (pid ${HEALTH_PID})"

# --- tailscaled (userspace / netstack mode) ---------------------------------
mkdir -p /var/lib/tailscale /var/run/tailscale
tailscaled --tun=userspace-networking --socket="${SOCK}" --state=/var/lib/tailscale/tailscaled.state &
TS_PID=$!
log "tailscaled starting (pid ${TS_PID})"

# Wait until the daemon actually answers (90s max).
i=0
until tailscale status --json 2>/dev/null | grep -q '"BackendState"'; do
  i=$((i + 1))
  if [ "$i" -ge 90 ]; then
    log "ERROR: tailscaled not ready after 90s"
    exit 1
  fi
  sleep 1
done
log "tailscaled is ready"

# --- log in & advertise the exit node ---------------------------------------
if ! tailscale up \
      --auth-key="${TS_AUTHKEY:?TS_AUTHKEY env var is required}" \
      --hostname="${TS_HOST}" \
      --advertise-exit-node \
      --accept-dns=false \
      --timeout=3m; then
  # tailscale up fails if preferences already match persisted state; set works then
  log "tailscale up returned non-zero, falling back to tailscale set"
  tailscale set --hostname="${TS_HOST}" --advertise-exit-node
fi
log "advertising exit node as '${TS_HOST}'"
tailscale status || true

# --- supervise ---------------------------------------------------------------
# Health server death is non-fatal (restart it) — the exit node is the real job.
# tailscaled death is fatal: exit so Render restarts the container; the reusable
# auth key re-registers the node and the ACL auto-approver re-approves it.
while :; do
  sleep 20
  if ! kill -0 "$HEALTH_PID" 2>/dev/null; then
    log "health server exited; restarting it"
    HEALTH_PID=$(start_health_server)
    log "health server back on :${HEALTH_PORT} (pid ${HEALTH_PID})"
  fi
  kill -0 "$TS_PID" 2>/dev/null || { log "tailscaled died"; exit 1; }
  tailscale status --json 2>/dev/null | grep -q '"BackendState"' \
    || { log "tailscale daemon not answering"; exit 1; }
done
