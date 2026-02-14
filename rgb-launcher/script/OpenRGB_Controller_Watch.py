#!/usr/bin/env python3
"""
Wrapper pour OpenRGB_Controller avec surveillance de sequence.txt
"""

import os
import sys
import time
import subprocess
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class SequenceFileHandler(FileSystemEventHandler):
    """Gestionnaire pour surveiller les changements du fichier sequence.txt"""
    def __init__(self, sequence_file, script_dir):
        self.sequence_file = sequence_file
        self.script_dir = script_dir
        self.last_mode = None
        self.current_process = None

    def start_controller(self, mode):
        """Démarre le contrôleur avec le mode spécifié"""
        # Tuer l'ancien processus si existe
        if self.current_process and self.current_process.poll() is None:
            print(f"🔄 Arrêt du mode précédent...")
            self.current_process.terminate()
            try:
                self.current_process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.current_process.kill()

        # Démarrer le nouveau mode
        print(f"🚀 Démarrage du mode: {mode}")
        self.current_process = subprocess.Popen(
            ['python3', f'{self.script_dir}/OpenRGB_Controller.py', mode],
            cwd=self.script_dir
        )

    def on_modified(self, event):
        if event.src_path.endswith('sequence.txt'):
            try:
                with open(self.sequence_file, 'r') as f:
                    new_mode = f.read().strip()

                if new_mode and new_mode != self.last_mode:
                    print(f"📝 Nouveau mode détecté: {new_mode}")
                    self.last_mode = new_mode
                    self.start_controller(new_mode)
            except Exception as e:
                print(f"⚠️ Erreur lecture sequence.txt: {e}")

if __name__ == "__main__":
    SCRIPT_DIR = os.path.expanduser('~/.config/quickshell/rgb-launcher/script')
    SEQUENCE_FILE = f'{SCRIPT_DIR}/sequence.txt'

    # Lire le mode initial
    try:
        with open(SEQUENCE_FILE, 'r') as f:
            initial_mode = f.read().strip()
        print(f"📖 Mode initial: {initial_mode}")
    except:
        initial_mode = "sequence_1"
        print(f"⚠️ Mode par défaut: {initial_mode}")

    # Créer le gestionnaire
    event_handler = SequenceFileHandler(SEQUENCE_FILE, SCRIPT_DIR)

    # Démarrer le mode initial
    event_handler.start_controller(initial_mode)

    # Configurer watchdog
    observer = Observer()
    observer.schedule(event_handler, SCRIPT_DIR, recursive=False)
    observer.start()

    print(f"👁️ Surveillance de {SEQUENCE_FILE}")
    print("🎮 Changez sequence.txt pour changer de mode")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n🛑 Arrêt demandé")
    finally:
        observer.stop()
        observer.join()
        if event_handler.current_process:
            event_handler.current_process.terminate()
        print("🏁 Programme terminé")
