#!/usr/bin/env python3
import json
import os
import sqlite3
import sys
import tomllib
from pathlib import Path
from typing import List, Dict, Any, Optional
import re
import urllib.request
import urllib.error
import struct
import binascii
import vdf
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta


class ImageCache:
    def __init__(self, cache_file: Path, ttl_hours: int = 24):
        self.cache_file = cache_file
        self.ttl = timedelta(hours=ttl_hours)
        self.cache = self._load_cache()

    def _load_cache(self) -> Dict[str, Any]:
        if not self.cache_file.exists():
            return {}
        try:
            with open(self.cache_file, 'r') as f:
                return json.load(f)
        except Exception:
            return {}

    def _save_cache(self):
        try:
            self.cache_file.parent.mkdir(parents=True, exist_ok=True)
            with open(self.cache_file, 'w') as f:
                json.dump(self.cache, f, indent=2)
        except Exception as e:
            print(f"Error saving cache: {e}", file=sys.stderr)

    def get(self, key: str) -> Optional[str]:
        if key not in self.cache:
            return None
        entry = self.cache[key]
        cached_time = datetime.fromisoformat(entry['timestamp'])
        if datetime.now() - cached_time > self.ttl:
            del self.cache[key]
            return None
        return entry['url']

    def set(self, key: str, url: str):
        self.cache[key] = {
            'url': url,
            'timestamp': datetime.now().isoformat()
        }
        self._save_cache()

    def clear_expired(self):
        now = datetime.now()
        expired_keys = [k for k, v in self.cache.items()
                        if now - datetime.fromisoformat(v['timestamp']) > self.ttl]
        for key in expired_keys:
            del self.cache[key]
        if expired_keys:
            self._save_cache()


class GameLauncher:
    def __init__(self, config_path: str = None):
        if config_path is None:
            script_dir = Path(os.path.abspath(__file__)).parent
            config_path = script_dir.parent.parent / "config.toml"

        self.config_path = Path(config_path)
        self.favorites_file = self.config_path.parent / "favorites.json"
        self.config = self.load_config()

        cache_dir = self.config_path.parent / "cache"
        cache_file = cache_dir / "image_cache.json"
        cache_ttl = self.config.get("steamgriddb", {}).get("cache_ttl_hours", 24)
        self.image_cache = ImageCache(cache_file, ttl_hours=cache_ttl)
        self.image_cache.clear_expired()

        # Detect Heroic installation once at startup
        self._heroic_bin: Optional[str] = self._detect_heroic()
        # Detect Lutris installation once at startup
        self._lutris_bin: Optional[str] = self._detect_lutris()

    # ── Lutris detection ───────────────────────────────────────────────────

    def _detect_lutris(self) -> Optional[str]:
        import shutil
        if shutil.which("lutris"):
            return "lutris"

        # Flatpak
        flatpak_paths = [
            Path("/var/lib/flatpak/app/net.lutris.Lutris"),
            Path.home() / ".local/share/flatpak/app/net.lutris.Lutris",
        ]
        for p in flatpak_paths:
            if p.exists():
                return "flatpak run net.lutris.Lutris"

        return None

    def get_lutris_exec(self, game_id: int) -> str:
        url = f"lutris:rungameid/{game_id}"
        if self._lutris_bin is None:
            return f"xdg-open {url}"
        return f"{self._lutris_bin} {url}"

    # ── Heroic detection ───────────────────────────────────────────────────

    def _detect_heroic(self) -> Optional[str]:
        import shutil
        if shutil.which("heroic"):
            return "heroic"

        # 2. AppImage — exclut la Corbeille
        search_dirs = [
            Path.home() / "Applications",
            Path.home() / "Downloads",
            Path.home() / ".local/bin",
            Path.home(),
            Path("/opt"),
        ]
        for directory in search_dirs:
            if not directory.exists():
                continue
            for appimage in directory.glob("*eroic*.AppImage"):
                # Ignore Trash
                if ".local/share/Trash" in str(appimage):
                    continue
                if os.access(appimage, os.X_OK):
                    return str(appimage)

        # 3. Flatpak
        flatpak_paths = [
            Path("/var/lib/flatpak/app/com.heroicgameslauncher.hgl"),
            Path.home() / ".local/share/flatpak/app/com.heroicgameslauncher.hgl",
        ]
        for p in flatpak_paths:
            if p.exists():
                return "flatpak run com.heroicgameslauncher.hgl"

        # 4. Fallback xdg-open
        return None

    def get_heroic_exec(self, runner: str, app_name: str) -> str:
        """
        Build the correct launch command for a Heroic game depending on
        how Heroic is installed (AppImage / Flatpak / native / xdg-open).
        """
        url = f"heroic://launch/{runner}/{app_name}"

        if self._heroic_bin is None:
            # xdg-open fallback: works if Heroic registered the URL scheme
            return f"xdg-open {url}"

        # AppImage and native binary accept the URL as argument
        # Flatpak command already contains all tokens
        return f"{self._heroic_bin} {url}"

    # ── Favorites ──────────────────────────────────────────────────────────

    def load_favorites(self) -> set:
        try:
            with open(self.favorites_file, 'r') as f:
                return set(json.load(f))
        except Exception:
            return set()

    def save_favorites(self, favorites: set):
        try:
            with open(self.favorites_file, 'w') as f:
                json.dump(sorted(favorites), f, indent=2)
        except Exception as e:
            print(f"Error saving favorites: {e}", file=sys.stderr)

    def toggle_favorite(self, name: str, source: str):
        key = f"{name}:{source}"
        favorites = self.load_favorites()
        if key in favorites:
            favorites.discard(key)
            is_fav = False
        else:
            favorites.add(key)
            is_fav = True
        self.save_favorites(favorites)
        print(json.dumps({"ok": True, "favorite": is_fav}), flush=True)

    # ── Config ─────────────────────────────────────────────────────────────

    def load_config(self) -> Dict[str, Any]:
        try:
            with open(self.config_path, 'rb') as f:
                return tomllib.load(f)
        except Exception as e:
            print(f"Error loading config: {e}", file=sys.stderr)
            return self.get_default_config()

    def get_default_config(self) -> Dict[str, Any]:
        return {
            "steam": {
                "enabled": True,
                "library_paths": ["~/.local/share/Steam/steamapps"],
                "fetch_covers": True
            },
            "steamgriddb": {
                "enabled": False,
                "api_key": "",
                "image_type": "grid",
                "prefer_animated": False,
                "fallback_to_steam": True,
                "dimensions": [],
                "styles": [],
                "mimes": ["image/png", "image/jpeg"],
                "nsfw": "false",
                "humor": "false",
                "epilepsy": "false",
                "cache_ttl_hours": 24,
                "parallel_requests": True,
                "max_workers": 10,
                "request_timeout": 3
            },
            "heroic": {
                "enabled": True,
                "config_paths": ["~/.config/heroic"],
                "scan_epic": True,
                "scan_gog": True,
                "scan_amazon": True,
                "scan_sideload": True
            },
            "filtering": {
                "games_only": False,
                "exclude_categories": [],
                "exclude_keywords": []
            },
            "behavior": {
                "sort_by": "recent",
                "show_favorites_first": True
            }
        }

    def expand_path(self, path: str) -> Path:
        return Path(os.path.expanduser(os.path.expandvars(path)))

    # ── Image helpers ──────────────────────────────────────────────────────

    def check_url_exists(self, url: str, timeout: int = 2) -> bool:
        try:
            request = urllib.request.Request(url, method='HEAD')
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.status == 200
        except Exception:
            return False

    def get_steam_cdn_fallback_url(self, app_id: str) -> str:
        cache_key = f"steam_cdn:{app_id}"
        cached_url = self.image_cache.get(cache_key)
        if cached_url:
            return cached_url

        base_url = f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}"
        fallback_urls = [
            f"{base_url}/header.jpg",
            f"{base_url}/library_600x900.jpg",
            f"{base_url}/capsule_616x353.jpg",
            f"{base_url}/library_hero.jpg",
        ]

        if self.check_url_exists(fallback_urls[0], timeout=1):
            self.image_cache.set(cache_key, fallback_urls[0])
            return fallback_urls[0]

        for url in fallback_urls[1:]:
            if self.check_url_exists(url, timeout=1):
                self.image_cache.set(cache_key, url)
                return url

        return fallback_urls[0]

    def get_steamgriddb_cover_url(self, app_id: str, platform: str = "steam", game_name: str = "") -> Optional[str]:
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False):
            return None
        api_key = sgdb_config.get("api_key", "")
        if not api_key:
            return None

        anim_suffix = "animated" if sgdb_config.get("prefer_animated", False) else "static"
        cache_key = f"{platform}:{app_id}:{sgdb_config.get('image_type', 'grid')}:{anim_suffix}"
        cached_url = self.image_cache.get(cache_key)
        if cached_url is not None:
            return cached_url if cached_url else None

        image_type = sgdb_config.get("image_type", "grid")
        endpoint_map = {"grid": "grids", "hero": "heroes", "logo": "logos", "icon": "icons"}
        endpoint = endpoint_map.get(image_type, "grids")

        def score_image(img):
            likes = img.get("likes") or 0  # None → 0
            # Tri strict par j'aimes si activé dans config
            if sgdb_config.get("sort_by_likes", False):
                return likes

            score = likes * 1000
            if img.get("width") and img.get("height"):
                score += img["width"] * img["height"] // 100
            if img.get("mime") == "image/png":
                score += 500

            return score

        def filter_images(images):
            images = [img for img in images if img.get("width", 0) >= 300]
            min_likes = sgdb_config.get("min_likes", 0)
            if min_likes > 0:
                filtered = [img for img in images if (img.get("likes") or 0) >= min_likes]
                if filtered:
                    images = filtered
            return images

        def normalize(val, default=None):
            """String '920x430' ou liste ['920x430'] → toujours une liste propre"""
            if not val:
                return default or []
            if isinstance(val, str):
                return [v.strip() for v in val.split(",") if v.strip()]
            return [str(v).strip() for v in val if str(v).strip()]

        dimensions = normalize(sgdb_config.get("dimensions"))
        styles     = normalize(sgdb_config.get("styles"))
        base_flags = []
        if dimensions:
            base_flags.append(f"dimensions={','.join(dimensions)}")
        if styles:
            base_flags.append(f"styles={','.join(styles)}")
        base_flags.append(f"nsfw={str(sgdb_config.get('nsfw', False)).lower()}")
        base_flags.append(f"humor={str(sgdb_config.get('humor', False)).lower()}")
        base_flags.append(f"epilepsy={str(sgdb_config.get('epilepsy', False)).lower()}")

        base_url = f"https://www.steamgriddb.com/api/v2/{endpoint}/{platform}/{app_id}"
        timeout  = sgdb_config.get("request_timeout", 3)

        def make_url(types_val, with_dims=True, mimes_val=None, url_base=None):
            p = [f"types={types_val}"]
            if mimes_val:
                p.append(f"mimes={mimes_val}")
            p += [f for f in base_flags if with_dims or not f.startswith("dimensions=")]
            return (url_base or base_url) + "?" + "&".join(p)

        def do_request(url):
            """Retourne les images brutes (non filtrées/triées), ou None."""
            try:
                req = urllib.request.Request(url)
                req.add_header("Authorization", f"Bearer {api_key}")
                req.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
                req.add_header("Accept", "application/json")
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    data = json.loads(resp.read().decode())
                    if data.get("success") and data.get("data"):
                        return data["data"]
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    self.image_cache.set(cache_key, "")
            except Exception:
                pass
            return None

        def best_image(raw_images, prefer_webm=False):
            """Filtre, trie et retourne la meilleure URL, ou None."""
            if not raw_images:
                return None
            imgs = filter_images(raw_images)
            if not imgs:
                return None
            if prefer_webm:
                # Préférer WebM parmi les animés, sinon prendre le meilleur du lot
                webm = [i for i in imgs if i.get("mime") == "image/webm"]
                pool = sorted(webm or imgs, key=score_image, reverse=True)
            else:
                pool = sorted(imgs, key=score_image, reverse=True)
            return pool[0].get("url", pool[0].get("thumb"))

        prefer_animated = sgdb_config.get("prefer_animated", False)

        if prefer_animated:
            # Animés (WebP principalement sur SGDB)
            raw = do_request(make_url("animated", with_dims=True))
            if raw is None and dimensions:
                raw = do_request(make_url("animated", with_dims=False))
            image_url = best_image(raw, prefer_webm=False)
            if image_url:
                self.image_cache.set(cache_key, image_url)
                return image_url

        # Fallback (ou mode static) : PNG statique
        raw = do_request(make_url("static", with_dims=True, mimes_val="image/png"))
        if raw is None and dimensions:
            raw = do_request(make_url("static", with_dims=False, mimes_val="image/png"))
        image_url = best_image(raw, prefer_webm=False)
        if image_url:
            self.image_cache.set(cache_key, image_url)
            return image_url

        # Fallback par nom (steam-shortcut + jeux sans ID SGDB valide)
        if game_name:
            sgdb_id = self._search_sgdb_id_by_name(game_name, api_key, timeout)
            if sgdb_id:
                name_base = f"https://www.steamgriddb.com/api/v2/{endpoint}/game/{sgdb_id}"
                if prefer_animated:
                    raw = do_request(make_url("animated", with_dims=True, url_base=name_base))
                    if raw is None and dimensions:
                        raw = do_request(make_url("animated", with_dims=False, url_base=name_base))
                    image_url = best_image(raw, prefer_webm=False)
                    if image_url:
                        self.image_cache.set(cache_key, image_url)
                        return image_url
                raw = do_request(make_url("static", with_dims=True, mimes_val="image/png", url_base=name_base))
                if raw is None and dimensions:
                    raw = do_request(make_url("static", with_dims=False, mimes_val="image/png", url_base=name_base))
                image_url = best_image(raw, prefer_webm=False)
                if image_url:
                    self.image_cache.set(cache_key, image_url)
                    return image_url

        return None

    def get_steamgriddb_logo_url(self, app_id: str, platform: str = "steam", game_name: str = "") -> Optional[str]:
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False):
            return None
        api_key = sgdb_config.get("api_key", "")
        if not api_key:
            return None

        cache_key = f"{platform}:{app_id}:logo"
        cached_url = self.image_cache.get(cache_key)
        if cached_url is not None:
            return cached_url if cached_url else None

        url = f"https://www.steamgriddb.com/api/v2/logos/{platform}/{app_id}?types=static&mimes=image/png"

        timeout = sgdb_config.get("request_timeout", 3)
        try:
            request = urllib.request.Request(url)
            request.add_header("Authorization", f"Bearer {api_key}")
            request.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
            request.add_header("Accept", "application/json")
            with urllib.request.urlopen(request, timeout=timeout) as response:
                data = json.loads(response.read().decode())
                if data.get("success") and data.get("data"):
                    images = data["data"]
                    if images:
                        logo_url = images[0].get("url", images[0].get("thumb"))
                        self.image_cache.set(cache_key, logo_url)
                        return logo_url
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.image_cache.set(cache_key, "")
        except Exception:
            pass

        # Fallback par nom (steam-shortcut + jeux sans ID SGDB valide)
        if game_name:
            sgdb_id = self._search_sgdb_id_by_name(game_name, api_key, timeout)
            if sgdb_id:
                name_url = f"https://www.steamgriddb.com/api/v2/logos/game/{sgdb_id}?types=static&mimes=image/png"
                try:
                    req2 = urllib.request.Request(name_url)
                    req2.add_header("Authorization", f"Bearer {api_key}")
                    req2.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
                    req2.add_header("Accept", "application/json")
                    with urllib.request.urlopen(req2, timeout=timeout) as r2:
                        d2 = json.loads(r2.read().decode())
                        if d2.get("success") and d2.get("data"):
                            logo_url = d2["data"][0].get("url", d2["data"][0].get("thumb"))
                            self.image_cache.set(cache_key, logo_url)
                            return logo_url
                except Exception:
                    pass

        return None

    def fetch_images_parallel(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False) or not sgdb_config.get("parallel_requests", True):
            return games

        max_workers = sgdb_config.get("max_workers", 10)
        games_to_fetch = []
        for i, game in enumerate(games):
            source   = game.get("source", "")
            category = game.get("category", "")
            image    = game.get("image", "")
            # Inclure Steam, Epic, GOG, Amazon, Heroic, Sideload
            valid_source = source in ["steam", "epic", "gog", "amazon", "heroic", "sideload"]
            # Forcer le fetch pour : steam-shortcut (image locale), sideload/heroic (image grid Heroic, pas hero)
            is_shortcut = category == "steam-shortcut"
            is_sideload = category == "sideload" or source in ["heroic", "sideload"]
            needs_fetch = not image or "steamstatic.com" in image or is_shortcut or is_sideload
            if valid_source and game.get("appid") and needs_fetch:
                games_to_fetch.append((i, game))

        if not games_to_fetch:
            return games

        def fetch_cover_and_logo(item):
            idx, game = item
            platform = self.get_steamgriddb_platform(game.get("source", ""), game.get("category", ""))
            appid = game.get("appid")
            name  = game.get("name", "")

            # Cover
            cover_url = self.get_steamgriddb_cover_url(appid, platform, game_name=name)
            # Steam CDN uniquement pour les vrais jeux Steam (pas les shortcuts)
            if not cover_url and game.get("source") == "steam" and game.get("category") != "steam-shortcut":
                cover_url = self.get_steam_cdn_fallback_url(appid)

            # Logo (toujours PNG transparent)
            logo_url = self.get_steamgriddb_logo_url(appid, platform, game_name=name)

            return idx, cover_url, logo_url

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(fetch_cover_and_logo, item): item for item in games_to_fetch}
            for future in as_completed(futures):
                try:
                    idx, cover_url, logo_url = future.result()
                    if cover_url:
                        games[idx]["image"] = cover_url
                    if logo_url:
                        games[idx]["logo"] = logo_url
                except Exception:
                    pass

        return games

        def fetch_image(item):
            idx, game = item
            platform = self.get_steamgriddb_platform(game.get("source", ""), game.get("category", ""))
            url = self.get_steamgriddb_cover_url(game.get("appid"), platform)
            if not url and game.get("source") == "steam":
                url = self.get_steam_cdn_fallback_url(game.get("appid"))
            return idx, url

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {executor.submit(fetch_image, item): item for item in games_to_fetch}
            for future in as_completed(futures):
                try:
                    idx, url = future.result()
                    if url:
                        games[idx]["image"] = url
                except Exception:
                    pass

        return games

    def get_steamgriddb_platform(self, source: str, category: str) -> str:
        platform_map = {
            "steam": "steam", "epic": "egs", "gog": "gog",
            "amazon": "amazon", "uplay": "uplay", "origin": "origin",
            "battlenet": "bnet", "sideload": "steam",
        }
        return platform_map.get(source.lower()) or platform_map.get(category.lower()) or "steam"

    def _search_sgdb_id_by_name(self, game_name: str, api_key: str, timeout: int) -> Optional[int]:
        """Cherche un jeu sur SGDB par nom. Retourne l'ID SGDB si le nom correspond bien."""
        import urllib.parse

        def word_set(name):
            # Enlever ™, ®, ©, ponctuation spéciale avant de split
            cleaned = re.sub(r'[™®©]', '', name)
            return set(re.sub(r'[_\-:]+', ' ', cleaned).lower().split())

        game_words = word_set(game_name)
        if not game_words:
            return None

        encoded = urllib.parse.quote(game_name)
        url = f"https://www.steamgriddb.com/api/v2/search/autocomplete/{encoded}"
        try:
            req = urllib.request.Request(url)
            req.add_header("Authorization", f"Bearer {api_key}")
            req.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
            req.add_header("Accept", "application/json")
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                data = json.loads(resp.read().decode())
                if data.get("success") and data.get("data"):
                    for result in data["data"]:
                        sgdb_words = word_set(result.get("name", ""))
                        # Tous les mots du nom de jeu doivent être dans le résultat SGDB
                        # Évite les faux positifs comme "Elden Ring_Mod" → "Elden Ring"
                        if game_words and game_words.issubset(sgdb_words):
                            return result["id"]
        except Exception:
            pass
        return None

    def get_steam_cover_url(self, app_id: str) -> str:
        sgdb_url = self.get_steamgriddb_cover_url(app_id, platform="steam")
        if sgdb_url:
            return sgdb_url
        sgdb_config = self.config.get("steamgriddb", {})
        if sgdb_config.get("enabled", False) and not sgdb_config.get("fallback_to_steam", True):
            return ""
        return self.get_steam_cdn_fallback_url(app_id)

    def get_heroic_cover_url(self, app_id: str, source: str, art_url: str = "", game_name: str = "") -> str:
        platform = self.get_steamgriddb_platform(source, source)
        sgdb_url = self.get_steamgriddb_cover_url(app_id, platform=platform, game_name=game_name)
        return sgdb_url if sgdb_url else art_url

    # ── Steam ──────────────────────────────────────────────────────────────

    def scan_steam_library(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("steam", {}).get("enabled", True):
            return games
        library_paths = self.config.get("steam", {}).get("library_paths", [])
        for lib_path in library_paths:
            lib_path = self.expand_path(lib_path)
            if not lib_path.exists():
                continue
            for acf_file in lib_path.glob("*.acf"):
                game_data = self.parse_acf_file(acf_file)
                if game_data:
                    games.append(game_data)
        return games

    def is_steam_tool(self, name: str) -> bool:
        tool_patterns = [
            "proton", "steam linux runtime", "steamworks common", "steam runtime",
            "redistributable", "sdk", "dedicated server", "tool", "hotfix",
            "steamvr", "steam audio", "steam shader", "steam workshop",
            "steam controller", "directx", "vcredist", "visual c++",
            ".net framework", "microsoft visual", "steam play", "compatibility tool"
        ]
        return any(pattern in name.lower() for pattern in tool_patterns)

    def parse_acf_file(self, acf_path: Path) -> Dict[str, Any]:
        try:
            with open(acf_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()

            app_id_match = re.search(r'"appid"\s+"(\d+)"', content)
            if not app_id_match:
                return None
            app_id = app_id_match.group(1)

            name_match = re.search(r'"name"\s+"([^"]+)"', content)
            if not name_match:
                return None
            name = name_match.group(1)

            if self.is_steam_tool(name):
                return None

            last_played_match = re.search(r'"LastPlayed"\s+"(\d+)"', content)
            last_played = int(last_played_match.group(1)) if last_played_match else 0

            sgdb_config = self.config.get("steamgriddb", {})
            cover_url = "" if sgdb_config.get("parallel_requests", True) else self.get_steam_cover_url(app_id)

            return {
                "name": name,
                "exec": f"steam steam://rungameid/{app_id}",
                "image": cover_url,
                "category": "steam",
                "favorite": False,
                "appid": app_id,
                "last_played": last_played,
                "source": "steam",
                "logo": ""
            }
        except Exception:
            return None

    def convert_appid_to_long(self, appid: int) -> int:
        int32 = struct.Struct('<i')
        bin_appid = int32.pack(appid)
        hex_appid = binascii.hexlify(bin_appid).decode()
        reversed_hex = bytes.fromhex(hex_appid)[::-1].hex()
        return int(reversed_hex, 16) << 32 | 0x02000000

    def parse_vdf_shortcuts(self, file_path: Path) -> List[Dict[str, Any]]:
        games = []
        try:
            with open(file_path, 'rb') as f:
                shortcuts_data = vdf.binary_load(f)
            for idx, app in shortcuts_data.get('shortcuts', {}).items():
                game_data = self.process_shortcut_entry(app)
                if game_data:
                    games.append(game_data)
        except Exception:
            pass
        return games

    def process_shortcut_entry(self, app: Dict[str, Any]) -> Dict[str, Any]:
        name = app.get('AppName', app.get('appname', 'Unknown'))
        exe = app.get('Exe', app.get('exe', ''))
        icon = app.get('icon', '')
        appid = app.get('appid', 0)
        last_played = app.get('LastPlayTime', app.get('lastplaytime', 0))

        if not name or not exe:
            return None

        long_appid = self.convert_appid_to_long(appid)

        return {
            "name": name,
            "exec": f"steam steam://rungameid/{long_appid}",
            "image": icon if icon else "",
            "category": "steam-shortcut",
            "favorite": False,
            "appid": str(long_appid),
            "last_played": last_played,
            "source": "steam"
        }

    def scan_steam_shortcuts(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("steam", {}).get("enabled", True):
            return games
        steam_path = self.expand_path("~/.local/share/Steam")
        userdata_path = steam_path / "userdata"
        if not userdata_path.exists():
            return games
        for user_dir in userdata_path.iterdir():
            if user_dir.is_dir():
                shortcuts_file = user_dir / "config" / "shortcuts.vdf"
                if shortcuts_file.exists():
                    games.extend(self.parse_vdf_shortcuts(shortcuts_file))
        return games

    # ── Desktop files ──────────────────────────────────────────────────────

    def scan_desktop_files(self) -> List[Dict[str, Any]]:
        games = []
        desktop_dirs = [
            Path.home() / ".local/share/applications",
            Path("/usr/share/applications"),
            Path("/usr/local/share/applications")
        ]
        for desktop_dir in desktop_dirs:
            if not desktop_dir.exists():
                continue
            for desktop_file in desktop_dir.glob("*.desktop"):
                game_data = self.parse_desktop_file(desktop_file)
                if game_data:
                    games.append(game_data)
        return games

    def parse_desktop_file(self, desktop_path: Path) -> Dict[str, Any]:
        try:
            with open(desktop_path, 'r', encoding='utf-8') as f:
                content = f.read()
            if "Categories=" not in content or "Game" not in content:
                return None
            name_match = re.search(r'^Name=(.+)$', content, re.MULTILINE)
            if not name_match:
                return None
            name = name_match.group(1)
            exec_match = re.search(r'^Exec=(.+)$', content, re.MULTILINE)
            if not exec_match:
                return None
            exec_cmd = exec_match.group(1)
            icon_match = re.search(r'^Icon=(.+)$', content, re.MULTILINE)
            icon = icon_match.group(1) if icon_match else ""
            image_path = self.resolve_icon_path(icon) if icon else ""
            return {
                "name": name,
                "exec": exec_cmd,
                "image": image_path,
                "category": "desktop",
                "favorite": False,
                "source": "desktop",
                "last_played": 0
            }
        except Exception:
            return None

    def resolve_icon_path(self, icon: str) -> str:
        if icon.startswith("/"):
            return icon
        icon_dirs = [
            Path.home() / ".local/share/icons",
            Path("/usr/share/icons"),
            Path("/usr/share/pixmaps")
        ]
        for icon_dir in icon_dirs:
            if not icon_dir.exists():
                continue
            for ext in ["png", "svg", "jpg", "xpm"]:
                for size in ["256x256", "128x128", "64x64", "48x48"]:
                    icon_path = icon_dir / "hicolor" / size / "apps" / f"{icon}.{ext}"
                    if icon_path.exists():
                        return str(icon_path)
                icon_path = icon_dir / f"{icon}.{ext}"
                if icon_path.exists():
                    return str(icon_path)
        return icon

    # ── Heroic ─────────────────────────────────────────────────────────────

    def scan_heroic_library(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("heroic", {}).get("enabled", True):
            return games

        config_paths = self.config.get("heroic", {}).get("config_paths", [])
        scan_epic    = self.config.get("heroic", {}).get("scan_epic", True)
        scan_gog     = self.config.get("heroic", {}).get("scan_gog", True)
        scan_amazon  = self.config.get("heroic", {}).get("scan_amazon", True)
        scan_sideload = self.config.get("heroic", {}).get("scan_sideload", True)
        use_parallel = self.config.get("steamgriddb", {}).get("parallel_requests", True)

        for config_path in config_paths:
            heroic_path = self.expand_path(config_path)
            if not heroic_path.exists():
                continue

            stores = []
            if scan_epic:
                stores.append(("legendary", "epic"))
            if scan_gog:
                stores.append(("gog_store", "gog"))
            if scan_amazon:
                stores.append(("nile_config", "amazon"))

            for store_dir, runner in stores:
                library_path  = heroic_path / "store_cache" / store_dir / "library.json"
                installed_path = heroic_path / "store_cache" / store_dir / "installed.json"

                if not library_path.exists():
                    continue

                try:
                    with open(library_path, 'r') as f:
                        data = json.load(f)

                    installed_games = set()
                    if installed_path.exists():
                        with open(installed_path, 'r') as f:
                            installed_data = json.load(f)
                            installed_games = {
                                g.get("app_name", "")
                                for g in installed_data.get("installed", [])
                            }

                    for game in data.get("library", []):
                        app_name = game.get("app_name", "")
                        if app_name not in installed_games:
                            continue

                        title = game.get("title", "Unknown")
                        art   = game.get("art_cover", game.get("art_square", ""))
                        cover_url = art if use_parallel else self.get_heroic_cover_url(app_name, runner, art)

                        games.append({
                            "name":        title,
                            "exec":        self.get_heroic_exec(runner, app_name),  # ← auto-détecté
                            "image":       cover_url,
                            "category":    runner,
                            "favorite":    False,
                            "source":      runner,
                            "last_played": 0,
                            "appid":       app_name,
                            "logo":        ""
                        })
                except Exception:
                    pass

            if scan_sideload:
                sideload_path = heroic_path / "sideload_apps" / "library.json"
                if sideload_path.exists():
                    try:
                        with open(sideload_path, 'r') as f:
                            data = json.load(f)
                        for game in data.get("games", []):
                            if game.get("is_installed", False):
                                app_name  = game.get("app_name", "")
                                title     = game.get("title", "Unknown")
                                art       = game.get("art_cover", game.get("art_square", ""))
                                cover_url = art if use_parallel else self.get_heroic_cover_url(app_name, "sideload", art)

                                games.append({
                                    "name":        title,
                                    "exec":        self.get_heroic_exec("sideload", app_name),  # ← auto-détecté
                                    "image":       cover_url,
                                    "category":    "sideload",
                                    "favorite":    False,
                                    "source":      "heroic",
                                    "last_played": 0,
                                    "appid":       app_name,
                                    "logo":        ""
                                })
                    except Exception:
                        pass

        return games

    # ── Lutris ─────────────────────────────────────────────────────────────

    def scan_lutris_library(self) -> List[Dict[str, Any]]:
        games = []
        if not self.config.get("lutris", {}).get("enabled", False):
            return games

        db_path = self.expand_path(
            self.config.get("lutris", {}).get("db_path", "~/.local/share/lutris/pga.db")
        )
        if not db_path.exists():
            return games

        coverart_dir = self.expand_path("~/.local/share/lutris/coverart")
        try:
            con = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
            con.row_factory = sqlite3.Row
            cur = con.cursor()
            cur.execute(
                "SELECT id, name, slug, runner, lastplayed, installed "
                "FROM games WHERE installed = 1"
            )
            rows = cur.fetchall()
            con.close()
        except Exception as e:
            print(f"[lutris] Error reading database: {e}", file=sys.stderr)
            return games

        for row in rows:
            name = row["name"] or ""
            if not name:
                continue

            slug = row["slug"] or ""
            game_id = row["id"]

            # Cover art: check jpg then png
            image_path = ""
            for ext in ("jpg", "jpeg", "png"):
                candidate = coverart_dir / f"{slug}.{ext}"
                if candidate.exists():
                    image_path = str(candidate)
                    break

            games.append({
                "name":        name,
                "exec":        self.get_lutris_exec(game_id),
                "image":       image_path,
                "category":    "lutris",
                "favorite":    False,
                "source":      "lutris",
                "last_played": row["lastplayed"] or 0,
                "appid":       str(game_id),
                "logo":        "",
            })

        return games

    # ── Manual / config entries ────────────────────────────────────────────

    def load_manual_games(self) -> List[Dict[str, Any]]:
        games = []
        games_toml_path = self.config_path.parent / "games.toml"
        if not games_toml_path.exists():
            return games
        try:
            with open(games_toml_path, 'rb') as f:
                data = tomllib.load(f)
            for game in data.get("games", []):
                if "image" in game:
                    game["image"] = str(self.expand_path(game["image"]))
                game["source"] = "manual"
                game["last_played"] = game.get("last_played", 0)
                games.append(game)
        except Exception:
            pass
        return games

    def load_config_entries(self) -> List[Dict[str, Any]]:
        games = []
        box_art_dir = self.config.get("box_art_dir") or self.config.get("animations", {}).get("box_art_dir", "")
        if box_art_dir:
            box_art_dir = self.expand_path(box_art_dir)
        entries = self.config.get("entries", [])
        for entry in entries:
            title        = entry.get("title", "Unknown")
            launch_command = entry.get("launch_command", "")
            path_box_art = entry.get("path_box_art", "")
            image_path = ""
            if path_box_art and box_art_dir:
                image_path = str(box_art_dir / path_box_art)
            elif path_box_art:
                image_path = str(self.expand_path(path_box_art))
            games.append({
                "name":        title,
                "exec":        launch_command,
                "image":       image_path,
                "category":    "launcher",
                "favorite":    False,
                "source":      "config",
                "last_played": 0,
                "logo":        ""
            })
        return games

    # ── Filtering / sorting ────────────────────────────────────────────────

    def should_include_game(self, game: Dict[str, Any]) -> bool:
        filtering = self.config.get("filtering", {})
        if filtering.get("games_only", False):
            category = game.get("category", "").lower()
            name     = game.get("name", "").lower()
            if category in ["launcher", "desktop"]:
                if category == "desktop" and ("steam" in name or "heroic" in name or game.get("appid")):
                    pass
                else:
                    return False
            exclude_patterns = [
                "launcher", "manager", "runtime", "proton", "tool",
                "steamtools", "mod manager", "nexus mods", "vortex",
                "portproton", "protonup", "goverlay", "piper",
                "parsec", "moonlight", "millennium"
            ]
            if any(p in name for p in exclude_patterns):
                return False
        excluded_categories = filtering.get("exclude_categories", [])
        if game.get("category") in excluded_categories:
            return False
        excluded_keywords = filtering.get("exclude_keywords", [])
        game_name_lower = game.get("name", "").lower()
        if any(k.lower() in game_name_lower for k in excluded_keywords):
            return False
        return True

    # Source priority for exec/launch command (higher = preferred)
    _SOURCE_PRIORITY = {"steam": 4, "epic": 3, "gog": 3, "amazon": 3, "heroic": 3, "lutris": 2, "desktop": 1, "manual": 5}

    def _metadata_score(self, game: Dict[str, Any]) -> int:
        score = 0
        if game.get("image"):
            score += 3
        if game.get("last_played", 0) > 0:
            score += 2
        if game.get("appid"):
            score += 1
        if game.get("logo"):
            score += 1
        return score

    def _deduplicate_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Group games by normalized name, merge duplicates keeping best metadata."""
        groups: Dict[str, List[Dict[str, Any]]] = {}
        for game in games:
            key = game.get("name", "").strip().lower()
            groups.setdefault(key, []).append(game)

        result = []
        for entries in groups.values():
            if len(entries) == 1:
                result.append(entries[0])
                continue

            # Sort by source priority desc, then metadata score desc
            entries.sort(key=lambda g: (
                self._SOURCE_PRIORITY.get(g.get("source", ""), 0),
                self._metadata_score(g)
            ), reverse=True)

            # Start from the highest-priority entry and fill gaps from others
            merged = dict(entries[0])
            for other in entries[1:]:
                for field in ("image", "logo", "last_played", "appid"):
                    if not merged.get(field) and other.get(field):
                        merged[field] = other[field]

            result.append(merged)

        return result

    def merge_games(self) -> List[Dict[str, Any]]:
        steam_games     = self.scan_steam_library()
        steam_shortcuts = self.scan_steam_shortcuts()
        desktop_games   = self.scan_desktop_files()
        heroic_games    = self.scan_heroic_library()
        lutris_games    = self.scan_lutris_library()
        manual_games    = self.load_manual_games()
        config_entries  = self.load_config_entries()

        games_dict = {}

        for game in steam_games:
            if self.should_include_game(game):
                games_dict[f"steam:{game['name']}"] = game
        for game in steam_shortcuts:
            if self.should_include_game(game):
                key = f"steam:{game['name']}"
                if key in games_dict:
                    games_dict[key].update(game)
                else:
                    games_dict[key] = game
        for game in heroic_games:
            if self.should_include_game(game):
                games_dict[f"heroic:{game['name']}"] = game
        for game in lutris_games:
            if self.should_include_game(game):
                games_dict[f"lutris:{game['name']}"] = game
        for game in config_entries:
            if self.should_include_game(game):
                games_dict[f"config:{game['name']}"] = game
        for game in desktop_games:
            if self.should_include_game(game):
                key = f"desktop:{game['name']}"
                if key not in games_dict:
                    games_dict[key] = game
        for game in manual_games:
            # Manual entries override by name across all sources
            matched = [k for k in games_dict if k.endswith(f":{game['name']}")]
            if matched:
                for k in matched:
                    games_dict[k].update(game)
            else:
                games_dict[f"manual:{game['name']}"] = game

        games = self._deduplicate_games(list(games_dict.values()))

        sgdb_config = self.config.get("steamgriddb", {})
        if sgdb_config.get("enabled", False) and sgdb_config.get("parallel_requests", True):
            games = self.fetch_images_parallel(games)

        favorites = self.load_favorites()
        for game in games:
            key = f"{game.get('name', '')}:{game.get('source', '')}"
            game['favorite'] = key in favorites

        return games

    def sort_games(self, games: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        sort_by = self.config.get("behavior", {}).get("sort_by", "name")
        show_favorites_first = self.config.get("behavior", {}).get("show_favorites_first", True)
        if show_favorites_first:
            games.sort(key=lambda g: (not g.get("favorite", False)))
        if sort_by == "recent":
            games.sort(key=lambda g: g.get("last_played", 0), reverse=True)
        elif sort_by == "playtime":
            games.sort(key=lambda g: g.get("playtime", 0), reverse=True)
        elif sort_by == "name":
            games.sort(key=lambda g: g.get("name", "").lower())
        return games

    def load_wallust_colors(self) -> Dict[str, str]:
        wallust_path = self.expand_path(
            self.config.get("appearance", {}).get("wallust_path", "~/.cache/wal/wal.json")
        )
        try:
            with open(wallust_path, 'r') as f:
                data = json.load(f)
            colors = {}
            if "special" in data:
                colors.update(data["special"])
            if "colors" in data:
                colors.update(data["colors"])
            return colors
        except Exception:
            return {}

    def get_all_games(self) -> Dict[str, Any]:
        games = self.merge_games()
        games = self.sort_games(games)
        wallust_colors = {}
        if self.config.get("appearance", {}).get("use_wallust", True):
            wallust_colors = self.load_wallust_colors()
        return {
            "games":  games,
            "config": self.config,
            "colors": wallust_colors
        }

    def output_json(self):
        data = self.get_all_games()
        print(json.dumps(data, indent=2))


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == "toggle":
        name = sys.argv[2]
        source = sys.argv[3] if len(sys.argv) > 3 else ""
        launcher = GameLauncher()
        launcher.toggle_favorite(name, source)
    else:
        launcher = GameLauncher()
        launcher.output_json()


if __name__ == "__main__":
    main()