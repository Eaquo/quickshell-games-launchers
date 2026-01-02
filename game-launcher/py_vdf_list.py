#!/usr/bin/env python3
"""
Script pour trouver les VRAIS AppID des jeux non-Steam
Utilise l'AppID stocké dans shortcuts.vdf au lieu de le calculer
"""

import vdf
import sys
import struct
import binascii
from pathlib import Path

def find_steam_userdata():
    """Trouve le répertoire userdata de Steam"""
    steam_path = Path.home() / ".local/share/Steam/userdata"
    if not steam_path.exists():
        print("❌ Steam userdata introuvable!")
        return None

    user_dirs = [d for d in steam_path.iterdir() if d.is_dir()]
    return user_dirs

def get_shortcuts(user_dir):
    """Charge les raccourcis d'un utilisateur"""
    vdf_path = user_dir / "config/shortcuts.vdf"

    if not vdf_path.exists():
        return None

    try:
        with open(vdf_path, 'rb') as f:
            return vdf.binary_load(f)
    except Exception as e:
        print(f"❌ Erreur lecture {vdf_path}: {e}")
        return None

def convert_appid_to_long(appid):
    """
    Convertit l'AppID court (depuis shortcuts.vdf) en AppID long (pour lancement)
    Méthode de @bkbilly sur GitHub
    """
    # Convert to HEX int32
    int32 = struct.Struct('<i')
    bin_appid = int32.pack(appid)
    hex_appid = binascii.hexlify(bin_appid).decode()

    # Convert to long_appid
    reversed_hex = bytes.fromhex(hex_appid)[::-1].hex()
    long_appid = int(reversed_hex, 16) << 32 | 0x02000000

    return long_appid

def main():
    search_term = sys.argv[1] if len(sys.argv) > 1 else None

    print("🔍 Recherche des jeux non-Steam...\n")

    user_dirs = find_steam_userdata()
    if not user_dirs:
        return

    found_games = []

    for user_dir in user_dirs:
        shortcuts = get_shortcuts(user_dir)
        if not shortcuts:
            continue

        user_id = user_dir.name
        print(f"📁 Utilisateur Steam: {user_id}")
        print("=" * 80)

        for idx, app in shortcuts.get('shortcuts', {}).items():
            app_name = app.get('AppName', 'Unknown')

            if search_term and search_term.lower() not in app_name.lower():
                continue

            exe = app.get('Exe', '')
            start_dir = app.get('StartDir', '')
            icon = app.get('icon', '')
            launch_options = app.get('LaunchOptions', '')

            # L'AppID est stocké directement dans shortcuts.vdf
            short_appid = app.get('appid', 0)

            # Conversion en long AppID (pour steam://rungameid/)
            long_appid = convert_appid_to_long(short_appid)

            found_games.append({
                'name': app_name,
                'short_appid': short_appid,
                'long_appid': long_appid,
                'exe': exe
            })

            print(f"\n🎮 {app_name}")
            print(f"   Exe: {exe}")
            if start_dir:
                print(f"   StartDir: {start_dir}")
            if icon:
                print(f"   Icône: {icon}")
            if launch_options:
                print(f"   Options: {launch_options}")
            print(f"\n   ✅ AppID court (protontricks): {short_appid}")
            print(f"   ✅ AppID long (steam://): {long_appid}")
            print(f"\n   📌 Commandes de lancement:")
            print(f"      steam steam://rungameid/{long_appid}")
            print(f"      steam -applaunch {short_appid}")
            print(f"      xdg-open steam://rungameid/{long_appid}")
            print(f"      protontricks {short_appid} --version")
            print("-" * 80)

    if not found_games:
        if search_term:
            print(f"❌ Aucun jeu trouvé contenant '{search_term}'")
        else:
            print("❌ Aucun jeu non-Steam trouvé")
    else:
        print(f"\n✅ {len(found_games)} jeu(x) trouvé(s)")

        # Propose de créer un raccourci
        if len(found_games) == 1:
            game = found_games[0]
            create_shortcut = input(f"\n❓ Créer un raccourci bureau pour '{game['name']}' ? (o/N): ")
            if create_shortcut.lower() == 'o':
                create_desktop_shortcut(game)

def create_desktop_shortcut(game):
    """Crée un raccourci .desktop"""
    desktop_path = Path.home() / "Desktop"
    if not desktop_path.exists():
        desktop_path = Path.home() / ".local/share/applications"

    # Nom de fichier sécurisé
    safe_name = "".join(c for c in game['name'] if c.isalnum() or c in (' ', '-', '_')).strip()
    filename = desktop_path / f"{safe_name}-Steam.desktop"

    content = f"""[Desktop Entry]
Name={game['name']} (Steam)
Comment=Lancé via Steam avec Proton
Exec=steam steam://rungameid/{game['long_appid']}
Type=Application
Categories=Game
StartupNotify=true
Terminal=false
"""

    try:
        with open(filename, 'w') as f:
            f.write(content)
        import os
        os.chmod(filename, 0o755)
        print(f"✅ Raccourci créé: {filename}")
    except Exception as e:
        print(f"❌ Erreur création raccourci: {e}")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Annulé")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Erreur: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
