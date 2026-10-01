#!/bin/sh
# Minimal HTTP responder for Render's health checks / keep-alive pings.
# Invoked once per connection by socat (EXEC:/health.sh): stdin/stdout are the socket.
# Read the request head first (so the client's data is drained before we close,
# avoiding RST-truncated responses), then answer one small 200 response.
read -r _request || exit 0
while read -r _line && [ -n "$_line" ]; do :; done
printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok'
exit 0
