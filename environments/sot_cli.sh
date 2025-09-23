#!/bin/bash

# Standardkonfigurationsdatei (kann angepasst werden)
# bspw. festgelegt VAR: CONFIG_FILE

default_command="help"

# Konfigurationsdatei laden, falls vorhanden

while IFS= read -r line
do
    # Nur Zeilen verarbeiten, die ein ":" enthalten
    if echo "$line" | grep -q ":"; then
        # Den Namen und den Wert extrahieren
        var_name=$(echo "$line" | cut -d ':' -f 1 | xargs | tr ' ' '_')
        var_value=$(echo "$line" | cut -d ':' -f 2- | xargs)

        # Entferne die Anführungszeichen, wenn sie vorhanden sind
        var_value=$(echo "$var_value" | sed 's/^"\(.*\)"$/\1/')

        # Die Variable setzen
        eval "$var_name=\"$var_value\""
    fi
done < "$CONFIG_FILE"

# Funktion zum Logging von Befehlen
log_command() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $USER - $@" >> "$log_file"
}

# Funktion zur Anzeige der Hilfe
show_help() {
    echo "Usage: SOT [foldername] <command> [args]"
    echo ""
    echo "Available commands:"
    find "$scripts_dir" -type f -name "*.sh" | sed "s|^$scripts_dir/||" | sed "s|/| |g" | sed "s|.sh$||"
    echo ""
    echo "Use 'SOT help <command>' for more information on a specific command."
}

# Funktion zur Anzeige der spezifischen Hilfe für einen Befehl
show_command_help() {
    local command_path="$1"
    if [ -x "$command_path" ]; then
        "$command_path" --help
        return $?
    else
        echo "No help available for this command."
        return 1
    fi
}

# Funktion zum Ausführen des Befehls
execute_command() {
    local command_path="$1"
    shift

    if [ -x "$command_path" ]; then
        "$command_path" "$@" "$tools_dir" "$CONFIG_FILE" "$username" "$vault_file" "$vault_secret" "$opt_data_dir" "$clone_dir" "$systemlink_path" "$log_file" "$branch"
        return $?
    else
        return 1
    fi
}

# Überprüfen, ob ein Befehl übergeben wurde
if [ -z "$1" ]; then
    echo "No command provided."
    show_help
    exit 1
fi

# Wenn "help" als erstes Argument übergeben wurde
if [ "$1" = "help" ]; then
    if [ -z "$2" ]; then
        show_help
        exit 0
    else
        if [ -f "$scripts_dir/$2.sh" ]; then
            show_command_help "$scripts_dir/$2.sh"
        elif [ -f "$scripts_dir/$2/$3.sh" ]; then
            show_command_help "$scripts_dir/$2/$3.sh"
        else
            echo "No help available for the command '$2'."
            exit 1
        fi
        exit 0
    fi
fi

# Aufbau des Befehls (Ordner/Skriptstruktur unterstützen)
if [ -f "$scripts_dir/$1.sh" ]; then
    COMMAND_PATH="$scripts_dir/$1.sh"
    shift
elif [ -f "$scripts_dir/$1/$2.sh" ]; then
    COMMAND_PATH="$scripts_dir/$1/$2.sh"
    shift 2
else
    COMMAND_PATH=""
fi

# Logge den Befehl
log_command "$COMMAND_PATH $@"

# Versuche den Befehl auszuführen
if [ -n "$COMMAND_PATH" ]; then
    execute_command "$COMMAND_PATH" "$@"
    RESULT=$?
else
    RESULT=1
fi

# Fallback-Option, wenn der Befehl nicht gefunden wird
if [ $RESULT -ne 0 ]; then
    if [ -n "$default_command" ] && [ "$default_command" != "$1" ]; then
        echo "Command not found. Executing default command."
        execute_command "$scripts_dir/$default_command.sh" "$COMMAND_PATH" "$@"
    else
        echo "Error: Command not found."
        show_help
        exit 1
    fi
fi

# Fehlerbehandlung
if [ $RESULT -ne 0 ]; then
    echo "The command failed with exit code $RESULT."
    exit $RESULT
fi

exit 0


