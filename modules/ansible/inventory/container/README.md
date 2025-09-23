# Container-Inventar

Dieser Ordner stellt ein optionales Inventar für Container-bezogene Playbooks zur Verfügung.
Die Playbooks greifen weiterhin auf die gemeinsamen Rollen unter `modules/ansible/roles` zu,
verwenden jedoch ein separates `ansible.cfg`, falls spezielle Einstellungen erforderlich sind.

## Enthaltene Dateien

- `ansible.cfg` – Container-spezifische Basiskonfiguration (z. B. angepasster `roles_path`).
- `hosts.ini` – Inventar für lokale Ausführungen gegen Container oder Container-Hosts.

> Tipp: Wird kein eigener Container-spezifischer Eintrag benötigt, kann das Standardinventar
> `modules/ansible/inventory/hosts.ini` genutzt werden. Das CLI akzeptiert hierfür den
> Inventar-Schlüssel `default`.
