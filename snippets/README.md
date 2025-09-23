# Snippets

In diesem Ordner können wiederverwendbare YAML-, Shell- oder Cloud-Init-Snippets abgelegt
werden. Die Sammlung erleichtert die Pflege von häufig genutzten Konfigurationen
(z. B. Cloud-Init, Container-Templates oder Vault-Seed-Dateien).

Strukturvorschlag:

- `snippets/cloud-init/` – Basis-Snippets für neue Server (z. B. QEMU Guest Agent).
- `snippets/vault/` – Beispielinhalte für Secrets oder Policy-Definitionen.
- `snippets/docker/` – Docker-Compose- oder Traefik-Beispiele.

> Die Dateien können direkt von Modulen, Skripten oder externen Projekten referenziert werden.
