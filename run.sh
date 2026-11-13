#!/bin/sh
OPTS=/data/options.json
USERCONF=/config
RUNDIR=/tmp/alloy

LOKI_HOST=$(jq -r '.loki_host // empty' "$OPTS")
LOKI_PORT=$(jq -r '.loki_port // empty' "$OPTS")
USE_HTTPS=$(jq -r '.use_https // false' "$OPTS")
USE_AUTH=$(jq -r '.use_basic_auth // false' "$OPTS")
LOKI_USER=$(jq -r '.loki_user // empty' "$OPTS")
LOKI_PASSWORD=$(jq -r '.loki_password // empty' "$OPTS")

if [ -z "$LOKI_HOST" ] || [ -z "$LOKI_PORT" ]; then
  echo "FEHLER: loki_host oder loki_port fehlt in der Add-on-Konfiguration"
  exit 1
fi

if [ "$USE_AUTH" = "true" ] && { [ -z "$LOKI_USER" ] || [ -z "$LOKI_PASSWORD" ]; }; then
  echo "FEHLER: Basic Auth ist aktiv, aber Benutzer oder Passwort fehlt"
  exit 1
fi

SCHEME=http
[ "$USE_HTTPS" = "true" ] && SCHEME=https

export LOKI_URL="${SCHEME}://${LOKI_HOST}:${LOKI_PORT}/loki/api/v1/push"
export LOKI_USER LOKI_PASSWORD

echo "Sende Logs an ${LOKI_URL}"
if [ "$USE_AUTH" = "true" ]; then
  echo "Basic Auth: aktiv (Benutzer: ${LOKI_USER})"
else
  echo "Basic Auth: aus"
fi

# Beim ersten Start Default-Config anlegen
[ -f "$USERCONF/config.alloy" ] || cp /default.alloy "$USERCONF/config.alloy"

# Laufzeit-Verzeichnis: Nutzer-Configs + generierter loki.write-Block
rm -rf "$RUNDIR" && mkdir -p "$RUNDIR"
cp "$USERCONF"/*.alloy "$RUNDIR"/

{
  echo 'loki.write "default" {'
  echo '  endpoint {'
  echo '    url = sys.env("LOKI_URL")'
  if [ "$USE_AUTH" = "true" ]; then
    echo '    basic_auth {'
    echo '      username = sys.env("LOKI_USER")'
    echo '      password = sys.env("LOKI_PASSWORD")'
    echo '    }'
  fi
  echo '  }'
  echo '}'
} > "$RUNDIR/loki-write.generated.alloy"

exec /bin/alloy run \
  --server.http.listen-addr=0.0.0.0:12345 \
  --storage.path=/data/alloy \
  "$RUNDIR"