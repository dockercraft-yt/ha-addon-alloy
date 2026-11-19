FROM grafana/alloy:v1.22.0

ARG BUILD_ARCH
ARG BUILD_VERSION

LABEL \
  io.hass.name="Grafana Alloy" \
  io.hass.description="Grafana Alloy collector that ships Home Assistant, Supervisor and add-on logs to Loki" \
  io.hass.type="addon" \
  io.hass.arch="${BUILD_ARCH}" \
  io.hass.version="${BUILD_VERSION}" \
  org.opencontainers.image.source="https://github.com/dockercraft-yt/ha-addon-alloy" \
  org.opencontainers.image.licenses="MIT"

# Root is required to read the host journal mounted by the Supervisor.
USER root

RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
COPY default.alloy /default.alloy
RUN chmod +x /run.sh

ENTRYPOINT []
CMD ["/run.sh"]
