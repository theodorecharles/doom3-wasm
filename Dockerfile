# syntax=docker/dockerfile:1.7

FROM nginx:1.27-alpine

ARG VCS_REF=unknown
LABEL org.opencontainers.image.title="Doom 3 WASM" \
      org.opencontainers.image.description="Owner-data Doom 3 and RoE browser clients" \
      org.opencontainers.image.source="https://github.com/theodorecharles/doom3-wasm" \
      org.opencontainers.image.revision="$VCS_REF"

COPY build/web/ /usr/share/nginx/html/
COPY build/native/dhewm3 /opt/doom3/bin/dhewm3
COPY build/native/base.so /opt/doom3/bin/base.so
COPY build/native/d3xp.so /opt/doom3/bin/d3xp.so
COPY build/server/dhewm3ded /opt/doom3/bin/dhewm3ded
COPY build/server/base.so /opt/doom3/server/base.so
COPY build/server/d3xp.so /opt/doom3/server/d3xp.so
COPY COPYING.txt /usr/share/nginx/html/DHEWM3-COPYING.txt
COPY docker/nginx.conf /etc/nginx/conf.d/default.conf

RUN mkdir -p /data/base /data/d3xp /data/custom_maps /opt/doom3/bin /opt/doom3/server \
    && printf '%s\n' \
        'Corresponding source for this image:' \
        "https://github.com/theodorecharles/doom3-wasm/tree/${VCS_REF}" \
        'The image contains engine/runtime code only; supply proprietary Doom 3/RoE data through /data.' \
        > /usr/share/nginx/html/SOURCE-OFFER.txt \
    && chmod 0755 /opt/doom3/bin/dhewm3 /opt/doom3/bin/dhewm3ded

ENV HTTP_PORT=8088 \
    GAME_SLOTS=8 \
    KEEP_ALIVE=false \
    IDLE_TIMEOUT=15m \
    GAME_MODE=vanilla

VOLUME ["/data"]
EXPOSE 8088/tcp 27666/udp
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O - http://127.0.0.1:8088/health >/dev/null
