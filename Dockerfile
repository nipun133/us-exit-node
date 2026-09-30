FROM tailscale/tailscale:stable

# Tailscale exit node for Render's free tier.
# - tailscaled runs in userspace (netstack) mode: no /dev/net/tun, no NET_ADMIN
# - netstack mode can *serve* exit nodes (tailscale.com/docs/reference/kernel-vs-userspace-routers)
# - busybox httpd answers Render's health checks so the service comes up cleanly
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Render injects $PORT at runtime; default kept for local testing
ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/entrypoint.sh"]
