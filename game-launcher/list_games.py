#!/usr/bin/env python3
"""
Game Library List Generator
Lists all detected games with their installation paths and sources
"""

import json
import sys
from pathlib import Path
from backend import GameLauncher


def main():
    """Generate a formatted list of all games with their paths"""
    launcher = GameLauncher()
    data = launcher.get_all_games()
    games = data.get("games", [])

    # Sort games by source then name
    games.sort(key=lambda g: (g.get("source", ""), g.get("name", "").lower()))

    print("=" * 80)
    print(" " * 25 + "GAME LIBRARY")
    print("=" * 80)
    print(f"\nTotal games found: {len(games)}\n")

    current_source = None
    for game in games:
        source = game.get("source", "unknown")
        name = game.get("name", "Unknown")
        exec_cmd = game.get("exec", "N/A")
        category = game.get("category", "")

        # Print source header
        if source != current_source:
            current_source = source
            source_names = {
                "steam": "STEAM GAMES",
                "epic": "EPIC GAMES STORE",
                "gog": "GOG GAMES",
                "amazon": "AMAZON GAMES",
                "heroic": "HEROIC SIDELOAD",
                "config": "CUSTOM LAUNCHERS",
                "manual": "MANUAL ENTRIES"
            }
            print("\n" + "-" * 80)
            print(f"  {source_names.get(source, source.upper())}")
            print("-" * 80 + "\n")

        # Print game info
        print(f"📦 {name}")
        if category:
            print(f"   Category: {category}")
        print(f"   Command:  {exec_cmd}")

        # Extract and print install path if available
        if "steam://rungameid/" in exec_cmd:
            app_id = exec_cmd.split("steam://rungameid/")[1].split()[0]
            print(f"   App ID:   {app_id}")
            # Try to find install path from Steam library
            import re
            found_path = False
            for lib_path_str in launcher.config.get("steam", {}).get("library_paths", []):
                lib_path = launcher.expand_path(lib_path_str)
                if lib_path.exists():
                    for acf_file in lib_path.glob("appmanifest_*.acf"):
                        try:
                            with open(acf_file, 'r', encoding='utf-8', errors='ignore') as f:
                                content = f.read()
                                # Check if this ACF file is for our app_id
                                appid_match = re.search(r'"appid"\s+"' + app_id + r'"', content)
                                if appid_match:
                                    # Extract install directory
                                    install_match = re.search(r'"installdir"\s+"([^"]+)"', content)
                                    if install_match:
                                        install_dir = install_match.group(1)
                                        full_path = lib_path.parent / "common" / install_dir
                                        print(f"   Path:     {full_path}")
                                        found_path = True
                                        break
                        except Exception as e:
                            pass
                    if found_path:
                        break

        elif source == "heroic" and "heroic://launch/" in exec_cmd:
            parts = exec_cmd.replace("heroic://launch/", "").split("/")
            if len(parts) >= 2:
                runner = parts[0]
                app_id = parts[1]
                print(f"   Runner:   {runner}")
                print(f"   App ID:   {app_id}")

        elif exec_cmd and not exec_cmd.startswith("steam") and not exec_cmd.startswith("heroic"):
            # For manual/config entries, the exec might contain the path
            print(f"   Path:     {exec_cmd.split()[0]}")

        print()

    print("=" * 80)
    print("\nPress ENTER to close...")
    input()


if __name__ == "__main__":
    main()
