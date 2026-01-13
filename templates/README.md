# Templates

In diesem Ordner können wiederverwendbare YAML-, Shell- oder Cloud-Init-Templates abgelegt
werden. Die Sammlung erleichtert die Pflege von häufig genutzten Konfigurationen
(z. B. Cloud-Init, Container-Templates oder Vault-Seed-Dateien).

Strukturvorschlag:

- `templates/cloud-init/` – Basis-Templates für neue Server (z. B. QEMU Guest Agent).
- `templates/vault/` – Beispielinhalte für Secrets oder Policy-Definitionen.
- `templates/docker/` – Docker-Compose- oder Traefik-Beispiele.

> Die Dateien können direkt von Modulen, Skripten oder externen Projekten referenziert werden.
