#!/usr/bin/env python3
"""
RGB Launcher Backend
Loads RGB modes and pywal colors, outputs JSON for QML
"""

import json
import os
import sys
import tomllib
from pathlib import Path
from typing import List, Dict, Any


class RGBLauncher:
    def __init__(self, config_path: str = None):
        if config_path is None:
            config_path = Path.home() / ".config/quickshell/rgb-launcher/config.toml"

        self.config_path = Path(config_path)
        self.config = self.load_config()

    def load_config(self) -> Dict[str, Any]:
        """Load configuration from TOML file"""
        try:
            with open(self.config_path, 'rb') as f:
                return tomllib.load(f)
        except FileNotFoundError:
            print(f"Config file not found: {self.config_path}", file=sys.stderr)
            return self.get_default_config()
        except Exception as e:
            print(f"Error loading config: {e}", file=sys.stderr)
            return self.get_default_config()

    def get_default_config(self) -> Dict[str, Any]:
        """Return default configuration"""
        return {
            "openrgb": {
                "enabled": True
            },
            "appearance": {
                "use_pywal": True,
                "pywal_path": "~/.cache/wal/wal.json"
            }
        }

    def expand_path(self, path: str) -> Path:
        """Expand ~ and environment variables in path"""
        return Path(os.path.expanduser(os.path.expandvars(path)))

    def load_rgb_modes(self) -> List[Dict[str, Any]]:
        """Load RGB modes from config"""
        modes = []
        mode_configs = self.config.get("modes", [])

        for mode_config in mode_configs:
            mode = {
                "name": mode_config.get("name", "Unknown Mode"),
                "description": mode_config.get("description", ""),
                "command": mode_config.get("command", ""),
                "icon": mode_config.get("icon", "🎮"),
                "icon_font": mode_config.get("icon_font", ""),
                "icon_color": mode_config.get("icon_color", ""),
                "color_preview": mode_config.get("color_preview", "static"),
                "category": mode_config.get("category", "other")
            }
            modes.append(mode)

        return modes

    def load_pywal_colors(self) -> Dict[str, str]:
        """Load colors from pywal cache and flatten structure"""
        pywal_path = self.expand_path(
            self.config.get("appearance", {}).get("pywal_path", "~/.cache/wal/wal.json")
        )

        try:
            with open(pywal_path, 'r') as f:
                data = json.load(f)

            # Flatten the structure for easier QML access
            colors = {}

            # Add special colors (background, foreground, cursor)
            if "special" in data:
                colors.update(data["special"])

            # Add color palette (color0-color15)
            if "colors" in data:
                colors.update(data["colors"])

            return colors
        except Exception as e:
            print(f"Error loading pywal colors: {e}", file=sys.stderr)
            return {}

    def get_current_brightness(self) -> int:
        """Get current RGB brightness from file"""
        brightness_file = Path.home() / ".config/hypr/Openrgb/brightness.txt"
        try:
            if brightness_file.exists():
                with open(brightness_file, 'r') as f:
                    return int(f.read().strip())
        except Exception as e:
            print(f"Error reading brightness: {e}", file=sys.stderr)
        return 100  # Default brightness

    def get_all_modes(self) -> Dict[str, Any]:
        """Get all RGB modes and metadata"""
        modes = self.load_rgb_modes()

        pywal_colors = {}
        if self.config.get("appearance", {}).get("use_pywal", True):
            pywal_colors = self.load_pywal_colors()

        brightness = self.get_current_brightness()

        return {
            "modes": modes,
            "config": self.config,
            "colors": pywal_colors,
            "brightness": brightness
        }

    def output_json(self):
        """Output modes as JSON to stdout"""
        data = self.get_all_modes()
        print(json.dumps(data, indent=2))


def main():
    """Main entry point"""
    launcher = RGBLauncher()
    launcher.output_json()


if __name__ == "__main__":
    main()
