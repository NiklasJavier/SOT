# Terraform Modulstruktur

Dieser Platzhalter dient als Einstiegspunkt für lokale Terraform-Module innerhalb von SOT.
Die Struktur orientiert sich an TID (Terraform Infrastructure Deployment) und ermöglicht,
provider-spezifische Module, Stacks oder Re-usable Komponenten abzulegen.

Empfohlene Unterordner:

- `modules/terraform/<provider>/` – Wiederverwendbare Module (z. B. `proxmox`, `hetzner`).
- `modules/terraform/services/` – Service- oder Stack-Definitionen mit `.tfvars`.
- `modules/terraform/scripts/` – Helper-Skripte wie Provider-Bootstrap oder Cloud-Init-Snippets.

> Für komplexere Setups empfiehlt sich weiterhin die direkte Nutzung von TID.
