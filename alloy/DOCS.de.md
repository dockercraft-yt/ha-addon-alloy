# Grafana Alloy

Dieses Add-on führt [Grafana Alloy](https://grafana.com/docs/alloy/) direkt auf deinem Home Assistant OS aus und schickt die Logs von **Home Assistant Core, Supervisor, dem Host und allen installierten Add-ons** an eine [Grafana Loki](https://grafana.com/docs/loki/)-Instanz.

## Wie funktioniert das?

Unter Home Assistant OS laufen Core, Supervisor und alle Add-ons als Docker-Container. Docker schreibt deren Logs ins Journal des Hosts. Das Add-on liest dieses Journal (read-only) aus, versieht die Einträge mit Labels und sendet sie an Loki. Zusätzliche Berechtigungen wie Docker-Zugriff oder ein deaktivierter Schutzmodus sind dafür **nicht** nötig.

## Voraussetzungen

- Home Assistant OS (Add-ons gibt es nur mit Supervisor)
- Eine erreichbare Loki-Instanz (Push-Endpoint `/loki/api/v1/push`)

Test vom Home-Assistant-Terminal aus:

```
curl http://<LOKI-IP>:3100/ready
```

Kommt `ready` zurück, ist Loki erreichbar.

## Installation

1. Einstellungen → Add-ons → Add-on Store → ⋮ → **Repositories**
2. Die URL dieses Repositories eintragen und hinzufügen
3. "Grafana Alloy" installieren
4. Im Tab **Konfiguration** mindestens den Loki-Host eintragen (siehe unten) und speichern
5. Add-on starten

Im Log des Add-ons sollte danach `Sende Logs an http://…` stehen.

## Konfiguration

| Option | Pflicht | Standard | Beschreibung |
|---|---|---|---|
| `loki_host` | ja | – | IP oder Hostname von Loki, ohne `http://` und ohne Port |
| `loki_port` | ja | `3100` | Port von Loki |
| `use_https` | nein | `false` | Verbindung per HTTPS statt HTTP aufbauen |
| `use_basic_auth` | nein | `false` | Basic Auth für die Verbindung zu Loki verwenden |
| `loki_user` | bei Basic Auth | – | Benutzername |
| `loki_password` | bei Basic Auth | – | Passwort |

Die URL wird automatisch zusammengesetzt:

```
<http|https>://<loki_host>:<loki_port>/loki/api/v1/push
```

**Änderungen an den Optionen werden erst nach einem Neustart des Add-ons wirksam.**

### HTTPS und Basic Auth

Loki selbst unterstützt weder Basic Auth noch TLS direkt. Beides wird in der Regel von einem **Reverse Proxy** vor Loki bereitgestellt (z. B. nginx, Traefik oder Caddy). Die Optionen sind nur sinnvoll, wenn ein solcher Proxy davor sitzt.

Vorab testen:

```
curl -u BENUTZER:PASSWORT https://<LOKI-HOST>:<PORT>/ready
```

**Bekannte Einschränkung:** Selbstsignierte Zertifikate werden aktuell nicht akzeptiert. Das Zertifikat muss von einer Stelle stammen, der der Container vertraut (z. B. Let's Encrypt).

Das Passwort steht, wie bei allen Add-on-Optionen, im Klartext in der Konfiguration des Add-ons (`/data/options.json`). Im Log wird es nicht ausgegeben.

## Alloy-Weboberfläche

Alloy bringt eine eigene Oberfläche mit (Pipeline-Graph, Komponentenstatus, Debug-Infos). Sie ist erreichbar unter:

```
http://<HOME-ASSISTANT-IP>:12345
```

Auf der Add-on-Seite gibt es dafür außerdem den Button **Web-UI öffnen**. Das Add-on erscheint bewusst **nicht** in der Seitenleiste.

> **Hinweis:** Die Oberfläche ist nicht per Login geschützt. Jeder im selben Netzwerk, der Port 12345 erreicht, kann sie sehen. Gib den Port nicht ins Internet frei.

## Logs in Grafana finden

Alle Einträge haben das Label `job="haos-journal"`. Zusätzlich gibt es:

| Label | Inhalt |
|---|---|
| `container` | Name des Containers, z. B. `homeassistant`, `hassio_supervisor`, `addon_<slug>` |
| `syslog_identifier` | Bezeichner des Programms im Journal |
| `unit` | Systemd-Unit (bei Host-Diensten) |
| `level` | Log-Level (`err`, `warning`, `info`, `debug` …) |
| `host` | Fester Wert `haos` |

Beispiel-Abfragen (LogQL):

```logql
# Home Assistant Core
{container="homeassistant"}

# Supervisor
{container="hassio_supervisor"}

# Ein bestimmtes Add-on (Beispiel: SSH-Add-on)
{container="addon_core_ssh"}

# Alle Fehler
{job="haos-journal", level="err"}

# Nach Text suchen
{container="homeassistant"} |= "error"

# Alle Add-ons gemeinsam
{container=~"addon_.+"}
```

Welche Container-Namen es gibt, zeigt Grafana im Query-Editor unter dem Label `container`.

## Eigene Alloy-Konfiguration

Beim ersten Start legt das Add-on eine Standardkonfiguration (`config.alloy`) im Konfigurationsordner des Add-ons an:

```
/addon_configs/<ID>_alloy/
```

Der Ordner ist über das Samba- oder SSH-Add-on erreichbar. Die Datei wird bei Updates **nicht überschrieben**, du kannst sie also frei anpassen. Zum Zurücksetzen löschst du sie, beim nächsten Start wird sie neu erzeugt.

Regeln:

- Alle `*.alloy`-Dateien in diesem Ordner werden geladen.
- Den Ziel-Block `loki.write "default"` erzeugt das Add-on selbst aus deinen Optionen. **Definiere ihn nicht in deinen Dateien**, sonst startet Alloy mit dem Fehler "component already declared".
- Leite eigene Pipelines mit `forward_to = [loki.write.default.receiver]` weiter.
- In eigenen Dateien kannst du `sys.env("LOKI_URL")` verwenden, wenn du die zusammengesetzte URL brauchst.

## Fehlersuche

**Das Add-on startet nicht und meldet einen Konfigurationsfehler**
`loki_host` ist nicht gesetzt, oder Basic Auth ist aktiv, aber Benutzer oder Passwort fehlen.

**Fehler "component already declared"**
In einer deiner `.alloy`-Dateien steht ein eigener `loki.write "default"`-Block. Entfernen, siehe oben.

**In Grafana kommen keine Logs an**
1. Im Add-on-Log prüfen, ob `Sende Logs an …` mit der richtigen URL erscheint.
2. Loki-Erreichbarkeit mit `curl …/ready` aus dem Home-Assistant-Terminal testen.
3. In der Alloy-Weboberfläche (Port 12345) den Status der Komponenten `loki.source.journal` und `loki.write` ansehen.
4. Zeitfenster in Grafana prüfen: Beim ersten Start werden maximal die letzten 12 Stunden nachgeliefert.

**Fehler wegen Zertifikat bei HTTPS**
Siehe "Bekannte Einschränkung" oben.

**Loki lehnt Einträge ab (Rate Limit / "entry too old")**
Beim ersten Start können viele Altlogs auf einmal ankommen. Das Limit in Loki anheben oder `max_age` in der eigenen `config.alloy` verkleinern.

## Datenschutz

Logs von Home Assistant und Add-ons können sensible Informationen enthalten, etwa Hostnamen, IP-Adressen, E-Mail-Adressen oder Tokens. Sende sie nur an eine Loki-Instanz, der du vertraust, und schütze den Zugriff auf Loki und Grafana entsprechend.