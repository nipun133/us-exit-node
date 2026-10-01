#!/bin/sh
# Minimal HTTP responder for Render's health checks / keep-alive pings.
# Invoked once per connection by socat (EXEC:/health.sh): stdin/stdout are the socket.
# Answer FIRST so the client always gets bytes even if the request never
# arrives, then drain the request head so our close is a clean FIN instead
# of an RST (which could discard the response).
printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'
while read -r _line && [ -n "$_line" ]; do :; done
exit 0
