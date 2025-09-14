# SOT (ServerOperationToolkit)

## Overview

The **SOT** repository provides a collection of scripts and configurations to quickly and easily set up a development, staging, or production environment. It is flexible and allows configuration based on user-defined settings or the use of default values.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [DevOps CLI Tool](#devops-cli-tool)
- [Using the Ansible Vault](#using-the-ansible-vault)
- [Debugging and Updates](#debugging-and-updates)
- [Features](#features)
- [License](#license)
- [Contact](#contact)

## Installation

The SOT can be initialized and installed using various commands. Here is an example for a quick setup.

### Example for a Quick Setup:

This command installs the toolkit and immediately executes a setup script, enabling a smooth and quick setup.

```bash
curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev -port "22" && devops setup
```

- **curl -fsSL**: Fetches the setup script from the specified GitHub repository.
- **bash -s -- -branch dev -key "ssh-pub-key" -port "22"**: Executes the script, sets up a development environment, enables the SSH key function with the provided public key, and configures SSH to use port 22.
- **&& devops setup**: After the installation, it immediately runs the `setup` script using the `devops` command to complete the setup. This also creates an Ansible Vault in the `${opt_data_dir}` directory.

**Note**: You can use `&&` to chain additional DevOps scripts to be executed automatically after the initial setup.

### Additional Example Commands:

- **Set up a Production Environment**:
  
  This command sets `USE_DEFAULTS=true` and configures a production environment.

  ```bash
  curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch production
  ```

- **Set up a Staging Environment**:
  
  This command sets `USE_DEFAULTS=true` and configures a staging environment.

  ```bash
  curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch staging 
  ```

- **Set up a Development Environment**:
  
  This command sets `USE_DEFAULTS=true` and configures a development environment.

  ```bash
  curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev
  ```

- **Set up a Development Environment with SSH Key**:
  
  This command sets `USE_DEFAULTS=true`, configures a development environment, and enables the SSH key function with the provided public key.

  ```bash
  curl -fsSL https://raw.githubusercontent.com/NiklasJavier/SOT/dev/environments/setup_devops_toolkit.sh | bash -s -- -branch dev -key "ssh-pub-key"
  ```

### Available Flags:

- **`-branch [production|staging|dev]`**:
  - Specifies the branch to be used. This option automatically sets `USE_DEFAULTS=true` and configures the corresponding environment.
  
- **`-full [true|false]`**:
  - Performs a full installation if set to `true`.
  
- **`-systemname [Name]`**:
  - Sets the system name (formerly hostname).
  
- **`-username [Name]`**:
  - Defines the username for the configuration.
  
- **`-key [Path]`**:
  - Enables the SSH key function and uses the provided public key.
  
- **`-port [Port Number]`**:
  - Sets the port for SSH connections.
  
- **`-tools [Tools]`**:
  - Installs additional tools separated by spaces.

## DevOps CLI Tool

The DevOps CLI Tool is a core component of the SOT that facilitates the execution of automation scripts. After installation and initialization, the tool is available via the `devops` command, eliminating the need to call `./devops_cli.sh`.

### Usage:

Once the toolkit is initialized, the tool can be invoked directly via the `devops` command:

```bash
devops [foldername] <command> [args]
```

### Functionality:

1. **Load Configuration**: The tool loads a configuration file that is either predefined or customized by the user. This file contains key-value pairs that are made available as environment variables in the script.

2. **Command Logging**: All executed commands are logged with a timestamp and username in a log file (`$LOG_FILE`).

3. **Command Execution**: Based on the provided command, the tool searches the script directory (`$SCRIPTS_DIR`) for the corresponding script and executes it with the necessary arguments and environment variables.

4. **Display Help**: If `help` is provided as a command, the tool displays a list of all available scripts and commands. It can also display specific help for individual commands.

### Example:

```bash
devops debug update
```

If `debug` is a folder in the script directory and `update.sh` is a script within it, this script will be executed with the specified arguments.

### Error Handling:

If a command is not found or fails to execute, the tool displays an error message and offers the option to execute a default command (`$default_command`).

## Using the Ansible Vault

The SOT uses an encrypted Ansible Vault to securely store and manage sensitive and dynamically configurable parameters. When the `devops setup` command is executed, a Vault file is created in the `${opt_data_dir}` directory, containing sensitive data such as credentials and configuration parameters.

### Managing the Vault:

- **View and Edit Vault Contents**: The contents of the Vault can be viewed and edited using the `devops vault` command.
- **Vault Key**: The secret key to decrypt the Vault file is stored in the `$VAULT_SECRET` variable. This key is only stored in the `${opt_data_dir}` directory under the name `devopsVaultAccessSecret-${username}.yml` if a clean removal of the toolkit is performed via `devops debug delete`. It is recommended to securely note this key and delete the file after setup.

### Example for Managing the Vault:

- **View Vault**:
  ```bash
  devops vault
  ```

- **Open Vault with Stored Key**:
  A script named `openVault.sh` in the `${opt_data_dir}` directory allows the Vault to be opened with the stored key:
  ```bash
  ${opt_data_dir}/openVault.sh
  ```

  This ensures that the systems configured by the script continue to have access to the necessary configuration parameters, even if the key is removed from the system. However, it is recommended to delete the access key to ensure security.

## Debugging and Updates

The SOT includes features for debugging and updating. Using the `devops update` command, the latest changes to the scripts can be retrieved, while retaining any custom changes or additions.

### Features of Debugging and Updates:

- **Toolkit Cleanup**: Removes all temporary files, configurations, and credentials from the system, except for a backup of the credentials stored in the `${opt_data_dir}` as `.yml`. The Vault key is only stored if `devops debug delete` is executed.
  
- **Toolkit Updates**: The `devops update` command allows you to retrieve the latest changes to the scripts while preserving custom modifications. This ensures that the toolkit is always up to date.

### Example:

- **Clean Up Toolkit**:
  ```bash
  devops debug delete
  ```

- **Update Toolkit**:
  ```bash
  devops update
  ```

This script updates the toolkit and ensures that all components are up to date while retaining any custom modifications.

## Features

- **Automated Script Detection and Execution**: Scans the script directory for executable files and executes them based on user input.
- **Configurable Environment Variables**: Loads and sets variables from a configuration file to dynamically adapt scripts.
- **Integrated Logging**: Logs all executed commands for later review.
- **Secure Vault Management**: Manages sensitive data through an encrypted Ansible Vault, with the option to securely delete or retain the access key.
- **Debugging and Updates**: Includes tools for cleaning up and updating the toolkit while retaining a secure copy of the credentials. Script changes can be retrieved via `devops update` without losing custom modifications.
- **Easy Access via `devops`**: After installation, the CLI tool can be used directly with the `devops` command, without needing to specify the path.
