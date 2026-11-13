#!/bin/sh
set -eu

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
  echo "ERROR: loki_host or loki_port is missing in the add-on configuration"
  exit 1
fi

if [ "$USE_AUTH" = "true" ] && { [ -z "$LOKI_USER" ] || [ -z "$LOKI_PASSWORD" ]; }; then
  echo "ERROR: Basic auth is enabled, but username or password is missing"
  exit 1
fi

SCHEME=http
[ "$USE_HTTPS" = "true" ] && SCHEME=https

export LOKI_URL="${SCHEME}://${LOKI_HOST}:${LOKI_PORT}/loki/api/v1/push"
export LOKI_USER LOKI_PASSWORD

echo "Sending logs to ${LOKI_URL}"
if [ "$USE_AUTH" = "true" ]; then
  echo "Basic auth: enabled (user: ${LOKI_USER})"
else
  echo "Basic auth: disabled"
fi

# Create the default config on first start
if [ ! -f "$USERCONF/config.alloy" ]; then
  if ! cp /default.alloy "$USERCONF/config.alloy"; then
    echo "ERROR: Failed to create the default Alloy config in $USERCONF" >&2
    exit 1
  fi
fi

# Runtime directory: user configs + generated loki.write block
if ! rm -rf "$RUNDIR"; then
  echo "ERROR: Failed to clear the Alloy runtime directory $RUNDIR" >&2
  exit 1
fi
if ! mkdir -p "$RUNDIR"; then
  echo "ERROR: Failed to create the Alloy runtime directory $RUNDIR" >&2
  exit 1
fi
if ! cp "$USERCONF"/*.alloy "$RUNDIR"/; then
  echo "ERROR: Failed to copy Alloy config files from $USERCONF to $RUNDIR" >&2
  exit 1
fi

AUTH_CONFIG=
if [ "$USE_AUTH" = "true" ]; then
  AUTH_CONFIG='    basic_auth {
      username = sys.env("LOKI_USER")
      password = sys.env("LOKI_PASSWORD")
    }'
fi

if ! printf '%s\n' \
  'loki.write "default" {' \
  '  endpoint {' \
  '    url = sys.env("LOKI_URL")' \
  "$AUTH_CONFIG" \
  '  }' \
  '}' > "$RUNDIR/loki-write.generated.alloy"; then
  echo "ERROR: Failed to write the generated Loki output config" >&2
  exit 1
fi

exec /bin/alloy run \
  --server.http.listen-addr=0.0.0.0:12345 \
  --storage.path=/data/alloy \
  "$RUNDIR"