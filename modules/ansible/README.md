# Ansible Modulstruktur

Das `modules/ansible`-Verzeichnis bildet die Standard-Ansible-Struktur ab, die innerhalb
von SOT verwendet wird. Die Inhalte orientieren sich an den Konventionen von AAT und
können direkt erweitert oder überschrieben werden.

## Struktur

```
modules/ansible/
├── ansible.cfg                 # Globale Ansible-Einstellungen
├── config/                     # Zentrale Include-Tasks (z. B. load_config.yml)
├── inventory/
│   ├── hosts.ini               # Standardinventar (localhost)
│   └── container/              # Optionales Inventar + ansible.cfg für Container-Szenarien
├── playbooks/                  # Einstiegspunkte (z. B. host_setup.yml)
├── roles/                      # Wiederverwendbare Rollen (common, variables, vault, …)
└── trigger_playbook.sh         # Wrapper für CLI-Aufrufe aus `SOT setup`
```

## Konfiguration laden

Die Rolle `roles/variables` lädt per `config/load_config.yml` sowohl die Standardwerte
unter `services/default_config.yml` als auch optionale Overrides. Dadurch stehen alle
Parameter als `sot_config`-Facts in den Playbooks zur Verfügung.

## Erweiterung

- Zusätzliche Inventare können unter `inventory/<name>/` abgelegt werden. Das CLI akzeptiert
  sie über den Parameter `<inventory_key>` im `trigger_playbook.sh`.
- Weitere Rollen folgen den üblichen Ansible-Konventionen und können direkt im Ordner
  `roles/` hinzugefügt werden.
- Gemeinsame Variablen lassen sich über `group_vars/` oder `host_vars/` ergänzen, falls nötig.
