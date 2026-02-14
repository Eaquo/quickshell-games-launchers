#!/usr/bin/env python3
"""
OpenRGB Controller avec modes multiples
Contrôleur RGB avec différents modes d'animation
"""

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor, DeviceType
import time, json, os, threading, random, sys, math
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

SCRIPT_PATH = os.path.expanduser('~/.config/quickshell/rgb-launcher/script')

class OpenRGBController:
    def __init__(self):
        self.WALLUST_PATH = os.path.expanduser(f'{SCRIPT_PATH}/wal_rgb.json')
        self.PORT_FILE = os.path.expanduser(f'{SCRIPT_PATH}/current_port.txt')
        self.STATUS_FILE = os.path.expanduser(f'{SCRIPT_PATH}/sequence.txt')
        self.BRIGHTNESS_FILE = os.path.expanduser(f'{SCRIPT_PATH}/brightness.txt')
        self.DEFAULT_PORT = 6742
        
        # État du contrôleur
        self.current_mode = "off"
        self.running = False
        self.animation_thread = None
        
        # Connexion OpenRGB
        self.setup_openrgb()
        
        # Chargement des couleurs
        self.load_colors()
        
        # Variables pour optimisation
        self.last_colors = {}
        self.last_modes = {}
        self.PREFERRED_MODES = ["Direct", "Static"]
    
    def get_openrgb_port(self):
        """Récupère le port OpenRGB depuis le fichier de config"""
        try:
            if os.path.exists(self.PORT_FILE):
                with open(self.PORT_FILE, 'r') as f:
                    port = int(f.read().strip())
                    print(f"🔌 Port OpenRGB: {port}")
                    return port
            else:
                print(f"📄 Port par défaut: {self.DEFAULT_PORT}")
                return self.DEFAULT_PORT
        except (FileNotFoundError, ValueError) as e:
            print(f"⚠️ Erreur lecture port: {e}")
            return self.DEFAULT_PORT
    
    def setup_openrgb(self):
        """Établit la connexion OpenRGB"""
        openrgb_port = self.get_openrgb_port()
        try:
            if openrgb_port != self.DEFAULT_PORT:
                self.client = OpenRGBClient(port=openrgb_port)
            else:
                self.client = OpenRGBClient()
            print(f"✅ Connexion OpenRGB sur port {openrgb_port}")
        except Exception as e:
            print(f"❌ Erreur connexion sur port {openrgb_port}: {e}")
            try:
                self.client = OpenRGBClient()
                print("✅ Connexion sur port par défaut")
            except Exception as e2:
                print(f"💥 Erreur critique: {e2}")
                sys.exit(1)
        
        # Identification des périphériques
        self.devices = self.client.devices
        print("🔍 Périphériques disponibles:")
        for i, device in enumerate(self.devices):
            print(f"   {i}: {device.name} (Type: {device.type})")
        
        try:
            self.ram_devices = [d for d in self.devices if "Corsair Vengeance Pro RGB" in d.name]
            self.node_pro = next(d for d in self.devices if "Corsair Lighting Node Pro" in d.name)
            self.mobo = next(d for d in self.devices if d.type == DeviceType.MOTHERBOARD)
            
            # Détection automatique de la carte graphique
            self.gpu = None
            
            # Méthode 1: Par type de périphérique
            gpu_candidates = [d for d in self.devices if d.type == DeviceType.GPU]
            if gpu_candidates:
                self.gpu = gpu_candidates[0]
                print(f"🎮 GPU détectée par type: {self.gpu.name}")
            
            # Méthode 2: Par nom (si la méthode 1 échoue)
            if not self.gpu:
                gpu_keywords = ["NVIDIA", "AMD", "Radeon", "GeForce", "RTX", "GTX", "RX"]
                for device in self.devices:
                    if any(keyword.lower() in device.name.lower() for keyword in gpu_keywords):
                        self.gpu = device
                        print(f"🎮 GPU détectée par nom: {self.gpu.name}")
                        break
            
            print(f"🎮 Périphériques détectés:")
            print(f"   - RAM: {len(self.ram_devices)} modules")
            print(f"   - Node Pro: {self.node_pro.name}")
            print(f"   - Carte mère: {self.mobo.name}")
            if self.gpu:
                print(f"   - GPU: {self.gpu.name}")
                print(f"     Modes disponibles: {[mode.name for mode in self.gpu.modes]}")
                print(f"     Nombre de LEDs: {len(self.gpu.leds)}")
            else:
                print("   - GPU: Non détectée")
            
        except StopIteration:
            print("❌ Périphérique manquant")
            for i, device in enumerate(self.devices):
                print(f"   {i}: {device.name} (Type: {device.type})")
            sys.exit(1)
    
    def get_all_devices(self):
        """Retourne tous les périphériques contrôlables"""
        devices = self.ram_devices + [self.node_pro, self.mobo]
        if self.gpu:
            devices.append(self.gpu)
        return devices
    
    def hex_to_rgbcolor(self, hex_code):
        """Convertit hex en RGBColor"""
        hex_code = hex_code.lstrip('#')
        r = int(hex_code[0:2], 16)
        g = int(hex_code[2:4], 16)
        b = int(hex_code[4:6], 16)
        return RGBColor(r, g, b)
    
    def load_colors(self):
        """Charge les couleurs depuis wallust"""
        try:
            with open(self.WALLUST_PATH) as f:
                wal = json.load(f)
            colors = [self.hex_to_rgbcolor(wal['colors'][f'color{i}']) for i in range(16)]
            
            # Attribution des couleurs nommées
            self.colorA = colors[0]   # Couleur principale
            self.colorB = colors[2]   # Accent 1
            self.colorC = colors[7]   # Accent 2
            self.colorD = colors[12]  # Accent 3
            self.colorE = colors[4]   # Accent 4
            self.colorF = colors[15]  # Couleur claire
            self.colorG = colors[13]  # Couleur moyenne
            self.colorH = colors[1]   # Couleur sombre
            self.colorI = colors[5]   # Accent 5a
            self.colorJ = colors[14]   # Accent 5b
            
            print("🎨 Couleurs chargées depuis wallust")
        except Exception as e:
            print(f"⚠️ Erreur chargement couleurs: {e}")
            # Couleurs par défaut
            self.colorA = RGBColor(255, 0, 0)
            self.colorB = RGBColor(0, 255, 0)
            self.colorC = RGBColor(0, 0, 255)
            self.colorD = RGBColor(255, 255, 0)
            self.colorE = RGBColor(255, 0, 255)
            self.colorF = RGBColor(255, 255, 255)
            self.colorG = RGBColor(128, 128, 128)
            self.colorH = RGBColor(64, 64, 64)
            self.colorI = RGBColor(0, 255, 255)
            self.colorJ = RGBColor(255, 165, 0)
    
    def get_brightness(self):
        """Récupère la luminosité actuelle (0.0 à 1.0)"""
        try:
            if os.path.exists(self.BRIGHTNESS_FILE):
                with open(self.BRIGHTNESS_FILE, 'r') as f:
                    brightness = int(f.read().strip())
                    return max(0, min(100, brightness)) / 100.0
        except:
            pass
        return 1.0

    def set_best_mode(self, device):
        """Active le meilleur mode disponible"""
        for mode_name in self.PREFERRED_MODES:
            for mode in device.modes:
                if mode.name.lower() == mode_name.lower():
                    try:
                        if self.last_modes.get(device) != mode.name:
                            device.set_mode(mode)
                            self.last_modes[device] = mode.name
                        return
                    except Exception as e:
                        print(f"⚠️ Mode '{mode_name}' échoué sur {device.name}: {e}")
    
    def smart_set_color(self, device, color):
        """Optimise les changements de couleur"""
        adjusted_color = self.apply_brightness(color)
        if self.last_colors.get(device) != adjusted_color:
            device.set_color(adjusted_color)
            self.last_colors[device] = adjusted_color
    
    def set_static(self, device, color):
        """Applique une couleur statique"""
        self.set_best_mode(device)
        self.smart_set_color(device, color)
    
    def interpolate_color(self, color1, color2, factor):
        """Interpolation entre deux couleurs"""
        r = int(color1.red + (color2.red - color1.red) * factor)
        g = int(color1.green + (color2.green - color1.green) * factor)
        b = int(color1.blue + (color2.blue - color1.blue) * factor)
        return RGBColor(r, g, b)
    
    def smooth_transition(self, device, start_color, end_color, duration=1.0, steps=20):
        """Transition douce entre couleurs"""
        self.set_best_mode(device)
        step_time = duration / steps
        
        for step in range(steps + 1):
            if not self.running:
                break
            factor = step / steps
            current_color = self.interpolate_color(start_color, end_color, factor)
            adjusted_color = self.apply_brightness(current_color)
            device.set_color(adjusted_color)
            time.sleep(step_time)
    
    def base_with_active_led(self, device, base_color, active_color, duration=50, speed=0.5, leds_per_fan=8):
        """Animation LED aléatoire par ventilateur"""
        self.set_best_mode(device)
        led_count = len(device.leds)
        start_time = time.time()
        
        fan_count = max(1, led_count // leds_per_fan)
        
        while time.time() - start_time < duration and self.running:
            colors = [base_color] * led_count
            
            for fan_index in range(fan_count):
                fan_start = fan_index * leds_per_fan
                fan_end = min(fan_start + leds_per_fan, led_count)
                
                if fan_end > fan_start:
                    active_led_index = random.randint(fan_start, fan_end - 1)
                    colors[active_led_index] = active_color
            
            adjusted_colors = [self.apply_brightness(c) for c in colors]
            device.set_colors(adjusted_colors)
            time.sleep(speed)
    
    def mode_off(self):
        """Mode éteint - toutes les lumières noires"""
        print("🌑 Mode OFF")
        black = RGBColor(0, 0, 0)
        for device in self.get_all_devices():
            self.set_static(device, black)
    
    def mode_sequence_1(self):
        """Séquence 1 - Animation originale avec transitions fluides"""
        print("🌈 Séquence 1")
        
        while self.running and self.current_mode == "sequence_1":
            # Phase 1
            print("🌈 Phase 1")
            self.set_static(self.mobo, self.colorG)
            if self.gpu:
                gpu_thread = threading.Thread(target=self.smooth_transition,
                                             args=(self.gpu, self.last_colors.get(self.gpu, RGBColor(0,0,0)), self.colorI, 1.0))
                gpu_thread.start()
                gpu_thread.join()
            
            # Animation RAM et Node Pro
            ram_threads = [
                threading.Thread(target=self.base_with_active_led, 
                                args=(ram, self.colorA, self.colorJ, 20, 0.5, 8))
                for ram in self.ram_devices
            ]
            node_thread = threading.Thread(target=self.base_with_active_led,
                                          args=(self.node_pro, self.colorA, self.colorJ, 20, 0.5, 8))
            
            for t in ram_threads + [node_thread]:
                t.start()
            for t in ram_threads + [node_thread]:
                t.join()
            
            if not self.running or self.current_mode != "sequence_1":
                break
            
            # Phase 2
            print("🌈 Phase 2")
            self.set_static(self.mobo, self.colorD)
            if self.gpu:
                self.set_static(self.gpu, self.colorH)
            
            ram_threads = [
                threading.Thread(target=self.base_with_active_led,
                                args=(ram, self.colorG, self.colorB, 20, 0.5, 8))
                for ram in self.ram_devices
            ]
            node_thread = threading.Thread(target=self.base_with_active_led,
                                          args=(self.node_pro, self.colorG, self.colorB, 20, 0.5, 8))
            
            for t in ram_threads + [node_thread]:
                t.start()
            for t in ram_threads + [node_thread]:
                t.join()
            
            if not self.running or self.current_mode != "sequence_1":
                break
            
            # Phase 3
            print("🌈 Phase 3")
            self.set_static(self.mobo, self.colorE)
            if self.gpu:
                self.set_static(self.gpu, self.colorE)
            
            ram_threads = [
                threading.Thread(target=self.base_with_active_led,
                                args=(ram, self.colorC, self.colorI, 20, 0.5, 8))
                for ram in self.ram_devices
            ]
            node_thread = threading.Thread(target=self.base_with_active_led,
                                          args=(self.node_pro, self.colorC, self.colorI, 20, 0.5, 8))
            
            for t in ram_threads + [node_thread]:
                t.start()
            for t in ram_threads + [node_thread]:
                t.join()
            
            if not self.running or self.current_mode != "sequence_1":
                break
            
            # Phase 4
            print("🌈 Phase 4")
            self.set_static(self.mobo, self.colorF)
            if self.gpu:
                self.set_static(self.gpu, self.colorB)
            
            ram_threads = [
                threading.Thread(target=self.base_with_active_led,
                                args=(ram, self.colorD, self.colorI, 20, 0.5, 8))
                for ram in self.ram_devices
            ]
            node_thread = threading.Thread(target=self.base_with_active_led,
                                          args=(self.node_pro, self.colorD, self.colorI, 20, 0.5, 8))
            
            for t in ram_threads + [node_thread]:
                t.start()
            for t in ram_threads + [node_thread]:
                t.join()
    
    def mode_sequence_2(self):
        """Séquence 2 - Vagues de couleur"""
        print("🌊 Séquence 2")
        colors_cycle = [self.colorA, self.colorB, self.colorC, self.colorD, self.colorE]
        
        while self.running and self.current_mode == "sequence_2":
            for color in colors_cycle:
                if not self.running or self.current_mode != "sequence_2":
                    break
                    
                # Transition douce sur tous les périphériques (y compris GPU)
                threads = []
                all_devices = self.get_all_devices()
                for device in all_devices:
                    thread = threading.Thread(target=self.smooth_transition, 
                                            args=(device, self.last_colors.get(device, RGBColor(0,0,0)), color, 2.0))
                    threads.append(thread)
                    thread.start()
                
                for thread in threads:
                    thread.join()
                
                time.sleep(3)
    
    def mode_sequence_3(self):
        """Séquence 3 - Respiration synchronisée"""
        print("💨 Séquence 3")
        
        while self.running and self.current_mode == "sequence_3":
            # Respiration montante
            for i in range(0, 256, 5):
                if not self.running or self.current_mode != "sequence_3":
                    break
                intensity = i / 255.0
                
                breath_color = RGBColor(
                    int((self.colorA.red + self.colorD.red) / 2 * intensity),
                    int((self.colorB.green + self.colorE.green) / 2 * intensity),
                    int((self.colorC.blue + self.colorF.blue) / 2 * intensity)
                )
                
                for device in self.get_all_devices():
                    self.set_static(device, breath_color)
                time.sleep(0.02)
            
            # Respiration descendante
            for i in range(255, 0, -5):
                if not self.running or self.current_mode != "sequence_3":
                    break
                intensity = i / 255.0
                
                breath_color = RGBColor(
                    int((self.colorA.red + self.colorD.red) / 2 * intensity),
                    int((self.colorB.green + self.colorE.green) / 2 * intensity),
                    int((self.colorC.blue + self.colorF.blue) / 2 * intensity)
                )
                
                for device in self.get_all_devices():
                    self.set_static(device, breath_color)
                time.sleep(0.02)
    
    def mode_sequence_4(self):
        """Séquence 4 - Cyberpunk Matrix avec effets néon et balayages"""
        print("🌆 Séquence 4 - Cyberpunk Mode")
        
        # Couleurs cyberpunk
        neon_primary = self.colorJ
        neon_secondary = self.colorB
        matrix_green = self.colorI
        danger_red = self.colorH
        shadow_color = self.colorA
        highlight = self.colorF
        
        cycle_count = 0
        
        while self.running and self.current_mode == "sequence_4":
            cycle_count += 1
            
            # Phase 1: Data Stream
            print("🌆 Phase 1: Data Stream")
            self.set_static(self.mobo, shadow_color)
            if self.gpu:
                self.set_static(self.gpu, self.interpolate_color(shadow_color, neon_primary, 0.3))
            
            for wave_cycle in range(3):
                if not self.running or self.current_mode != "sequence_4":
                    break
                
                for device in self.ram_devices + [self.node_pro]:
                    self.set_best_mode(device)
                    led_count = len(device.leds)
                    
                    for position in range(led_count + 8):
                        if not self.running or self.current_mode != "sequence_4":
                            break
                            
                        colors = [shadow_color] * led_count
                        
                        for i in range(max(0, position-6), min(led_count, position-2)):
                            colors[i] = self.interpolate_color(shadow_color, matrix_green, 0.3)
                        
                        for i in range(max(0, position-2), min(led_count, position)):
                            colors[i] = matrix_green
                        
                        if 0 <= position < led_count:
                            colors[position] = neon_primary
                        
                        device.set_colors(colors)
                        time.sleep(0.08)
            
            if not self.running or self.current_mode != "sequence_4":
                break
            
            # Phase 2: Neon Glitch
            print("🌆 Phase 2: Neon Glitch")
            glitch_colors = [danger_red, neon_primary, matrix_green, highlight]
            for glitch_round in range(8):
                if not self.running or self.current_mode != "sequence_4":
                    break
                
                # Glitch sur tous les périphériques
                for device in self.get_all_devices():
                    if random.random() < 0.6:
                        glitch_color = random.choice(glitch_colors)
                        self.set_static(device, glitch_color)
                
                time.sleep(0.1)
                
                for device in self.get_all_devices():
                    self.set_static(device, shadow_color)
                
                time.sleep(0.05)
            
            if not self.running or self.current_mode != "sequence_4":
                break
            
            # Phase 3: Cyberpunk Pulse
            print("🌆 Phase 3: Cyberpunk Pulse")
            for pulse_cycle in range(2):
                if not self.running or self.current_mode != "sequence_4":
                    break
                
                # Montée
                for intensity in range(0, 256, 12):
                    if not self.running or self.current_mode != "sequence_4":
                        break
                    
                    factor = intensity / 255.0
                    
                    self.set_static(self.mobo, self.interpolate_color(shadow_color, neon_secondary, factor))
                    if self.gpu:
                        self.set_static(self.gpu, self.interpolate_color(shadow_color, highlight, factor))
                    
                    for device in self.ram_devices + [self.node_pro]:
                        pulse_color = self.interpolate_color(shadow_color, neon_primary, factor)
                        self.set_static(device, pulse_color)
                    
                    time.sleep(0.03)
                
                time.sleep(0.2)
                
                # Descente
                for intensity in range(255, 0, -15):
                    if not self.running or self.current_mode != "sequence_4":
                        break
                    
                    factor = intensity / 255.0
                    
                    for device in self.get_all_devices():
                        pulse_color = self.interpolate_color(shadow_color, neon_primary, factor)
                        self.set_static(device, pulse_color)
                    
                    time.sleep(0.02)
            
            time.sleep(0.5)
    
    def mode_sequence_5(self):
        """Séquence 5 - Matrix Digital Rain avec effets de code défilant"""
        print("💚 Séquence 5 - Matrix Mode")
        
        # Couleurs Matrix
        matrix_main = self.colorE
        matrix_bright = self.colorF
        matrix_medium = self.colorG
        matrix_dim = self.colorH
        matrix_accent = self.colorI
        glitch_color = self.colorA
        background = RGBColor(0, 0, 0)
        
        cycle_count = 0
        
        while self.running and self.current_mode == "sequence_5":
            cycle_count += 1
            
            # Phase 1: System Boot
            print("💚 Phase 1: System Boot")
            boot_colors = [background, matrix_dim, matrix_medium, matrix_main, matrix_bright]
            for boot_color in boot_colors:
                if not self.running or self.current_mode != "sequence_5":
                    break
                for device in self.get_all_devices():
                    self.set_static(device, boot_color)
                time.sleep(0.3)
            
            if not self.running or self.current_mode != "sequence_5":
                break
            
            # Phase 2: Digital Rain
            print("💚 Phase 2: Digital Rain")
            for rain_cycle in range(25):
                if not self.running or self.current_mode != "sequence_5":
                    break
                
                # Pulsation carte mère et GPU
                pulse_intensity = (math.sin(rain_cycle * 0.2) + 1) / 2
                mobo_pulse = self.interpolate_color(matrix_dim, matrix_medium, pulse_intensity)
                self.set_static(self.mobo, mobo_pulse)
                if self.gpu:
                    gpu_pulse = self.interpolate_color(matrix_accent, matrix_main, pulse_intensity)
                    self.set_static(self.gpu, gpu_pulse)
                
                # Colonnes de code sur RAM et Node Pro
                for device in self.ram_devices + [self.node_pro]:
                    self.set_best_mode(device)
                    led_count = len(device.leds)
                    colors = [background] * led_count
                    
                    columns_count = random.randint(2, 4)
                    for _ in range(columns_count):
                        column_start = random.randint(0, led_count-1)
                        column_length = random.randint(3, 6)
                        
                        for i in range(column_length):
                            led_pos = (column_start + i) % led_count
                            if i == 0:
                                colors[led_pos] = matrix_bright
                            elif i == 1:
                                colors[led_pos] = matrix_main
                            elif i == 2:
                                colors[led_pos] = matrix_medium
                            else:
                                colors[led_pos] = matrix_dim
                    
                    device.set_colors(colors)
                time.sleep(0.12)
            
            time.sleep(1)

    def mode_sequence_6(self):
        """Séquence 6 - Aurora Borealis avec vagues ondulantes"""
        print("🌌 Séquence 6 - Aurora Borealis")

        # Couleurs aurore boréale
        aurora_green = self.colorI      # Vert brillant
        aurora_cyan = RGBColor(0, 255, 255)
        aurora_purple = self.colorE     # Violet/magenta
        aurora_blue = self.colorC       # Bleu
        aurora_teal = RGBColor(0, 180, 180)
        dark_background = RGBColor(10, 15, 30)

        while self.running and self.current_mode == "sequence_6":
            # Phase 1: Vague verte montante
            print("🌌 Phase 1: Northern Lights Rise")
            for intensity in range(0, 256, 8):
                if not self.running or self.current_mode != "sequence_6":
                    break

                factor = (math.sin(intensity / 40.0) + 1) / 2
                wave_color = self.interpolate_color(dark_background, aurora_green, factor)

                # Carte mère et GPU avec ondulation
                mobo_factor = (math.sin(intensity / 30.0) + 1) / 2
                self.set_static(self.mobo, self.interpolate_color(dark_background, aurora_teal, mobo_factor))

                if self.gpu:
                    gpu_factor = (math.sin(intensity / 25.0 + 1) + 1) / 2
                    self.set_static(self.gpu, self.interpolate_color(dark_background, aurora_blue, gpu_factor))

                # RAM et Node Pro avec vague
                for device in self.ram_devices + [self.node_pro]:
                    self.set_static(device, wave_color)

                time.sleep(0.04)

            if not self.running or self.current_mode != "sequence_6":
                break

            # Phase 2: Ondulation cyan-violet
            print("🌌 Phase 2: Color Dance")
            for wave_cycle in range(30):
                if not self.running or self.current_mode != "sequence_6":
                    break

                # Calcul des phases d'onde
                phase1 = (math.sin(wave_cycle * 0.3) + 1) / 2
                phase2 = (math.sin(wave_cycle * 0.3 + math.pi/2) + 1) / 2
                phase3 = (math.sin(wave_cycle * 0.3 + math.pi) + 1) / 2

                # Carte mère alterne cyan-vert
                mobo_color = self.interpolate_color(aurora_cyan, aurora_green, phase1)
                self.set_static(self.mobo, mobo_color)

                # GPU alterne bleu-violet
                if self.gpu:
                    gpu_color = self.interpolate_color(aurora_blue, aurora_purple, phase2)
                    self.set_static(self.gpu, gpu_color)

                # RAM et Node Pro avec gradient ondulant
                for i, device in enumerate(self.ram_devices + [self.node_pro]):
                    device_phase = (phase3 + i * 0.2) % 1.0
                    device_color = self.interpolate_color(aurora_green, aurora_purple, device_phase)
                    self.set_static(device, device_color)

                time.sleep(0.08)

            if not self.running or self.current_mode != "sequence_6":
                break

            # Phase 3: Rideau lumineux (curtain effect)
            print("🌌 Phase 3: Aurora Curtain")
            for device in self.ram_devices + [self.node_pro]:
                self.set_best_mode(device)
                led_count = len(device.leds)

                for sweep in range(2):
                    if not self.running or self.current_mode != "sequence_6":
                        break

                    for position in range(led_count + 10):
                        if not self.running or self.current_mode != "sequence_6":
                            break

                        colors = [dark_background] * led_count

                        # Créer un rideau de lumière qui se déplace
                        for i in range(led_count):
                            distance = abs(i - position)
                            if distance < 5:
                                intensity = 1.0 - (distance / 5.0)
                                if position % 2 == 0:
                                    colors[i] = self.interpolate_color(dark_background, aurora_green, intensity)
                                else:
                                    colors[i] = self.interpolate_color(dark_background, aurora_purple, intensity)

                        device.set_colors(colors)
                        time.sleep(0.06)

            time.sleep(0.5)

    def mode_sequence_7(self):
        """Séquence 7 - Lightning Storm avec éclairs et tonnerre"""
        print("⚡ Séquence 7 - Lightning Storm")

        # Couleurs orage
        storm_dark = RGBColor(10, 10, 20)
        lightning_white = RGBColor(255, 255, 255)
        lightning_blue = RGBColor(150, 200, 255)
        cloud_gray = RGBColor(40, 40, 60)
        thunder_purple = self.colorE

        while self.running and self.current_mode == "sequence_7":
            # Phase 1: Ambiance orageuse avec nuages
            print("⚡ Phase 1: Storm Clouds")
            for cloud_cycle in range(15):
                if not self.running or self.current_mode != "sequence_7":
                    break

                # Nuages qui bougent (pulsation lente)
                cloud_intensity = (math.sin(cloud_cycle * 0.4) + 1) / 2
                cloud_color = self.interpolate_color(storm_dark, cloud_gray, cloud_intensity * 0.5)

                self.set_static(self.mobo, cloud_color)
                if self.gpu:
                    gpu_cloud = self.interpolate_color(storm_dark, thunder_purple, cloud_intensity * 0.3)
                    self.set_static(self.gpu, gpu_cloud)

                for device in self.ram_devices + [self.node_pro]:
                    self.set_static(device, storm_dark)

                time.sleep(0.15)

            if not self.running or self.current_mode != "sequence_7":
                break

            # Phase 2: Éclairs aléatoires
            print("⚡ Phase 2: Lightning Strikes")
            for _ in range(random.randint(3, 6)):
                if not self.running or self.current_mode != "sequence_7":
                    break

                # Éclair soudain sur un composant aléatoire
                strike_device = random.choice(self.ram_devices + [self.node_pro])

                # Flash intense
                self.set_static(strike_device, lightning_white)
                if random.random() > 0.5 and self.gpu:
                    self.set_static(self.gpu, lightning_blue)

                time.sleep(0.05)

                # Atténuation rapide
                self.set_static(strike_device, lightning_blue)
                time.sleep(0.08)

                self.set_static(strike_device, storm_dark)
                if self.gpu:
                    self.set_static(self.gpu, thunder_purple)

                # Pause variable entre éclairs
                time.sleep(random.uniform(0.3, 1.5))

            if not self.running or self.current_mode != "sequence_7":
                break

            # Phase 3: Éclair traversant (fork lightning)
            print("⚡ Phase 3: Fork Lightning")
            for fork_strike in range(2):
                if not self.running or self.current_mode != "sequence_7":
                    break

                # Prépare tous les devices pour l'éclair
                for device in self.ram_devices + [self.node_pro]:
                    self.set_best_mode(device)
                    led_count = len(device.leds)

                    # Éclair qui traverse de haut en bas
                    for position in range(0, led_count, 2):
                        if not self.running or self.current_mode != "sequence_7":
                            break

                        colors = [storm_dark] * led_count

                        # Position de l'éclair
                        if position < led_count:
                            colors[position] = lightning_white
                        if position + 1 < led_count:
                            colors[position + 1] = lightning_blue
                        if position - 1 >= 0:
                            colors[position - 1] = cloud_gray

                        device.set_colors(colors)
                        time.sleep(0.02)

                    # Retour au calme
                    self.set_static(device, storm_dark)

                # Flash sur carte mère et GPU
                if self.gpu:
                    self.set_static(self.gpu, lightning_white)
                self.set_static(self.mobo, lightning_blue)
                time.sleep(0.1)

                if self.gpu:
                    self.set_static(self.gpu, storm_dark)
                self.set_static(self.mobo, storm_dark)

                time.sleep(random.uniform(1.0, 2.0))

            time.sleep(1)

    def mode_sequence_8(self):
        """Séquence 8 - Neon City avec néons urbains cyberpunk"""
        print("🌃 Séquence 8 - Neon City")

        # Palette néon urbain
        neon_pink = RGBColor(255, 20, 147)
        neon_cyan = RGBColor(0, 255, 255)
        neon_orange = RGBColor(255, 140, 0)
        neon_purple = self.colorE
        neon_lime = RGBColor(50, 255, 50)
        city_dark = RGBColor(15, 10, 25)
        billboard_white = RGBColor(255, 255, 200)

        while self.running and self.current_mode == "sequence_8":
            # Phase 1: Néons qui s'allument un par un
            print("🌃 Phase 1: City Awakens")
            neon_sequence = [
                (self.mobo, neon_cyan),
                (self.gpu if self.gpu else self.mobo, neon_pink),
            ]

            for device in self.ram_devices:
                neon_sequence.append((device, random.choice([neon_orange, neon_lime, neon_purple])))
            neon_sequence.append((self.node_pro, neon_cyan))

            for device, color in neon_sequence:
                if not self.running or self.current_mode != "sequence_8":
                    break
                self.smooth_transition(device, city_dark, color, 0.3, 10)
                time.sleep(0.2)

            if not self.running or self.current_mode != "sequence_8":
                break

            time.sleep(1)

            # Phase 2: Publicités clignotantes (billboard flicker)
            print("🌃 Phase 2: Neon Billboards")
            for flicker_cycle in range(20):
                if not self.running or self.current_mode != "sequence_8":
                    break

                # Néons qui clignotent de façon désynchronisée
                for device in [self.mobo] + self.ram_devices + [self.node_pro]:
                    if random.random() > 0.7:
                        flash_color = random.choice([billboard_white, neon_pink, neon_cyan])
                        self.set_static(device, flash_color)
                    else:
                        steady_color = random.choice([neon_orange, neon_purple, neon_lime])
                        self.set_static(device, steady_color)

                if self.gpu:
                    gpu_pulse = (math.sin(flicker_cycle * 0.5) + 1) / 2
                    self.set_static(self.gpu, self.interpolate_color(neon_purple, neon_pink, gpu_pulse))

                time.sleep(0.15)

            if not self.running or self.current_mode != "sequence_8":
                break

            # Phase 3: Balayage urbain (city sweep)
            print("🌃 Phase 3: Street Lights")
            for sweep_round in range(2):
                if not self.running or self.current_mode != "sequence_8":
                    break

                sweep_colors = [neon_cyan, neon_pink, neon_orange, neon_lime]

                for sweep_color in sweep_colors:
                    if not self.running or self.current_mode != "sequence_8":
                        break

                    # Balayage à travers tous les composants
                    all_devices = [self.mobo] + self.ram_devices + [self.node_pro]
                    if self.gpu:
                        all_devices.append(self.gpu)

                    for device in all_devices:
                        if not self.running or self.current_mode != "sequence_8":
                            break

                        self.smooth_transition(device, self.last_colors.get(device, city_dark), sweep_color, 0.4, 15)
                        time.sleep(0.1)

                    time.sleep(0.3)

            # Phase 4: Extinction progressive
            print("🌃 Phase 4: City Sleeps")
            for device in self.get_all_devices():
                if not self.running or self.current_mode != "sequence_8":
                    break
                self.smooth_transition(device, self.last_colors.get(device, neon_pink), city_dark, 0.5, 15)
                time.sleep(0.1)

            time.sleep(1)

    def mode_fixed_color(self, color_name):
        """Mode couleur fixe"""
        print(f"🎨 Couleur fixe: {color_name}")
        
        color_palette = {
            "rouge": RGBColor(255, 0, 0),
            "vert": RGBColor(0, 255, 0),
            "bleu": RGBColor(0, 114, 255),
            "cyan": RGBColor(0, 255, 255),
            "magenta": RGBColor(255, 70, 255),
            "violet": RGBColor(128, 0, 128),
            "jaune": RGBColor(255, 255, 0),
            "blanc": RGBColor(255, 255, 255),
            "orange": RGBColor(255, 165, 0),
            "rose": RGBColor(255, 192, 203),
            "lime": RGBColor(50, 205, 50),
            "azure": RGBColor(0, 127, 255),
        }
        
        if color_name not in color_palette:
            print(f"❌ Couleur inconnue: {color_name}")
            return
        
        fixed_color = color_palette[color_name]
        
        # Appliquer à tous les périphériques y compris GPU
        for device in self.get_all_devices():
            self.set_static(device, fixed_color)
        
        gpu_status = " (y compris GPU)" if self.gpu else ""
        print(f"✅ Couleur {color_name} appliquée à tous les périphériques{gpu_status}")
    
    def start_mode(self, mode):
        """Démarre un mode spécifique"""
        self.stop_current_mode()
        self.current_mode = mode
        self.running = True
        
        try:
            os.makedirs(os.path.dirname(self.STATUS_FILE), exist_ok=True)
            with open(self.STATUS_FILE, 'w') as f:
                f.write(mode)
        except Exception as e:
            print(f"⚠️ Impossible de sauvegarder le statut: {e}")
        
        if mode == "off":
            self.mode_off()
        elif mode == "sequence_1":
            self.animation_thread = threading.Thread(target=self.mode_sequence_1)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_2":
            self.animation_thread = threading.Thread(target=self.mode_sequence_2)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_3":
            self.animation_thread = threading.Thread(target=self.mode_sequence_3)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_4":
            self.animation_thread = threading.Thread(target=self.mode_sequence_4)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_5":
            self.animation_thread = threading.Thread(target=self.mode_sequence_5)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_6":
            self.animation_thread = threading.Thread(target=self.mode_sequence_6)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_7":
            self.animation_thread = threading.Thread(target=self.mode_sequence_7)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode == "sequence_8":
            self.animation_thread = threading.Thread(target=self.mode_sequence_8)
            self.animation_thread.daemon = True
            self.animation_thread.start()
        elif mode.startswith("fixed_"):
            color_name = mode.replace("fixed_", "")
            self.mode_fixed_color(color_name)
    
    def stop_current_mode(self):
        """Arrête le mode actuel"""
        self.running = False
        if self.animation_thread and self.animation_thread.is_alive():
            self.animation_thread.join(timeout=2)
    
    def cleanup(self):
        """Nettoyage avant fermeture"""
        self.stop_current_mode()
        self.mode_off()

    def apply_brightness(self, color):
        """Applique la luminosité actuelle à une couleur"""
        brightness = self.get_brightness()
        return RGBColor(
            int(color.red * brightness),
            int(color.green * brightness),
            int(color.blue * brightness)
        )

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 OpenRGB_Controller.py <mode>")
        print("Modes: off, sequence_1, sequence_2, sequence_3, sequence_4, sequence_5, sequence_6, sequence_7, sequence_8, fixed_<couleur>")
        print("Couleurs fixes: rouge, vert, bleu, cyan, magenta, jaune, blanc, orange, violet, rose, lime, azure")
        sys.exit(1)

    mode = sys.argv[1]
    valid_modes = ["off", "sequence_1", "sequence_2", "sequence_3", "sequence_4", "sequence_5", "sequence_6", "sequence_7", "sequence_8"]
    valid_colors = ["rouge", "vert", "bleu", "cyan", "magenta", "jaune", "blanc", "orange", "violet", "rose", "lime", "azure"]
    
    controller = OpenRGBController()
    
    try:
        controller.start_mode(mode)
        
        if mode != "off":
            # Maintenir le programme en vie pour les animations
            while controller.running:
                time.sleep(1)
        else:
            print("✅ Mode OFF appliqué")
            
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé")
    except Exception as e:
        print(f"💥 Erreur: {e}")
    finally:
        controller.cleanup()
        print("🏁 Programme terminé")
# Classe pour surveiller les changements
class SequenceFileHandler(FileSystemEventHandler):
    """Gestionnaire pour surveiller les changements du fichier sequence.txt"""
    def __init__(self, controller):
        self.controller = controller
        self.last_mode = None

    def on_modified(self, event):
        if event.src_path.endswith('sequence.txt'):
            try:
                with open(event.src_path, 'r') as f:
                    new_mode = f.read().strip()

                if new_mode and new_mode != self.last_mode:
                    print(f"📝 Nouveau mode détecté: {new_mode}")
                    self.last_mode = new_mode
                    self.controller.start_mode(new_mode)
            except Exception as e:
                print(f"⚠️ Erreur lecture sequence.txt: {e}")
