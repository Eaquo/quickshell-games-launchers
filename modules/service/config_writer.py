#!/usr/bin/env python3
"""Write config changes back to config.toml preserving comments (requires tomlkit)."""

import json
import sys
from pathlib import Path


def find_config():
    p = Path(__file__).parents[2] / "config.toml"
    return p if p.exists() else None


def main():
    try:
        import tomlkit
    except ImportError:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": "tomlkit not installed — run: pip install tomlkit",
                }
            ),
            flush=True,
        )
        sys.exit(1)

    try:
        payload = json.loads(sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read())
        path = find_config()
        if not path:
            print(
                json.dumps({"ok": False, "error": "config.toml not found"}), flush=True
            )
            sys.exit(1)

        with open(path) as f:
            doc = tomlkit.load(f)

        for section, values in payload.items():
            if section not in doc or not isinstance(values, dict):
                continue
            for key, val in values.items():
                if key in doc[section]:
                    if isinstance(val, list) and key == "entries":
                        aot = tomlkit.aot()
                        for entry in val:
                            t = tomlkit.table()
                            for ek, ev in entry.items():
                                t.add(ek, ev)
                            aot.append(t)
                        doc[section][key] = aot
                    else:
                        doc[section][key] = val
                else:
                    doc[section].add(key, val)

        with open(path, "w") as f:
            tomlkit.dump(doc, f)

        print(json.dumps({"ok": True}), flush=True)

    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}), flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
