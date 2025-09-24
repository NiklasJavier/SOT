#!/usr/bin/env python3
"""Utility to load SOT configuration files and expose flattened variables.

The loader understands both the legacy flat key structure as well as the new
nested schema rooted under ``sot``. Values are emitted as shell-compatible
assignments so callers can ``eval`` the output safely.
"""

from __future__ import annotations

import argparse
import copy
import re
import shlex
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, Mapping, MutableMapping

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover - optional dependency
    yaml = None  # type: ignore

DEFAULTS: Dict[str, Any] = {
    "sot": {
        "branch": "production",
        "user": {
            "system_name": "__GENERATE_SYSTEM_NAME__",
            "username": "__GENERATE_USERNAME__",
            "ssh_port": "282",
        },
        "logging": {
            "level": "info",
            "file": "/var/log/sot/cli.log",
        },
        "flags": {
            "use_defaults": "false",
        },
        "tools": {
            "list": "ansible docker sdkman",
        },
        "ssh": {
            "key_function_enabled": "false",
            "public_key": "",
        },
        "paths": {
            "clone": "/opt/sot",
            "modules": "/opt/sot/modules",
            "scripts": "/opt/sot/scripts",
            "pipelines": "/opt/sot/pipelines",
            "ansible_local": "/opt/sot/modules/ansible",
            "overrides": "/etc/sot/overrides",
            "opt_data": "/var/lib/sot",
            "systemlink": "/usr/sbin/SOT",
        },
        "vault": {
            "file": "/etc/sot/vault.yml",
            "secret": "local-secret",
            "content": "__GENERATE_VAULT_CONTENT__",
            "mail": "__GENERATE_VAULT_MAIL__",
        },
        "ansible": {
            "local": {
                "enabled": True,
                "priority": True,
            },
        },
        "runner": {
            "enabled": True,
            "mode": "aat",
            "sync_before_run": True,
            "work_dir": "/var/lib/sot/runner",
            "log_dir": "/var/log/sot/runner",
            "default_inventory": "",
            "aat_playbook_dir": "",
            "tid_stack_dir": "",
        },
        "aat": {
            "enabled": True,
            "repo": "https://github.com/NiklasJavier/AAT.git",
            "dir": "/opt/AAT",
            "branch": "main",
            "inventory": {
                "path": "host.ini",
                "vars": ["ssh_port", "system_name"],
            },
        },
        "tid": {
            "enabled": True,
            "repo": "https://github.com/NiklasJavier/TID.git",
            "dir": "/opt/TID",
            "branch": "main",
            "inventory": {
                "path": "host.ini",
                "vars": ["ssh_port", "system_name"],
            },
        },
    }
}


def deep_merge(target: MutableMapping[str, Any], source: Mapping[str, Any]) -> None:
    for key, value in source.items():
        if (
            key in target
            and isinstance(target[key], MutableMapping)
            and isinstance(value, Mapping)
        ):
            deep_merge(target[key], value)  # type: ignore[arg-type]
        else:
            target[key] = copy.deepcopy(value)


def set_path(data: MutableMapping[str, Any], path: Iterable[str], value: Any) -> None:
    current: MutableMapping[str, Any] = data
    parts = list(path)
    for part in parts[:-1]:
        if part not in current or not isinstance(current[part], MutableMapping):
            current[part] = {}
        current = current[part]  # type: ignore[assignment]
    if parts:
        current[parts[-1]] = value


VARIABLES: Dict[str, Dict[str, Any]] = {
    "branch": {"path": ["sot", "branch"], "legacy": "branch"},
    "system_name": {"path": ["sot", "user", "system_name"], "legacy": "system_name"},
    "username": {"path": ["sot", "user", "username"], "legacy": "username"},
    "ssh_port": {"path": ["sot", "user", "ssh_port"], "legacy": "ssh_port"},
    "log_level": {"path": ["sot", "logging", "level"], "legacy": "log_level"},
    "log_file": {"path": ["sot", "logging", "file"], "legacy": "log_file"},
    "use_defaults": {"path": ["sot", "flags", "use_defaults"], "legacy": "use_defaults"},
    "tools": {"path": ["sot", "tools", "list"], "legacy": "tools"},
    "ssh_key_function_enabled": {
        "path": ["sot", "ssh", "key_function_enabled"],
        "legacy": "ssh_key_function_enabled",
    },
    "ssh_key_public": {
        "path": ["sot", "ssh", "public_key"],
        "legacy": "ssh_key_public",
    },
    "clone_dir": {"path": ["sot", "paths", "clone"], "legacy": "clone_dir"},
    "modules_dir": {"path": ["sot", "paths", "modules"], "legacy": "modules_dir"},
    "scripts_dir": {"path": ["sot", "paths", "scripts"], "legacy": "scripts_dir"},
    "pipelines_dir": {"path": ["sot", "paths", "pipelines"], "legacy": "pipelines_dir"},
    "ansible_local_dir": {
        "path": ["sot", "paths", "ansible_local"],
        "legacy": "ansible_local_dir",
    },
    "ansible_local_enabled": {
        "path": ["sot", "ansible", "local", "enabled"],
        "legacy": "ansible_local_enabled",
        "type": "bool",
    },
    "ansible_local_priority": {
        "path": ["sot", "ansible", "local", "priority"],
        "legacy": "ansible_local_priority",
        "type": "bool",
    },
    "overrides_dir": {"path": ["sot", "paths", "overrides"], "legacy": "overrides_dir"},
    "opt_data_dir": {"path": ["sot", "paths", "opt_data"], "legacy": "opt_data_dir"},
    "systemlink_path": {
        "path": ["sot", "paths", "systemlink"],
        "legacy": "systemlink_path",
    },
    "vault_file": {"path": ["sot", "vault", "file"], "legacy": "vault_file"},
    "vault_secret": {"path": ["sot", "vault", "secret"], "legacy": "vault_secret"},
    "vault_content": {"path": ["sot", "vault", "content"], "legacy": "vault_content"},
    "vault_mail": {"path": ["sot", "vault", "mail"], "legacy": "vault_mail"},
    "aat_enabled": {
        "path": ["sot", "aat", "enabled"],
        "legacy": "aat_enabled",
        "type": "bool",
    },
    "aat_repo_url": {"path": ["sot", "aat", "repo"], "legacy": "aat_repo_url"},
    "aat_dir": {"path": ["sot", "aat", "dir"], "legacy": "aat_dir"},
    "aat_branch": {"path": ["sot", "aat", "branch"], "legacy": "aat_branch"},
    "aat_inventory_path": {
        "path": ["sot", "aat", "inventory", "path"],
        "legacy": "aat_inventory_path",
    },
    "aat_inventory_vars": {
        "path": ["sot", "aat", "inventory", "vars"],
        "legacy": "aat_inventory_vars",
        "type": "list",
    },
    "tid_enabled": {
        "path": ["sot", "tid", "enabled"],
        "legacy": "tid_enabled",
        "type": "bool",
    },
    "tid_repo_url": {"path": ["sot", "tid", "repo"], "legacy": "tid_repo_url"},
    "tid_dir": {"path": ["sot", "tid", "dir"], "legacy": "tid_dir"},
    "tid_branch": {"path": ["sot", "tid", "branch"], "legacy": "tid_branch"},
    "tid_inventory_path": {
        "path": ["sot", "tid", "inventory", "path"],
        "legacy": "tid_inventory_path",
    },
    "tid_inventory_vars": {
        "path": ["sot", "tid", "inventory", "vars"],
        "legacy": "tid_inventory_vars",
        "type": "list",
    },
    "runner_enabled": {
        "path": ["sot", "runner", "enabled"],
        "legacy": "runner_enabled",
        "type": "bool",
    },
    "runner_default_mode": {
        "path": ["sot", "runner", "mode"],
        "legacy": "runner_default_mode",
    },
    "runner_sync_before_run": {
        "path": ["sot", "runner", "sync_before_run"],
        "legacy": "runner_sync_before_run",
        "type": "bool",
    },
    "runner_work_dir": {
        "path": ["sot", "runner", "work_dir"],
        "legacy": "runner_work_dir",
    },
    "runner_log_dir": {
        "path": ["sot", "runner", "log_dir"],
        "legacy": "runner_log_dir",
    },
    "runner_default_inventory": {
        "path": ["sot", "runner", "default_inventory"],
        "legacy": "runner_default_inventory",
    },
    "runner_aat_playbook_dir": {
        "path": ["sot", "runner", "aat_playbook_dir"],
        "legacy": "runner_aat_playbook_dir",
    },
    "runner_tid_stack_dir": {
        "path": ["sot", "runner", "tid_stack_dir"],
        "legacy": "runner_tid_stack_dir",
    },
}


LEGACY_BOOL = {"true", "1", "yes", "on"}


def _normalise_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if value is None:
        return False
    return str(value).strip().lower() in LEGACY_BOOL


def _normalise_list(value: Any) -> Iterable[str]:
    if isinstance(value, (list, tuple)):
        for item in value:
            if item is None:
                continue
            yield str(item)
        return
    if value is None:
        return
    if isinstance(value, str):
        parts = [p for p in re.split(r"[\s,]+", value) if p]
    else:
        parts = [str(value)]
    for part in parts:
        yield part


def parse_simple_yaml(text: str) -> Dict[str, Any]:
    root: Dict[str, Any] = {}
    stack: list[Dict[str, Any]] = [
        {"indent": -1, "container": root, "last_key": None},
    ]

    def parse_scalar(raw: str) -> Any:
        raw = raw.strip()
        if not raw:
            return ""
        if raw[0] == raw[-1] and raw[0] in {'"', "'"}:
            return raw[1:-1]
        lowered = raw.lower()
        if lowered in {"true", "false"}:
            return lowered == "true"
        return raw

    for raw_line in text.splitlines():
        line = raw_line.split("#", 1)[0]
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        line = line.strip()

        while stack and indent <= stack[-1]["indent"]:
            stack.pop()

        if line.startswith("- "):
            value = parse_scalar(line[2:])
            parent = None
            for idx in range(len(stack) - 1, -1, -1):
                candidate = stack[idx]
                container = candidate["container"]
                if isinstance(container, list):
                    parent = candidate
                    stack = stack[: idx + 1]
                    break
                if isinstance(container, dict) and candidate.get("last_key") is not None:
                    parent = candidate
                    stack = stack[: idx + 1]
                    break
            if parent is None:
                raise SystemExit("Invalid YAML structure: list item without key")
            container = parent["container"]
            if isinstance(container, list):
                container.append(value)
                stack.append({"indent": indent, "container": container, "last_key": None})
            elif isinstance(container, dict):
                key = parent.get("last_key")
                if key is None:
                    raise SystemExit("Invalid YAML structure: list item without key")
                current = container.get(key)
                if isinstance(current, dict) and not current:
                    container[key] = []
                    current = container[key]
                if not isinstance(current, list):
                    new_list: list[Any] = []
                    if current not in (None, ""):
                        new_list.append(current)
                    container[key] = new_list
                    current = new_list
                current.append(value)
                stack.append({"indent": indent, "container": current, "last_key": None})
            else:
                raise SystemExit("Invalid YAML structure around list item")
            continue

        if ":" not in line:
            raise SystemExit(f"Unsupported YAML line: {raw_line}")

        key, raw_value = line.split(":", 1)
        key = key.strip()
        value = raw_value.strip()

        parent = stack[-1]
        container = parent["container"]
        if not isinstance(container, dict):
            raise SystemExit(f"Invalid YAML nesting for key: {key}")

        if value == "":
            new_container: Dict[str, Any] = {}
            container[key] = new_container
            parent["last_key"] = key
            stack.append({"indent": indent, "container": new_container, "last_key": None})
        else:
            container[key] = parse_scalar(value)
            parent["last_key"] = key

    return root


def load_raw_config(path: Path) -> Dict[str, Any]:
    if not path.exists():
        raise SystemExit(f"Configuration file not found: {path}")
    text = path.read_text(encoding="utf-8")
    if yaml is not None:  # pragma: no branch - prefer native parser when available
        data = yaml.safe_load(text) or {}
    else:
        data = parse_simple_yaml(text)
    if not isinstance(data, dict):
        raise SystemExit("Configuration file must define a mapping at the top level")
    return data


def build_config(raw: Dict[str, Any]) -> Dict[str, Any]:
    config = copy.deepcopy(DEFAULTS)
    nested = raw.get("sot") if isinstance(raw.get("sot"), Mapping) else None
    if isinstance(nested, Mapping):
        deep_merge(config, {"sot": nested})

    # Apply legacy keys if present at the top level
    for name, meta in VARIABLES.items():
        legacy_key = meta.get("legacy")
        if not legacy_key:
            continue
        if legacy_key in raw and raw[legacy_key] is not None:
            set_path(config, meta["path"], raw[legacy_key])
    return config


def resolve_value(data: Mapping[str, Any], path: Iterable[str]) -> Any:
    current: Any = data
    for part in path:
        if not isinstance(current, Mapping) or part not in current:
            return None
        current = current[part]
    return current


def format_value(name: str, value: Any, meta: Mapping[str, Any]) -> str:
    value_type = meta.get("type")
    if value_type == "bool":
        rendered = "true" if _normalise_bool(value) else "false"
    elif value_type == "list":
        rendered = " ".join(_normalise_list(value))
    else:
        if value is None:
            rendered = ""
        else:
            rendered = str(value)
    return f"{name}={shlex.quote(rendered)}"


def main(argv: Iterable[str]) -> int:
    parser = argparse.ArgumentParser(description="Load SOT configuration values")
    parser.add_argument("config", type=Path, help="Path to the YAML configuration file")
    parser.add_argument(
        "--select",
        nargs="*",
        default=list(VARIABLES.keys()),
        help="Explicit variable names to emit",
    )
    args = parser.parse_args(list(argv))

    raw = load_raw_config(args.config)
    config = build_config(raw)

    unknown = sorted(set(args.select) - VARIABLES.keys())
    if unknown:
        for name in unknown:
            print(f"# Warning: unknown configuration key '{name}'", file=sys.stderr)

    for name in args.select:
        meta = VARIABLES.get(name)
        if not meta:
            continue
        value = resolve_value(config, meta["path"])
        line = format_value(name, value, meta)
        print(line)
    return 0


if __name__ == "__main__":  # pragma: no cover - manual execution
    raise SystemExit(main(sys.argv[1:]))
