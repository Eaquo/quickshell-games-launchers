from openrgb import OpenRGBClient
from openrgb.utils import RGBColor, DeviceType
import time, json, os, threading, random
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
PATH_SCRIPT = os.path.expanduser('~/.config/quickshell/rgb-launcher/script')
WALLUST_PATH = os.path.expanduser(PATH_SCRIPT + '/wal_rgb.json')

# --- Configuration multi-ports ---
PORT_FILE = os.path.expanduser(PATH_SCRIPT + '/current_port.txt')
DEFAULT_PORT = 6742

# --- Configuration luminosité ---
BRIGHTNESS_FILE = os.path.expanduser(PATH_SCRIPT + '/brightness.txt')
DEFAULT_BRIGHTNESS = 100

def get_brightness():
    """Récupère la luminosité depuis le fichier AGS (0-100)"""
    try:
        if os.path.exists(BRIGHTNESS_FILE):
            with open(BRIGHTNESS_FILE, 'r') as f:
                brightness = int(f.read().strip())
                if 0 <= brightness <= 100:
                    return brightness / 100.0
        return DEFAULT_BRIGHTNESS / 100.0
    except (FileNotFoundError, ValueError) as e:
        return DEFAULT_BRIGHTNESS / 100.0

def apply_brightness(color):
    """Applique la luminosité à une couleur RGBColor"""
    brightness = get_brightness()
    return RGBColor(
        int(color.red * brightness),
        int(color.green * brightness),
        int(color.blue * brightness)
    )

def get_openrgb_port():
    """Récupère le port OpenRGB depuis le fichier de config ou utilise le défaut"""
    try:
        if os.path.exists(PORT_FILE):
            with open(PORT_FILE, 'r') as f:
                port = int(f.read().strip())
                print(f"🔌 Utilisation du port OpenRGB: {port}")
                return port
        else:
            print(f"📁 Fichier de port non trouvé, utilisation du port par défaut: {DEFAULT_PORT}")
            return DEFAULT_PORT
    except (FileNotFoundError, ValueError) as e:
        print(f"⚠️  Erreur lecture port, utilisation du défaut: {e}")
        return DEFAULT_PORT

# --- Utilitaires ---
def hex_to_rgbcolor(hex_code):
    hex_code = hex_code.lstrip('#')
    r = int(hex_code[0:2], 16)
    g = int(hex_code[2:4], 16)
    b = int(hex_code[4:6], 16)
    return RGBColor(r, g, b)

def load_colors():
    with open(WALLUST_PATH) as f:
        wal = json.load(f)
    return [hex_to_rgbcolor(wal['colors'][f'color{i}']) for i in range(16)]

# --- Interpolation de couleurs pour transitions douces ---
def interpolate_color(color1, color2, factor):
    """
    Interpoler entre deux couleurs selon un facteur (0.0 à 1.0)
    0.0 = couleur1, 1.0 = couleur2
    """
    r = int(color1.red + (color2.red - color1.red) * factor)
    g = int(color1.green + (color2.green - color1.green) * factor)
    b = int(color1.blue + (color2.blue - color1.blue) * factor)
    return RGBColor(r, g, b)

# --- Détection changement WAL ---
class WalChangeHandler(FileSystemEventHandler):
    def __init__(self, on_change_callback):
        self.on_change_callback = on_change_callback

    def on_modified(self, event):
        if event.src_path == WALLUST_PATH:
            self.on_change_callback()

def reload_colors():
    global colors, colorA, colorB, colorC, colorD, colorE, colorF, colorG, colorH, colorI
    print("🔁 Reload WAL colors")
    colors = load_colors()
    colorA = colors[0]
    colorB = colors[2]
    colorC = colors[7]
    colorD = colors[12]
    colorE = colors[4]
    colorF = colors[15]
    colorG = colors[13]
    colorH = colors[1]
    colorI = colors[5]

# --- Connexion OpenRGB avec support multi-ports ---
openrgb_port = get_openrgb_port()
try:
    if openrgb_port != DEFAULT_PORT:
        client = OpenRGBClient(port=openrgb_port)
    else:
        client = OpenRGBClient()
    print(f"✅ Connexion OpenRGB établie sur le port {openrgb_port}")
except Exception as e:
    print(f"❌ Erreur connexion OpenRGB sur le port {openrgb_port}: {e}")
    print("🔄 Tentative sur le port par défaut...")
    try:
        client = OpenRGBClient()
        print("✅ Connexion OpenRGB établie sur le port par défaut")
    except Exception as e2:
        print(f"💥 Erreur critique de connexion OpenRGB: {e2}")
        exit(1)

devices = client.devices

# Vérification et attribution des périphériques
try:
    ram_devices = [d for d in devices if d.name == "Corsair Vengeance Pro RGB"]
    node_pro = next(d for d in devices if d.name == "Corsair Lighting Node Pro")
    mobo = next(d for d in devices if d.type == DeviceType.MOTHERBOARD)
    
    print(f"🎮 Périphériques détectés:")
    print(f"   - RAM: {len(ram_devices)} modules")
    print(f"   - Node Pro: {node_pro.name}")
    print(f"   - Carte mère: {mobo.name}")
    
except StopIteration as e:
    print(f"❌ Périphérique manquant: {e}")
    print("📋 Périphériques disponibles:")
    for i, device in enumerate(devices):
        print(f"   {i}: {device.name} (Type: {device.type})")
    exit(1)

colors = load_colors()
reload_colors()

last_colors = {}
last_modes = {}

PREFERRED_MODES = ["Direct", "Static"]

# Reset composant
def reset_device(device):
    try:
        set_best_mode(device)
        device.set_color(RGBColor(0, 0, 0))  # noir temporaire
        time.sleep(0.1)
    except Exception as e:
        print(f"⚠️ Erreur reset sur {device.name}: {e}")

def set_mode_safe(device, target_mode_name):
    for mode in device.modes:
        if mode.name.lower() == target_mode_name.lower():
            if last_modes.get(device) != mode.name:
                device.set_mode(mode)
                last_modes[device] = mode.name
            return
    print(f"⚠️ Mode '{target_mode_name}' non disponible pour {device.name}")

def set_best_mode(device):
    """
    Essaie d'activer le meilleur mode disponible dans PREFERRED_MODES.
    Si un mode échoue à la validation, on passe au suivant.
    """
    for mode_name in PREFERRED_MODES:
        for mode in device.modes:
            if mode.name.lower() == mode_name.lower():
                try:
                    mode.validate(device.comms._protocol_version)
                    if last_modes.get(device) != mode.name:
                        device.set_mode(mode)
                        last_modes[device] = mode.name
                    return
                except Exception as e:
                    print(f"⚠️ Le mode '{mode_name}' a échoué sur {device.name}: {e}")
    print(f"⚠️ Aucun mode valide trouvé pour {device.name}")
    
def smart_set_color(device, color):
    # Appliquer la luminosité à la couleur avant de l'envoyer
    adjusted_color = apply_brightness(color)
    if last_colors.get(device) != adjusted_color:
        device.set_color(adjusted_color)
        last_colors[device] = adjusted_color

def set_static(device, color):
    set_mode_safe(device, "Static")
    smart_set_color(device, color)

def smooth_transition(device, start_color, end_color, duration=1.0, steps=20):
    """
    Effectue une transition douce entre deux couleurs
    """
    set_best_mode(device)
    step_time = duration / steps

    for step in range(steps + 1):
        factor = step / steps
        current_color = interpolate_color(start_color, end_color, factor)
        # Appliquer la luminosité
        device.set_color(apply_brightness(current_color))
        time.sleep(step_time)

def base_with_active_led(device, base_color, active_color, duration=50, speed=0.5, leds_per_fan=8):
    """
    Active une LED aléatoire par ventilateur.
    """
    set_best_mode(device)
    led_count = len(device.leds)
    start_time = time.time()

    # Calculer le nombre de ventilateurs
    fan_count = led_count // leds_per_fan
    if fan_count == 0:
        fan_count = 1  # Au moins un ventilateur même si LEDs insuffisantes

    print(f"Dispositif: {device.name}, LEDs: {led_count}, Ventilateurs calculés: {fan_count}")

    # Appliquer la luminosité aux couleurs de base et active
    adjusted_base = apply_brightness(base_color)
    adjusted_active = apply_brightness(active_color)

    while time.time() - start_time < duration:
        # Réinitialiser toutes les LEDs à la couleur de base
        colors = [adjusted_base] * led_count

        # Pour chaque ventilateur, activer une LED aléatoire
        for fan_index in range(fan_count):
            # Calculer la plage d'indices pour ce ventilateur
            fan_start = fan_index * leds_per_fan
            fan_end = min(fan_start + leds_per_fan, led_count)

            if fan_end > fan_start:  # S'assurer qu'il y a des LEDs disponibles pour ce ventilateur
                # Choisir une LED aléatoire dans la plage de ce ventilateur
                active_led_index = random.randint(fan_start, fan_end - 1)
                colors[active_led_index] = adjusted_active

        # Appliquer les couleurs au dispositif
        device.set_colors(colors)
        time.sleep(speed)

# --- Gestion des transitions entre phases ---
def transition_to_phase(ram_devices, node_pro, mobo, 
                        ram_base_from, ram_base_to, 
                        ram_active_from, ram_active_to, 
                        mobo_from, mobo_to, 
                        transition_duration=0.1):
    """
    Effectue une transition douce entre deux phases d'animation
    """
    print("🔄 Transition vers nouvelle phase...")
    
    # Transition pour la carte mère
    mobo_thread = threading.Thread(
        target=smooth_transition, 
        args=(mobo, mobo_from, mobo_to, transition_duration)
    )
    mobo_thread.start()
    
    # Pour le moment, les transitions sur les RAM et Node Pro sont simplifiées
    # car nous utilisons des effets complexes avec plusieurs couleurs
    # Nous effectuons simplement une brève pause pour synchroniser avec la transition de la carte mère
    time.sleep(transition_duration)
    
    mobo_thread.join()
    print("✅ Transition terminée")

# --- Watcher WAL ---
handler = WalChangeHandler(reload_colors)
observer = Observer()
observer.schedule(handler, path=os.path.dirname(WALLUST_PATH), recursive=False)
observer_thread = threading.Thread(target=observer.start)
observer_thread.daemon = True
observer_thread.start()

# --- Boucle principale ---
try:
    # Forcer un reset au début du programme
    print("🔄 Initialisation des périphériques RGB...")
    for ram in ram_devices:
        reset_device(ram)
    reset_device(node_pro)
    reset_device(mobo)
    
    # Couleur initiale
    current_mobo_color = colorA
    set_static(mobo, current_mobo_color)
    
    # Pour garder une trace des couleurs actuelles pour les transitions
    current_ram_base = colorA
    current_ram_active = colorB

    print("🎨 Démarrage de l'animation RGB synchronisée avec Wallust")
    
    while True:
        print("🌈 Phase 1")
        # Transition vers Phase 1
        transition_to_phase(ram_devices, node_pro, mobo, 
                           current_ram_base, colorA, 
                           current_ram_active, colorB, 
                           current_mobo_color, colorC)
        
        current_ram_base = colorG
        current_ram_active = colorG
        current_mobo_color = colorG
        
        set_static(mobo, colorG)
        ram_threads = [
            threading.Thread(target=base_with_active_led, args=(ram, colorA, colorI, 20, 0.5, 8))
            for ram in ram_devices
        ]
        node_thread = threading.Thread(target=base_with_active_led, args=(node_pro, colorA, colorI, 20, 0.5, 8))

        for t in ram_threads:
            t.start()
        node_thread.start()
        for t in ram_threads:
            t.join()
        node_thread.join()

        print("🌈 Phase 2")
        # Transition vers Phase 2
        transition_to_phase(ram_devices, node_pro, mobo, 
                           current_ram_base, colorG, 
                           current_ram_active, colorC, 
                           current_mobo_color, colorD)
        
        current_ram_base = colorG
        current_ram_active = colorC
        current_mobo_color = colorD
        
        set_static(mobo, colorD)
        ram_threads = [
            threading.Thread(target=base_with_active_led, args=(ram, colorG, colorB, 20, 0.5, 8))
            for ram in ram_devices
        ]
        node_thread = threading.Thread(target=base_with_active_led, args=(node_pro, colorG, colorB, 20, 0.5, 8))

        for t in ram_threads:
            t.start()
        node_thread.start()
        for t in ram_threads:
            t.join()
        node_thread.join()

        print("🌈 Phase 3")
        # Transition vers Phase 3
        transition_to_phase(ram_devices, node_pro, mobo, 
                           current_ram_base, colorC, 
                           current_ram_active, colorG, 
                           current_mobo_color, colorE)
        
        current_ram_base = colorC
        current_ram_active = colorG
        current_mobo_color = colorE
        
        ram_threads = [
            threading.Thread(target=base_with_active_led, args=(ram, colorC, colorI, 20, 0.5, 8))
            for ram in ram_devices
        ]
        node_thread = threading.Thread(target=base_with_active_led, args=(node_pro, colorC, colorI, 20, 0.5, 8))

        for t in ram_threads:
            t.start()
        node_thread.start()
        for t in ram_threads:
            t.join()
        node_thread.join()

        print("🌈 Phase 4")
        # Transition vers Phase 4
        transition_to_phase(ram_devices, node_pro, mobo, 
                           current_ram_base, colorD, 
                           current_ram_active, colorI, 
                           current_mobo_color, colorF)
        
        current_ram_base = colorD
        current_ram_active = colorI
        current_mobo_color = colorF
        
        set_static(mobo, colorF)
        ram_threads = [
            threading.Thread(target=base_with_active_led, args=(ram, colorD, colorI, 20, 0.5, 8))
            for ram in ram_devices
        ]
        node_thread = threading.Thread(target=base_with_active_led, args=(node_pro, colorD, colorI, 20, 0.5, 8))

        for t in ram_threads:
            t.start()
        node_thread.start()
        for t in ram_threads:
            t.join()
        node_thread.join()

except KeyboardInterrupt:
    print("🛑 Animation stoppée par l'utilisateur.")
    for device in ram_devices + [node_pro, mobo]:
        try:
            set_static(device, colorA)
        except:
            pass
except Exception as e:
    print(f"💥 Erreur inattendue: {e}")
    # Essayer de remettre en état normal
    try:
        for device in ram_devices + [node_pro, mobo]:
            set_static(device, RGBColor(255, 255, 255))  # Blanc de sécurité
    except:
        pass
    raise