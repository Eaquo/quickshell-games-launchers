import QtQuick

Item {
    id: i18n
    visible: false

    readonly property string lang: {
        const l = Qt.locale().name.split("_")[0]
        return strings[l] !== undefined ? l : "en"
    }

    readonly property string dateLocale: ({
        "fr": "fr-FR", "en": "en-US", "es": "es-ES", "ru": "ru-RU", "ja": "ja-JP"
    })[lang] || "en-US"

    function t(key) {
        const s = strings[lang] ?? strings["en"]
        return s[key] ?? strings["en"][key] ?? key
    }

    function formatDate(ts) {
        if (!ts || ts === 0) return ""
        const d = new Date(ts * 1000)
        return d.toLocaleDateString(dateLocale, { weekday: "long", day: "numeric", month: "long", year: "numeric" })
    }

    readonly property var strings: ({
        "fr": {
            new_badge:        "NOUVEAU",
            recent_badge:     "RÉCENT",
            all:              "Tous",
            favs:             "Favoris",
            search:           "Rechercher un jeu…",
            results:          "résultats",
            no_games:         "Aucun jeu trouvé",
            try_other:        "Essaie un autre terme",
            no_games_source:  "Aucun jeu dans cette source",
            loading:          "Recherche des jeux…",
            help_horiz:       "← → Naviguer │ ⏎ Lancer │ ALT+F Favori │ Esc Fermer",
            games:            "jeux",
            played_on:        "Joué le",
            playtime:         "Temps de jeu",
            last_session:     "Dernière session",
            install_size:     "Taille installée",
            last_update:      "Dernière MAJ",
            launch:           "LANCER",
            start_game:       "Démarrage",
        },
        "en": {
            new_badge:        "NEW",
            recent_badge:     "RECENT",
            all:              "All",
            favs:             "Favs",
            search:           "Search for a game…",
            results:          "results",
            no_games:         "No games found",
            try_other:        "Try another search term",
            no_games_source:  "No games in this source",
            loading:          "Looking for games…",
            help_horiz:       "← → Navigate │ ⏎ Launch │ ALT+F Favorite │ Esc Close",
            games:            "games",
            played_on:        "Played on",
            playtime:         "Play time",
            last_session:     "Last session",
            install_size:     "Install size",
            last_update:      "Last update",
            launch:           "LAUNCH",
            start_game:       "Start Game",
        },
        "es": {
            new_badge:        "NUEVO",
            recent_badge:     "RECIENTE",
            all:              "Todos",
            favs:             "Favoritos",
            search:           "Buscar un juego…",
            results:          "resultados",
            no_games:         "No se encontraron juegos",
            try_other:        "Intenta otro término",
            no_games_source:  "No hay juegos en esta fuente",
            loading:          "Buscando juegos…",
            help_horiz:       "← → Navegar │ ⏎ Iniciar │ ALT+F Favorito │ Esc Cerrar",
            games:            "juegos",
            played_on:        "Jugado el",
            playtime:         "Tiempo de juego",
            last_session:     "Última sesión",
            install_size:     "Tamaño instalado",
            last_update:      "Última actualización",
            launch:           "INICIAR",
            start_game:       "Iniciar Juego",
        },
        "ru": {
            new_badge:        "НОВЫЙ",
            recent_badge:     "НЕДАВНО",
            all:              "Все",
            favs:             "Избр.",
            search:           "Поиск игры…",
            results:          "результатов",
            no_games:         "Игры не найдены",
            try_other:        "Попробуй другой запрос",
            no_games_source:  "Нет игр в этом источнике",
            loading:          "Поиск игр…",
            help_horiz:       "← → Навигация │ ⏎ Запуск │ ALT+F Избранное │ Esc Закрыть",
            games:            "игр",
            played_on:        "Сыграно",
            playtime:         "Время игры",
            last_session:     "Последняя сессия",
            install_size:     "Размер установки",
            last_update:      "Последнее обновление",
            launch:           "ЗАПУСК",
            start_game:       "Запуск игры",
        },
        "ja": {
            new_badge:        "新着",
            recent_badge:     "最近",
            all:              "すべて",
            favs:             "お気に入り",
            search:           "ゲームを検索…",
            results:          "件",
            no_games:         "ゲームが見つかりません",
            try_other:        "別のキーワードで検索",
            no_games_source:  "このソースにゲームがありません",
            loading:          "ゲームを検索中…",
            help_horiz:       "← → ナビ │ ⏎ 起動 │ ALT+F お気に入り │ Esc 閉じる",
            games:            "ゲーム",
            played_on:        "プレイ日",
            playtime:         "プレイ時間",
            last_session:     "最終セッション",
            install_size:     "インストールサイズ",
            last_update:      "最終更新",
            launch:           "起動",
            start_game:       "ゲームを起動",
        },
    })
}
