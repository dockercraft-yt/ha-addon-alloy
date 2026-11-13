FROM grafana/alloy:v1.11.0
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq \
 && rm -rf /var/lib/apt/lists/*
COPY run.sh /run.sh
COPY default.alloy /default.alloy
RUN chmod +x /run.sh
ENTRYPOINT []
CMD ["/run.sh"]