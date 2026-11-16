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
CUSTOM_CONFIG=$(jq -r '.custom_config_path // empty' "$OPTS")

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

if [ -n "$CUSTOM_CONFIG" ]; then
  # Optional: user-provided config file that replaces $USERCONF/config.alloy
  case "$CUSTOM_CONFIG" in
    /*) ;;
    *)
      echo "ERROR: custom_config_path must be an absolute path, e.g. /homeassistant/alloy/config.alloy" >&2
      exit 1
      ;;
  esac
  if [ ! -f "$CUSTOM_CONFIG" ] || [ ! -r "$CUSTOM_CONFIG" ]; then
    echo "ERROR: Custom Alloy config $CUSTOM_CONFIG not found or not readable" >&2
    echo "       Allowed locations: /homeassistant/... (Home Assistant config folder)," >&2
    echo "       /share/... and /config/... (this add-on's config folder)." >&2
    case "$CUSTOM_CONFIG" in
      /config/*)
        echo "       Note: inside this add-on, /config is the add-on's own folder." >&2
        echo "       For the Home Assistant config folder use /homeassistant/... instead." >&2
        ;;
    esac
    exit 1
  fi
  CUSTOM_CONFIG=$(realpath "$CUSTOM_CONFIG")
  echo "Alloy config: ${CUSTOM_CONFIG} (custom)"
else
  # Create the default config on first start
  if [ ! -f "$USERCONF/config.alloy" ]; then
    if ! cp /default.alloy "$USERCONF/config.alloy"; then
      echo "ERROR: Failed to create the default Alloy config in $USERCONF" >&2
      exit 1
    fi
  fi
  echo "Alloy config: ${USERCONF}/config.alloy (add-on config folder)"
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
for f in "$USERCONF"/*.alloy; do
  [ -f "$f" ] || continue
  if [ -n "$CUSTOM_CONFIG" ]; then
    # The custom file replaces config.alloy; never load the same file twice
    [ "$(basename "$f")" = "config.alloy" ] && continue
    [ "$(realpath "$f")" = "$CUSTOM_CONFIG" ] && continue
  fi
  if ! cp "$f" "$RUNDIR"/; then
    echo "ERROR: Failed to copy Alloy config file $f to $RUNDIR" >&2
    exit 1
  fi
done

if [ -n "$CUSTOM_CONFIG" ] && ! cp "$CUSTOM_CONFIG" "$RUNDIR/config.alloy"; then
  echo "ERROR: Failed to copy custom Alloy config $CUSTOM_CONFIG to $RUNDIR" >&2
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