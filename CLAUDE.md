# CLAUDE.md

Home-Assistant-Add-on, das Grafana Alloy auf Home Assistant OS ausführt und das Host-Journal (Core, Supervisor, Host, alle Add-ons) an Loki schickt. Repo: `dockercraft-yt/ha-addon-alloy`.

Mit dem Nutzer auf Deutsch kommunizieren. Doku, CHANGELOG, Commit-Messages und Code-Kommentare sind auf Englisch (außer `DOCS.de.md` und die Übersetzungsdateien).

## Aufbau

- `alloy/config.yaml`: Add-on-Manifest (Version, Optionen, Schema, Ordner-Mappings)
- `alloy/run.sh`: Startskript (POSIX `sh`, muss ShellCheck mit `--shell=sh` bestehen). Liest `/data/options.json` mit `jq`, baut die Laufzeit-Config in `/tmp/alloy` und startet `alloy run`.
- `alloy/default.alloy`: Standard-Pipeline, wird beim ersten Start als `config.alloy` in den Add-on-Ordner kopiert.
- `alloy/Dockerfile`: basiert auf `grafana/alloy:<version>` (Debian), installiert `jq`, läuft als root (nötig für das Journal).
- `alloy/translations/*.yaml`: Optionsnamen und -beschreibungen in 12 Sprachen (en, de, fr, es, it, nl, pt, pl, cs, sv, nb, da).
- `alloy/DOCS.md` (EN) und `alloy/DOCS.de.md` (DE): Nutzer-Doku im Add-on. `README.md`: GitHub-Startseite.
- `grafana/`: Beispiel-Dashboard. `img/`: Logo und Screenshots.

## Pfade im Container

| Container-Pfad | Herkunft | Zugriff |
|---|---|---|
| `/config` | `app_config` = `/addon_configs/<id>_alloy/` (eigener Add-on-Ordner) | rw |
| `/homeassistant` | `homeassistant_config` (Ordner mit `configuration.yaml`) | ro |
| `/share` | `share` | ro |
| `/data` | `options.json`, Alloy-Storage `/data/alloy` | rw |
| `/var/log/journal` | Host-Journal (`journald: true`) | ro |

Achtung: Im Container ist `/config` der Add-on-Ordner, **nicht** der HA-Konfigurationsordner. In Fehlermeldungen und Doku darauf hinweisen.

Map-Typ heißt `app_config`, nicht mehr das veraltete `addon_config`.

## Begriffe: „App“ statt „Add-on“

Home Assistant hat Add-ons mit 2026.2 in **Apps** umbenannt. Seit 0.2.0 verwenden README, DOCS, Übersetzungen und `description` in `config.yaml` „app“ bzw. „App“. Menüpfad: **Settings → Apps → Install app → ⋮ → Repositories** (DE: Einstellungen → Apps → App installieren). Neue Texte ebenso schreiben.

Technische Namen bleiben: Repo `ha-addon-alloy`, Container `addon_<slug>`, Ordner `/addon_configs/`, Tool „add-on linter“. Der My-Link zum Hinzufügen des Repos heißt `supervisor_add_addon_repository` (nicht `supervisor_add_repository`, den gibt es nicht).

## Konfigurationslogik (run.sh)

- `loki.write "default"` wird immer aus den Optionen erzeugt (`loki-write.generated.alloy`). Nutzer dürfen ihn nicht selbst definieren ("component already declared").
- Alle `*.alloy` aus `/config` werden geladen.
- Option `custom_config_path` (seit 0.2.0, optional): absoluter Pfad unter `/homeassistant`, `/share` oder `/config`. Die Datei **ersetzt** `/config/config.alloy`; andere `*.alloy` aus `/config` werden weiter geladen; dieselbe Datei wird nie doppelt geladen. Relativer oder nicht vorhandener Pfad → Start bricht mit verständlicher Fehlermeldung ab.

Wenn eine neue Option dazukommt: `config.yaml` (options/schema), `run.sh`, **alle 12** Übersetzungen, `DOCS.md`, `DOCS.de.md`, `README.md` und `CHANGELOG.md` anpassen.

## Versionen, Branches, Releases

- Entwicklung auf `Development`, Release per Merge/PR nach `main`.
- Version steht in `alloy/config.yaml` und braucht einen passenden Abschnitt in `alloy/CHANGELOG.md`.
- Push auf `main` → `build.yml` baut und pusht `ghcr.io/dockercraft-yt/ha-addon-alloy-{amd64,aarch64}:<version>`. Vorhandene Versionen werden nie überschrieben, also bei Image-Änderungen immer die Version erhöhen.
- Push auf `main` → `release.yml` erstellt Tag und GitHub-Release `v<version>`; die Notizen kommen aus `## <version>` im CHANGELOG (awk prüft das zweite Wort der Überschrift).
- `lint.yml` (Add-on-Linter, ShellCheck, Hadolint, `alloy fmt` auf `default.alloy`) läuft nur bei Pull Requests und Pushes auf `main`, **nicht** bei Pushes auf `Development`.
- 0.2.0 ist bewusst ein Minor-Sprung (Alloy v1.22.0 + `custom_config_path`), damit beim Einsatz eines Base Images ein klarer Versionssprung sichtbar ist.

## CHANGELOG-Stil

- Die Versionsnummer muss das zweite Wort der `## `-Überschrift bleiben (sonst findet `release.yml` die Notizen nicht).
- **Major/Minor** (x.0.0, 0.x.0): `## <version> – Minor release` bzw. `– Major release`, kurzer Einleitungssatz, **Highlights**-Liste, Abschnitte mit Emojis: `### ✨ Added`, `### 🔄 Changed`, `### 🐛 Fixed`, `### ⚠️ Upgrade notes`.
- **Bugfix/Patch** (0.x.y): schlicht, `### Fixed` / `### Changed`, keine Emojis, keine Einleitung.

## Lokal testen (ohne GHCR)

Unter Windows fehlen Docker, ShellCheck und jq; dort nur `sh -n alloy/run.sh` möglich. Volle Tests auf dem Linux-Rechner:

ShellCheck und Hadolint sind auf dem Linux-Rechner nicht installiert, laufen aber per Docker. Für den Add-on-Linter gibt es kein öffentliches Image; `frenck/action-addon-linter` (Tag `v2`) klonen und `src/` bauen:

```bash
docker run --rm -v "$PWD:/mnt:ro" koalaman/shellcheck:stable --shell=sh /mnt/alloy/run.sh
docker run --rm -i -v "$PWD/.hadolint.yaml:/.config/hadolint.yaml:ro" hadolint/hadolint \
  hadolint --config /.config/hadolint.yaml --failure-threshold warning - < alloy/Dockerfile
# Add-on-Linter (INPUT_COMMUNITY muss gesetzt sein, sonst KeyError):
git clone -q --depth 1 -b v2 https://github.com/frenck/action-addon-linter.git /tmp/linter
docker build -t addon-linter /tmp/linter/src
docker run --rm -v "$PWD:/github/workspace:ro" -w /github/workspace \
  -e INPUT_PATH=./alloy -e INPUT_COMMUNITY=false addon-linter

mkdir -p test/{data,config,homeassistant/alloy,share}
cp alloy/default.alloy test/homeassistant/alloy/config.alloy
echo '{"loki_host":"192.0.2.10","loki_port":3100,"use_https":false,"custom_config_path":"/homeassistant/alloy/config.alloy"}' > test/data/options.json
docker build -t alloy-test alloy/
docker run --rm -p 12345:12345 \
  -v "$PWD/test/data:/data" -v "$PWD/test/config:/config" \
  -v "$PWD/test/homeassistant:/homeassistant:ro" -v "$PWD/test/share:/share:ro" \
  -v /var/log/journal:/var/log/journal:ro -v /etc/machine-id:/etc/machine-id:ro \
  alloy-test
```

Den Ordner `test/` nicht committen.

Realistischer Test auf Home Assistant: `alloy/` per Samba- oder SSH-App nach `/local_apps/alloy_dev/` kopieren (ältere HA-Versionen: `/addons/alloy_dev/`). Dort in `config.yaml` die `image:`-Zeile löschen (dann baut der Supervisor lokal) und `slug: alloy_dev` / `name: Grafana Alloy (dev)` setzen. Danach **Settings → Apps → Install app** (App store) öffnen, oben rechts im **⋮**-Menü **Check for updates** wählen, ggf. Seite neu laden und die App im Abschnitt **Local apps** installieren. Die reguläre App vorher stoppen (gleicher Port 12345, doppelte Logs).

## Stand

- **0.2.0 veröffentlicht (2026-11-19)** über PR #3; Images auf GHCR und Release `v0.2.0` erstellt. `main` und `Development` waren danach identisch.
- Vorgestellt im Home-Assistant-Forum (Kategorie „Projects“). Der Entwurf liegt lokal in `FORUM_POST.md` (per `.gitignore` ausgeschlossen).

## Offene Punkte

- [ ] Muttersprachliche Prüfung der Übersetzungen (außer de/en), vor allem `custom_config_path` und die Begriffe für „App“ (fr „application“, it „app“, es „aplicación“, pt „aplicativo“, pl „aplikacja“, cs „aplikace“, nl/sv/nb/da „app“). Unklar, ob das die offiziellen HA-Begriffe der jeweiligen Sprache sind.
- [ ] Deutsche Buttonbeschriftung „App installieren“ in `DOCS.de.md` in der echten HA-Oberfläche prüfen.
- [ ] Beim nächsten lokalen Test prüfen, ob der Ordner auf deinem System `/local_apps` oder noch `/addons` heißt, und den Abschnitt oben entsprechend festziehen.
