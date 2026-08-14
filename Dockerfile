# syntax=docker/dockerfile:1.7

ARG FRAMEWORK_IMAGE=wasm-game-framework:0.7.0
FROM ${FRAMEWORK_IMAGE}

ARG VCS_REF=unknown
LABEL org.opencontainers.image.title="Doom 3 WASM" \
      org.opencontainers.image.description="Owner-data Doom 3 and RoE browser clients" \
      org.opencontainers.image.source="https://github.com/theodorecharles/doom3-wasm" \
      org.opencontainers.image.revision="$VCS_REF"

COPY build/web/ /opt/game-site/
COPY COPYING.txt /opt/game-site/DHEWM3-COPYING.txt

RUN mkdir -p /data/base /data/d3xp /data/custom_maps \
    && printf '%s\n' \
        'Corresponding source for this image:' \
        "https://github.com/theodorecharles/doom3-wasm/tree/${VCS_REF}" \
        'The image contains engine/runtime code only; supply proprietary Doom 3/RoE data through /data.' \
        > /opt/game-site/SOURCE-OFFER.txt

ENV WASM_GAME_VARIANT=suite

VOLUME ["/data"]
EXPOSE 8088/tcp
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -q -O - http://127.0.0.1:8088/ >/dev/null
