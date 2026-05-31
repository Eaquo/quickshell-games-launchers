#!/usr/bin/env python3
import json
import re
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Any, Dict, List, Optional

from .image_cache import ImageCache


class SGDBClient:
    def __init__(self, config: Dict[str, Any], image_cache: ImageCache):
        self.config = config
        self.image_cache = image_cache

    # ── Connectivité ───────────────────────────────────────────────────────

    def _check_connectivity(self, timeout: int = 2) -> bool:
        import socket

        try:
            socket.setdefaulttimeout(timeout)
            socket.gethostbyname("www.steamgriddb.com")
            return True
        except OSError:
            return False

    def check_url_exists(self, url: str, timeout: int = 2) -> bool:
        try:
            request = urllib.request.Request(url, method="HEAD")
            with urllib.request.urlopen(request, timeout=timeout) as response:
                return response.status == 200
        except OSError:
            return False

    # ── CDN Steam ──────────────────────────────────────────────────────────

    def get_steam_cdn_fallback_url(self, app_id: str) -> str:
        cache_key = f"steam_cdn:{app_id}"
        cached_url = self.image_cache.get(cache_key)
        if cached_url:
            return self._local_or_url(cached_url)

        base_url = f"https://cdn.cloudflare.steamstatic.com/steam/apps/{app_id}"
        fallback_urls = [
            f"{base_url}/header.jpg",
            f"{base_url}/library_600x900.jpg",
            f"{base_url}/capsule_616x353.jpg",
            f"{base_url}/library_hero.jpg",
        ]

        if self.check_url_exists(fallback_urls[0], timeout=1):
            self.image_cache.set(cache_key, fallback_urls[0])
            return self._local_or_url(fallback_urls[0])

        for url in fallback_urls[1:]:
            if self.check_url_exists(url, timeout=1):
                self.image_cache.set(cache_key, url)
                return self._local_or_url(url)

        return fallback_urls[0]

    # ── Helpers SGDB ───────────────────────────────────────────────────────

    def _local_or_url(self, url: str) -> str:
        """Retourne le chemin local file:// si le fichier est téléchargé, sinon l'URL."""
        if not url or not url.startswith("http"):
            return url
        local = self.image_cache.cached_image_path(url)
        if Path(local).exists():
            return "file://" + local
        return url

    def get_steamgriddb_platform(self, source: str, category: str) -> str:
        platform_map = {
            "steam": "steam",
            "epic": "egs",
            "gog": "gog",
            "amazon": "amazon",
            "uplay": "uplay",
            "origin": "origin",
            "battlenet": "bnet",
            "sideload": "steam",
        }
        return (
            platform_map.get(source.lower())
            or platform_map.get(category.lower())
            or "steam"
        )

    def _search_sgdb_id_by_name(
        self, game_name: str, api_key: str, timeout: int
    ) -> Optional[int]:
        import urllib.parse

        def word_set(name):
            cleaned = re.sub(r"[™®©]", "", name)
            return set(re.sub(r"[_\-:]+", " ", cleaned).lower().split())

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
                        if game_words and game_words.issubset(sgdb_words):
                            return result["id"]
        except (urllib.error.URLError, json.JSONDecodeError) as e:
            print(f"[sgdb] search by name failed: {e}", file=sys.stderr)
        return None

    # ── Cover ──────────────────────────────────────────────────────────────

    def get_steamgriddb_cover_url(
        self,
        app_id: str,
        platform: str = "steam",
        game_name: str = "",
        prefer_animated: Optional[bool] = None,
    ) -> Optional[str]:
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False):
            return None
        api_key = sgdb_config.get("api_key", "")
        if not api_key:
            return None

        if prefer_animated is None:
            prefer_animated = sgdb_config.get("prefer_animated", False)

        anim_suffix = "animated" if prefer_animated else "static"
        cache_key = (
            f"{platform}:{app_id}:{sgdb_config.get('image_type', 'grid')}:{anim_suffix}"
        )
        cached_url = self.image_cache.get(cache_key)
        if cached_url is not None:
            return self._local_or_url(cached_url) if cached_url else None

        image_type = sgdb_config.get("image_type", "grid")
        endpoint_map = {
            "grid": "grids",
            "hero": "heroes",
            "logo": "logos",
            "icon": "icons",
        }
        endpoint = endpoint_map.get(image_type, "grids")

        def score_image(img):
            likes = img.get("likes") or 0
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
                filtered = [
                    img for img in images if (img.get("likes") or 0) >= min_likes
                ]
                if filtered:
                    images = filtered
            return images

        def normalize(val, default=None):
            if not val:
                return default or []
            if isinstance(val, str):
                return [v.strip() for v in val.split(",") if v.strip()]
            return [str(v).strip() for v in val if str(v).strip()]

        dimensions = normalize(sgdb_config.get("dimensions"))
        styles = normalize(sgdb_config.get("styles"))
        base_flags = []
        if dimensions:
            base_flags.append(f"dimensions={','.join(dimensions)}")
        if styles:
            base_flags.append(f"styles={','.join(styles)}")
        base_flags.append(f"nsfw={str(sgdb_config.get('nsfw', False)).lower()}")
        base_flags.append(f"humor={str(sgdb_config.get('humor', False)).lower()}")
        base_flags.append(f"epilepsy={str(sgdb_config.get('epilepsy', False)).lower()}")

        base_url = f"https://www.steamgriddb.com/api/v2/{endpoint}/{platform}/{app_id}"
        timeout = sgdb_config.get("request_timeout", 3)

        def make_url(types_val, with_dims=True, mimes_val=None, url_base=None):
            p = [f"types={types_val}"]
            if mimes_val:
                p.append(f"mimes={mimes_val}")
            p += [f for f in base_flags if with_dims or not f.startswith("dimensions=")]
            return (url_base or base_url) + "?" + "&".join(p)

        def do_request(url):
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
                else:
                    print(f"[sgdb] HTTP {e.code} on {url}", file=sys.stderr)
            except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as e:
                print(f"[sgdb] request failed: {e}", file=sys.stderr)
            return None

        def best_image(raw_images, prefer_webm=False):
            if not raw_images:
                return None
            imgs = filter_images(raw_images)
            if not imgs:
                return None
            if prefer_webm:
                webm = [i for i in imgs if i.get("mime") == "image/webm"]
                pool = sorted(webm or imgs, key=score_image, reverse=True)
            else:
                pool = sorted(imgs, key=score_image, reverse=True)
            return pool[0].get("url", pool[0].get("thumb"))

        if prefer_animated:
            raw = do_request(make_url("animated", with_dims=True))
            if raw is None and dimensions:
                raw = do_request(make_url("animated", with_dims=False))
            image_url = best_image(raw, prefer_webm=False)
            if image_url:
                self.image_cache.set(cache_key, image_url)
                return self._local_or_url(image_url)

        raw = do_request(make_url("static", with_dims=True, mimes_val="image/png"))
        if raw is None and dimensions:
            raw = do_request(make_url("static", with_dims=False, mimes_val="image/png"))
        image_url = best_image(raw, prefer_webm=False)
        if image_url:
            self.image_cache.set(cache_key, image_url)
            return self._local_or_url(image_url)

        if game_name:
            sgdb_id = self._search_sgdb_id_by_name(game_name, api_key, timeout)
            if sgdb_id:
                name_base = (
                    f"https://www.steamgriddb.com/api/v2/{endpoint}/game/{sgdb_id}"
                )
                if prefer_animated:
                    raw = do_request(
                        make_url("animated", with_dims=True, url_base=name_base)
                    )
                    if raw is None and dimensions:
                        raw = do_request(
                            make_url("animated", with_dims=False, url_base=name_base)
                        )
                    image_url = best_image(raw, prefer_webm=False)
                    if image_url:
                        self.image_cache.set(cache_key, image_url)
                        return self._local_or_url(image_url)
                raw = do_request(
                    make_url(
                        "static",
                        with_dims=True,
                        mimes_val="image/png",
                        url_base=name_base,
                    )
                )
                if raw is None and dimensions:
                    raw = do_request(
                        make_url(
                            "static",
                            with_dims=False,
                            mimes_val="image/png",
                            url_base=name_base,
                        )
                    )
                image_url = best_image(raw, prefer_webm=False)
                if image_url:
                    self.image_cache.set(cache_key, image_url)
                    return self._local_or_url(image_url)

        self.image_cache.set(cache_key, "")
        return None

    # ── Logo ───────────────────────────────────────────────────────────────

    def get_steamgriddb_logo_url(
        self, app_id: str, platform: str = "steam", game_name: str = ""
    ) -> Optional[str]:
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False):
            return None
        api_key = sgdb_config.get("api_key", "")
        if not api_key:
            return None

        cache_key = f"{platform}:{app_id}:logo"
        cached_url = self.image_cache.get(cache_key)
        if cached_url is not None:
            return self._local_or_url(cached_url) if cached_url else None

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
                        return self._local_or_url(logo_url)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.image_cache.set(cache_key, "")
        except (urllib.error.URLError, json.JSONDecodeError) as e:
            print(f"[sgdb] name fallback failed: {e}", file=sys.stderr)

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
                            logo_url = d2["data"][0].get(
                                "url", d2["data"][0].get("thumb")
                            )
                            self.image_cache.set(cache_key, logo_url)
                            return self._local_or_url(logo_url)
                except (urllib.error.URLError, json.JSONDecodeError) as e:
                    print(f"[sgdb] logo name fallback failed: {e}", file=sys.stderr)

        self.image_cache.set(cache_key, "")
        return None

    # ── Helpers cover haut niveau ──────────────────────────────────────────

    def get_steam_cover_url(self, app_id: str) -> str:
        sgdb_url = self.get_steamgriddb_cover_url(app_id, platform="steam")
        if sgdb_url:
            return sgdb_url
        sgdb_config = self.config.get("steamgriddb", {})
        if sgdb_config.get("enabled", False) and not sgdb_config.get(
            "fallback_to_steam", True
        ):
            return ""
        return self.get_steam_cdn_fallback_url(app_id)

    def get_heroic_cover_url(
        self, app_id: str, source: str, art_url: str = "", game_name: str = ""
    ) -> str:
        platform = self.get_steamgriddb_platform(source, source)
        sgdb_url = self.get_steamgriddb_cover_url(
            app_id, platform=platform, game_name=game_name
        )
        return sgdb_url if sgdb_url else art_url

    # ── Slideshow ──────────────────────────────────────────────────────────

    def get_steamgriddb_slideshow_urls(
        self, app_id: str, platform: str = "steam", game_name: str = "", n: int = 3
    ) -> List[str]:
        """Returns top N static image URLs for BigPicture hero slideshow."""
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False):
            return []
        api_key = sgdb_config.get("api_key", "")
        if not api_key:
            return []

        image_type = sgdb_config.get("image_type", "grid")
        endpoint_map = {
            "grid": "grids",
            "hero": "heroes",
            "logo": "logos",
            "icon": "icons",
        }
        endpoint = endpoint_map.get(image_type, "grids")

        cache_key = f"{platform}:{app_id}:{image_type}:slideshow"
        cached_val = self.image_cache.get(cache_key)
        if cached_val is not None:
            try:
                urls = json.loads(cached_val)
                return [self._local_or_url(u) for u in urls]
            except Exception:
                return []

        timeout = sgdb_config.get("request_timeout", 3)
        base_url = f"https://www.steamgriddb.com/api/v2/{endpoint}/{platform}/{app_id}"

        def score_image(img):
            likes = img.get("likes") or 0
            if sgdb_config.get("sort_by_likes", False):
                return likes
            score = likes * 1000
            if img.get("width") and img.get("height"):
                score += img["width"] * img["height"] // 100
            if img.get("mime") == "image/png":
                score += 500
            return score

        def do_request(url):
            try:
                req = urllib.request.Request(url)
                req.add_header("Authorization", f"Bearer {api_key}")
                req.add_header("User-Agent", "QuickShell-GameLauncher/2.0")
                req.add_header("Accept", "application/json")
                with urllib.request.urlopen(req, timeout=timeout) as resp:
                    data = json.loads(resp.read().decode())
                    if data.get("success") and data.get("data"):
                        return data["data"]
            except (urllib.error.URLError, json.JSONDecodeError, TimeoutError) as e:
                print(f"[sgdb] request failed: {e}", file=sys.stderr)
            return None

        def top_images(raw, count):
            if not raw:
                return []
            imgs = [img for img in raw if img.get("width", 0) >= 300]
            imgs = sorted(imgs, key=score_image, reverse=True)
            return [
                img.get("url") or img.get("thumb")
                for img in imgs[:count]
                if img.get("url") or img.get("thumb")
            ]

        query = "?types=static&mimes=image/png&nsfw=false&humor=false&epilepsy=false"
        raw = do_request(base_url + query)
        urls = top_images(raw, n)

        if not urls and game_name:
            sgdb_id = self._search_sgdb_id_by_name(game_name, api_key, timeout)
            if sgdb_id:
                name_base = (
                    f"https://www.steamgriddb.com/api/v2/{endpoint}/game/{sgdb_id}"
                )
                raw = do_request(name_base + query)
                urls = top_images(raw, n)

        self.image_cache.set(cache_key, json.dumps(urls))
        return [self._local_or_url(u) for u in urls]

    # ── Fetch parallèle ────────────────────────────────────────────────────

    def fetch_images_parallel(
        self, games: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        sgdb_config = self.config.get("steamgriddb", {})
        if not sgdb_config.get("enabled", False) or not sgdb_config.get(
            "parallel_requests", True
        ):
            return games

        max_workers = sgdb_config.get("max_workers", 10)
        prefer_animated = sgdb_config.get("prefer_animated", False)

        games_to_fetch = []
        for i, game in enumerate(games):
            source = game.get("source", "")
            category = game.get("category", "")
            image = game.get("image", "")
            valid_source = source in [
                "steam",
                "epic",
                "gog",
                "amazon",
                "heroic",
                "sideload",
            ]
            is_shortcut = category == "steam-shortcut"
            is_sideload = category == "sideload" or source in ["heroic", "sideload"]
            needs_fetch = (
                not image or "steamstatic.com" in image or is_shortcut or is_sideload
            )
            if valid_source and game.get("appid") and needs_fetch:
                games_to_fetch.append((i, game))

        if not games_to_fetch:
            return games

        if not self._check_connectivity():
            return games

        def fetch_all(item):
            idx, game = item
            platform = self.get_steamgriddb_platform(
                game.get("source", ""), game.get("category", "")
            )
            appid = game.get("appid")
            name = game.get("name", "")

            # Toujours récupérer la version statique
            static_url = self.get_steamgriddb_cover_url(
                appid, platform, game_name=name, prefer_animated=False
            )
            if (
                not static_url
                and game.get("source") == "steam"
                and game.get("category") != "steam-shortcut"
            ):
                static_url = self.get_steam_cdn_fallback_url(appid)

            # Version animée séparée si activée
            animated_url = None
            if prefer_animated:
                animated_url = self.get_steamgriddb_cover_url(
                    appid, platform, game_name=name, prefer_animated=True
                )
                # Si l'animée est identique à la statique (pas d'animée dispo), on la vide
                if animated_url and animated_url == static_url:
                    animated_url = None

            logo_url = self.get_steamgriddb_logo_url(appid, platform, game_name=name)
            slideshow_urls = self.get_steamgriddb_slideshow_urls(
                appid, platform, game_name=name, n=3
            )
            return idx, static_url, animated_url, logo_url, slideshow_urls

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = {
                executor.submit(fetch_all, item): item for item in games_to_fetch
            }
            for future in as_completed(futures):
                try:
                    idx, static_url, animated_url, logo_url, slideshow_urls = (
                        future.result()
                    )
                    if static_url:
                        games[idx]["image"] = static_url
                    if animated_url:
                        games[idx]["image_animated"] = animated_url
                    if logo_url:
                        games[idx]["logo"] = logo_url
                    if slideshow_urls:
                        games[idx]["images"] = slideshow_urls
                except Exception as e:
                    game_name = (
                        games[idx].get("name", "?") if 0 <= idx < len(games) else "?"
                    )
                    print(
                        f"[sgdb] image fetch failed for {game_name}: {e}",
                        file=sys.stderr,
                    )

        return games
