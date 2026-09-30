FROM tailscale/tailscale:stable

# Tailscale exit node for Render's free tier.
# - tailscaled runs in userspace (netstack) mode: no /dev/net/tun, no NET_ADMIN
# - netstack mode can *serve* exit nodes (tailscale.com/docs/reference/kernel-vs-userspace-routers)
# - socat answers Render's health checks and keep-alive pings on $PORT
#   (the tailscale image's busybox lacks the httpd applet — do NOT use it)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh \
 && { command -v socat >/dev/null 2>&1 || apk add --no-cache socat; }

# Render injects $PORT at runtime; default kept for local testing
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
