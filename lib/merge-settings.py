#!/usr/bin/env python3
"""
merge-settings.py — merge a partial settings patch into ~/.claude/settings.json
Usage: python3 merge-settings.py <patch.json>

Patch file is a JSON object. Keys are merged (shallow for top-level,
deep for nested objects). Does not delete existing keys.
"""

import json
import sys
import os
from pathlib import Path


def deep_merge(base: dict, patch: dict) -> dict:
    result = dict(base)
    for key, val in patch.items():
        if key in result and isinstance(result[key], dict) and isinstance(val, dict):
            result[key] = deep_merge(result[key], val)
        else:
            result[key] = val
    return result


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <patch.json>", file=sys.stderr)
        sys.exit(1)

    patch_path = Path(sys.argv[1])
    if not patch_path.exists():
        print(f"patch file not found: {patch_path}", file=sys.stderr)
        sys.exit(1)

    settings_path = Path.home() / ".claude" / "settings.json"

    base = {}
    if settings_path.exists():
        try:
            base = json.loads(settings_path.read_text())
        except json.JSONDecodeError as e:
            print(f"settings.json is malformed: {e}", file=sys.stderr)
            sys.exit(1)

    try:
        patch = json.loads(patch_path.read_text())
    except json.JSONDecodeError as e:
        print(f"patch file is malformed: {e}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(patch, dict):
        print(f"patch file must be a JSON object, got {type(patch).__name__}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(base, dict):
        base = {}
    merged = deep_merge(base, patch)

    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(json.dumps(merged, indent=2) + "\n")
    print(f"merged {len(patch)} key(s) into {settings_path}")


if __name__ == "__main__":
    main()
