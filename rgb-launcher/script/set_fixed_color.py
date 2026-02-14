#!/usr/bin/env python3
"""
Script simple pour appliquer une couleur fixe aux LEDs RGB
Usage: python set_fixed_color.py #FF0000
"""

import sys
import os
from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

def get_port():
    """Récupère le port OpenRGB"""
    port_file = os.path.expanduser('~/.config/hypr/Openrgb/current_port.txt')
    try:
        if os.path.exists(port_file):
            with open(port_file, 'r') as f:
                return int(f.read().strip())
    except:
        pass
    return 6742

def get_brightness():
    """Récupère la luminosité depuis le fichier AGS"""
    brightness_file = os.path.expanduser('~/.config/hypr/Openrgb/brightness.txt')
    try:
        if os.path.exists(brightness_file):
            with open(brightness_file, 'r') as f:
                brightness = int(f.read().strip())
                return brightness / 100.0
    except:
        pass
    return 1.0

def hex_to_rgb(hex_color):
    """Convertit une couleur hex en RGBColor"""
    hex_color = hex_color.lstrip('#')
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    return RGBColor(r, g, b)

def apply_brightness(color, brightness):
    """Applique la luminosité à une couleur"""
    return RGBColor(
        int(color.red * brightness),
        int(color.green * brightness),
        int(color.blue * brightness)
    )

def set_fixed_color(hex_color):
    """Applique une couleur fixe à tous les périphériques"""
    try:
        port = get_port()
        brightness = get_brightness()
        client = OpenRGBClient(port=port)

        color = hex_to_rgb(hex_color)
        color = apply_brightness(color, brightness)

        print(f"🎨 Application couleur: {hex_color} (luminosité: {int(brightness*100)}%)")

        for device in client.devices:
            try:
                # Cherche un mode statique ou direct
                mode_name = None
                for mode in device.modes:
                    if mode.name.lower() in ['static', 'direct']:
                        mode_name = mode.name
                        break

                if mode_name:
                    device.set_mode(mode_name)

                device.set_color(color)
                print(f"  ✅ {device.name}")
            except Exception as e:
                print(f"  ⚠️  {device.name}: {e}")

        # Écrire dans sequence.txt
        seq_file = os.path.expanduser('~/.config/hypr/Openrgb/sequence.txt')
        with open(seq_file, 'w') as f:
            f.write(f"fixed_{hex_color}")

        print(f"✅ Couleur appliquée!")

    except Exception as e:
        print(f"❌ Erreur: {e}")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python set_fixed_color.py #FF0000")
        sys.exit(1)

    hex_color = sys.argv[1]
    set_fixed_color(hex_color)
