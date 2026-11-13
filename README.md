# Grafana Alloy – Home Assistant Add-on

[![Add repository to my Home Assistant][repository-badge]][repository-url]

Ship the logs of **Home Assistant Core, the Supervisor, the host and every installed add-on** to [Grafana Loki](https://grafana.com/docs/loki/) with [Grafana Alloy](https://grafana.com/docs/alloy/), running as a regular add-on on Home Assistant OS.

> This is an unofficial community add-on. It is not affiliated with or endorsed by Grafana Labs or Nabu Casa.

## Why this add-on?

- **Everything in one place:** Core, Supervisor, host and all add-on logs end up in Loki, searchable in Grafana.
- **Small and simple:** Based on the official `grafana/alloy` image. No extra privileges, no disabled protection mode, no Docker API access. The add-on only reads the host journal, read-only.
- **Configured from the Home Assistant UI:** Loki host and port, optional HTTPS and optional Basic Auth are plain add-on options.
- **Hackable:** Alloy's own web UI is available, and you can extend the default pipeline with your own `*.alloy` files.
- **Example dashboard included:** Import it into Grafana and get log volume, errors and log streams per container.

## Requirements

- Home Assistant OS (add-ons require the Supervisor)
- A reachable Loki instance
- Grafana with a Loki data source (for the dashboard)

## Installation

1. Click the badge above, or go to **Settings → Add-ons → Add-on Store → ⋮ → Repositories** and add:

   ```
   https://github.com/dockercraft-yt/ha-addon-alloy
   ```

2. Install **Grafana Alloy** from the store.
3. Open the **Configuration** tab, enter your Loki host (and port if it is not `3100`) and save.
4. Start the add-on.

The add-on log should show `Sending logs to http://…`. A few seconds later the first entries appear in Grafana.

## Configuration

| Option | Required | Default | Description |
|---|---|---|---|
| `loki_host` | yes | – | IP or hostname of Loki, without `http://` and without port |
| `loki_port` | yes | `3100` | Port of Loki |
| `use_https` | no | `false` | Connect via HTTPS |
| `use_basic_auth` | no | `false` | Use Basic Auth |
| `loki_user` | with Basic Auth | – | Username |
| `loki_password` | with Basic Auth | – | Password |

Restart the add-on after changing options. HTTPS and Basic Auth are meant for setups with a reverse proxy in front of Loki, because Loki itself supports neither. See [DOCS.md](alloy/DOCS.md) for details.

## Finding your logs

Every entry carries `job="haos-journal"` plus the labels `container`, `syslog_identifier`, `unit` and `level`.

```logql
# Home Assistant Core
{job="haos-journal", container="homeassistant"}

# One add-on (container name is addon_<slug>)
{job="haos-journal", container="addon_core_ssh"}

# Errors across everything
{job="haos-journal"} |~ "ERROR|CRITICAL"
```

Use the label browser in Grafana Explore to see the container names on your system.

## Grafana dashboard

An example dashboard lives in [`grafana/ha-logs-dashboard.json`](grafana/ha-logs-dashboard.json). It contains:

- Totals for log lines, errors, warnings and active containers
- Log volume and errors per container over time
- Top 10 containers by log volume
- Log panels for Home Assistant Core, errors and warnings, and all logs
- Variables for the Loki data source, the container selection and a free-text search

To import it: **Dashboards → New → Import → Upload JSON file**, then select your Loki data source.

Errors and warnings are detected by text (`ERROR`, `CRITICAL`, `WARNING`) in the log line. The `level` label comes from the Docker journal driver and only reflects stdout versus stderr, not the log level of the application.

## Custom Alloy configuration

On first start, a default `config.alloy` is created in the add-on's config folder (`/addon_configs/<ID>_alloy/`, reachable via the Samba or SSH add-on). It is never overwritten by updates. All `*.alloy` files in that folder are loaded.

The `loki.write "default"` block is generated from the add-on options. Do not define it yourself, and forward your own pipelines to `loki.write.default.receiver`.

## Troubleshooting

- **The add-on runs but no logs arrive:** Make sure the `loki.source.journal` block in your `config.alloy` contains `path = "/var/log/journal"`. Without it, the journal can appear empty inside the container. You can check delivery with:

  ```
  curl -s http://<ADDON-HOSTNAME>:12345/metrics | grep loki_write_sent_entries_total
  ```

- **"component already declared":** Your own `.alloy` file defines `loki.write "default"`. Remove it.
- **Certificate errors with HTTPS:** Self-signed certificates are currently not supported.

More in [DOCS.md](alloy/DOCS.md).

## Security notes

- The Alloy web UI on port 12345 has no login. Do not expose it to the internet.
- The Basic Auth password is stored in plain text in the add-on options, like every add-on option. It is not written to the log.
- Home Assistant and add-on logs can contain sensitive data such as hostnames, IP addresses or tokens. Send them only to a Loki instance you trust.

## Repository layout

```
.
├── repository.yaml
├── README.md
├── grafana/
│   └── ha-logs-dashboard.json
└── alloy/
    ├── config.yaml
    ├── Dockerfile
    ├── run.sh
    ├── default.alloy
    ├── DOCS.md
    ├── CHANGELOG.md
    └── translations/
```

## Contributing

Issues and pull requests are welcome. When reporting a problem, please include the add-on log and your Home Assistant OS version, and remove any internal addresses or credentials first.

## License

See [LICENSE](LICENSE).

[repository-badge]: https://img.shields.io/badge/Add%20repository%20to%20my-Home%20Assistant-41BDF5?logo=home-assistant&style=for-the-badge
[repository-url]: https://my.home-assistant.io/redirect/supervisor_add_repository/?repository_url=https%3A%2F%2Fgithub.com%2FYOUR-USER%2FYOUR-REPO