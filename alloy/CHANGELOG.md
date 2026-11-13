# Changelog

All notable changes to this add-on are documented here.
## 0.1.5

### Changed

- Changed visibility for Basic Authentication to optional

## 0.1.4

### Added

- Readable field names and descriptions in the add-on configuration (English and German translations).
- Add-on icon (`icon.png`) and logo (`logo.png`).

### Notes

- The icon and logo were created with the help of AI (Claude by Anthropic) and are original designs, not copies of the Grafana or Home Assistant logos.

## 0.1.3

### Fixed

- No logs reached Loki although the add-on started without errors. The journal source now uses an explicit `path = "/var/log/journal"`. Without it, libsystemd inside the container can silently find zero entries.

### Upgrade notes

- The default `config.alloy` is only created on first start and is **never overwritten**. If you already have one, add the following line to the `loki.source.journal "haos"` block yourself:

  ```alloy
  path = "/var/log/journal"
  ```

  Alternatively, delete `config.alloy` in the add-on's config folder and restart the add-on to get the new default.

## 0.1.2

### Added

- Optional HTTPS for the connection to Loki (`use_https`).
- Optional Basic Auth for the connection to Loki (`use_basic_auth`, `loki_user`, `loki_password`). The password is passed to Alloy as an environment variable and is never written to a file or printed to the log.
- "Open Web UI" button on the add-on page (`webui`).
- Port description for the Alloy web UI in the network settings.
- Documentation (`DOCS.md`) with option reference, LogQL examples and troubleshooting.

### Changed

- The `loki.write "default"` block is now generated at startup from the add-on options instead of being part of `config.alloy`. This is what makes the HTTPS and Basic Auth switches possible.
- All add-on messages and documentation are now in English.
- `jq` is installed in the image to parse the add-on options reliably.

### Upgrade notes

- **Breaking:** Remove any `loki.write "default"` block from your existing `config.alloy`, otherwise Alloy fails with "component already declared". Deleting the file (to let it be recreated from the new default) also works.

## 0.1.1

### Added

- Loki host and port are configurable in the add-on options (`loki_host`, `loki_port`). The push URL is assembled automatically.
- The add-on refuses to start with a clear error message if the Loki host is missing.

### Changed

- The Loki URL is read from the environment (`sys.env("LOKI_URL")`) instead of being hard-coded in the Alloy configuration.

## 0.1.0

### Added

- Initial release: Grafana Alloy as a Home Assistant add-on for Home Assistant OS.
- Collects the host journal, which contains the logs of Home Assistant Core, the Supervisor and all installed add-ons, and ships it to Loki.
- Labels for easier filtering in Grafana: `container`, `syslog_identifier`, `unit`, `level`, plus the fixed labels `job="haos-journal"` and `host="haos"`.
- Default configuration is created on first start in the add-on config folder and can be edited freely.
- Alloy web UI on port 12345 (no sidebar entry).
- Read-only access to the host journal via `journald: true`, no extra privileges required.