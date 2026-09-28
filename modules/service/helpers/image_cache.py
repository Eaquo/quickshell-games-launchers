#!/usr/bin/env python3
import json
import os
import sys
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, Optional


class ImageCache:
    def __init__(self, cache_file: Path, ttl_hours: int = 24):
        self.cache_dir = cache_file.parent / "images"
        self.cache_file = cache_file
        self.ttl = timedelta(hours=ttl_hours)
        # set() est appelé depuis les threads SGDB : sérialise les écritures
        self._lock = threading.Lock()
        self.cache = self._load_cache()

    def _load_cache(self) -> Dict[str, Any]:
        if not self.cache_file.exists():
            return {}
        try:
            with open(self.cache_file, "r") as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError) as e:
            print(f"[image_cache]failed to load cache: {e}", file=sys.stderr)
            return {}

    def _save_cache(self):
        # Écriture atomique (tmp + rename) : un lecteur concurrent ne voit jamais
        # un JSON à moitié écrit, qui serait chargé comme cache vide
        with self._lock:
            tmp = self.cache_file.with_name(
                f"{self.cache_file.name}.{os.getpid()}.{threading.get_ident()}.tmp"
            )
            try:
                self.cache_file.parent.mkdir(parents=True, exist_ok=True)
                with open(tmp, "w") as f:
                    json.dump(dict(self.cache), f, indent=2)
                os.replace(tmp, self.cache_file)
            except Exception as e:
                print(f"[image_cache] save failed: {e}", file=sys.stderr)
                tmp.unlink(missing_ok=True)

    def get(self, key: str) -> Optional[str]:
        entry = self.cache.get(key)
        if entry is None:
            return None
        cached_time = datetime.fromisoformat(entry["timestamp"])
        if datetime.now() - cached_time > self.ttl:
            with self._lock:
                self.cache.pop(key, None)
            return None
        return entry["url"]

    def set(self, key: str, url: str):
        with self._lock:
            self.cache[key] = {"url": url, "timestamp": datetime.now().isoformat()}
        self._save_cache()

    def clear_expired(self):
        now = datetime.now()
        expired_keys = [
            k
            for k, v in self.cache.items()
            if now - datetime.fromisoformat(v["timestamp"]) > self.ttl
        ]
        for key in expired_keys:
            del self.cache[key]
        if expired_keys:
            self._save_cache()

    def clear_orphaned_images(self, keep_urls=()):
        """Supprime les fichiers locaux qui ne correspondent plus à aucune entrée valide du cache."""
        # Cache vide = chargement raté ou premier lancement : ne rien supprimer
        if not self.cache_dir.exists() or not self.cache:
            return
        valid = {self.cached_image_path(u) for u in keep_urls if u.startswith("http")}
        for entry in self.cache.values():
            url = entry.get("url", "")
            if url and url.startswith("["):
                try:
                    for u in json.loads(url):
                        if u and u.startswith("http"):
                            valid.add(self.cached_image_path(u))
                except json.JSONDecodeError as e:
                    print(
                        f"[image_cache] bad JSON in slideshow entry: {e}",
                        file=sys.stderr,
                    )
            elif url and url.startswith("http"):
                valid.add(self.cached_image_path(url))
        for f in self.cache_dir.iterdir():
            if f.is_file() and str(f) not in valid:
                try:
                    f.unlink()
                except OSError as e:
                    print(
                        f"[image_cache] could not unlink {f.name}: {e}", file=sys.stderr
                    )

    def cached_image_path(self, url: str) -> str:
        import hashlib
        from urllib.parse import urlparse

        if (
            not url
            or url.startswith("file://")
            or url.startswith("/")
            or url.startswith("~")
        ):
            return url
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        ext = Path(urlparse(url).path).suffix or ".jpg"
        url_hash = hashlib.md5(url.encode()).hexdigest()
        return str(self.cache_dir / f"{url_hash}{ext}")
