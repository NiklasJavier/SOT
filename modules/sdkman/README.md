# SDKMAN Plugin

SDK-Manager für Java, Gradle, Maven und andere JVM-basierte Tools.

## Übersicht

SDKMAN! ist ein Tool zum Verwalten von parallelen Versionen verschiedener SDKs auf den meisten Unix-basierten Systemen. Es bietet eine bequeme Kommandozeilen-Schnittstelle und API für die Installation, den Wechsel, die Entfernung und die Auflistung von Kandidaten.

## Installation

```bash
SOT sdkman install
# oder
SOT plugins install sdkman
```

## Nach der Installation

1. Terminal neu starten oder:
   ```bash
   source "$HOME/.sdkman/bin/sdkman-init.sh"
   ```

2. Verfügbare SDKs anzeigen:
   ```bash
   sdk list
   ```

3. Java installieren:
   ```bash
   sdk install java
   ```

## Unterstützte SDKs

- Java (verschiedene Distributionen: Temurin, GraalVM, Corretto, etc.)
- Gradle
- Maven
- Kotlin
- Groovy
- Scala
- Spring Boot CLI
- und viele mehr...

## Nützliche Befehle

```bash
sdk list java              # Verfügbare Java-Versionen
sdk install java 21-tem    # Temurin 21 installieren
sdk use java 17-tem        # Temporär zu Java 17 wechseln
sdk default java 21-tem    # Standard-Java setzen
sdk current                # Aktive SDK-Versionen anzeigen
sdk upgrade                # Alle SDKs aktualisieren
```

## Konfiguration

SDKMAN-Konfiguration befindet sich in `~/.sdkman/etc/config`:

```properties
sdkman_auto_answer=false
sdkman_auto_complete=true
sdkman_auto_env=false
sdkman_beta_channel=false
sdkman_colour_enable=true
sdkman_curl_connect_timeout=7
sdkman_curl_max_time=10
sdkman_debug_mode=false
sdkman_insecure_ssl=false
sdkman_rosetta2_compatible=false
sdkman_selfupdate_feature=true
```

## Weitere Informationen

- [SDKMAN! Dokumentation](https://sdkman.io/usage)
- [Verfügbare SDKs](https://sdkman.io/sdks)
