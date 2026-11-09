// ColorThemes.qml — Paletas de color para la shell
// Cada tema define un objeto con dark/light variants.
// palette(id, dark) devuelve el objeto de colores para Config.qml.
pragma Singleton
import Quickshell
import QtQuick

Singleton {

    // ── Catálogo de temas ─────────────────────────────────────────────────
    // Estructura de cada tema: { id, label, accent_dark, accent_light, dark{...}, light{...} }
    // Los campos de cada variant: bgColor, bgSolid, surface, surface1, surface2,
    //   surfaceVariant, textPrimary, textSecondary, textHint,
    //   outline, divider, hoverBg, hoverBgStrong, popupBg, popupBorder
    readonly property var themes: [
        {
            id: "matugen",
            label: "Matugen (wallpaper)",
            accent_dark:  "#89B4FA",
            accent_light: "#1967D2",
            dark:  {},
            light: {}
        },
        {
            id: "default",
            label: "ChromeOS / Google",
            accent_dark:  "#89B4FA",
            accent_light: "#1967D2",
            dark: {
                bgColor: "#E0141414", bgSolid: "#141414",
                surface: "#1C1C1C", surface1: "#222222", surface2: "#2A2A2A",
                surfaceVariant: "#1E2433",
                textPrimary: "#E8EAED", textSecondary: "#9AA0A6", textHint: "#5F6368",
                outline: "#5F6368", divider: "#3C4043",
                hoverBg: "#2A2A2A", hoverBgStrong: "#333333",
                popupBg: "#1A1A1A", popupBorder: "#333333",
                red: "#F28B82", green: "#81C995", yellow: "#FDD663", blue: "#8AB4F8",
                teal: "#78D9EC", peach: "#FAB387", mauve: "#C58AF9",
                tooltipBg: "#3C4043", tooltipText: "#FFFFFF"
            },
            light: {
                bgColor: "#E0FFFFFF", bgSolid: "#FFFFFF",
                surface: "#F8F9FA", surface1: "#F1F3F4", surface2: "#E8EAED",
                surfaceVariant: "#E8F0FE",
                textPrimary: "#202124", textSecondary: "#5F6368", textHint: "#9AA0A6",
                outline: "#DADCE0", divider: "#E8EAED",
                hoverBg: "#FFFFFF", hoverBgStrong: "#F1F3F4",
                popupBg: "#FFFFFF", popupBorder: "#DADCE0",
                red: "#C5221F", green: "#1E8E3E", yellow: "#E37400", blue: "#4d6a9e",
                teal: "#007B83", peach: "#E8710A", mauve: "#7C4DFF",
                tooltipBg: "#202124", tooltipText: "#FFFFFF"
            }
        },
        {
            id: "catppuccin-mocha",
            label: "Catppuccin Mocha",
            accent_dark:  "#89B4FA",
            accent_light: "#1E66F5",
            dark: {
                bgColor: "#E0181825", bgSolid: "#181825",
                surface: "#1E1E2E", surface1: "#1E1E2E", surface2: "#313244",
                surfaceVariant: "#1E2740",
                textPrimary: "#CDD6F4", textSecondary: "#BAC2DE", textHint: "#6C7086",
                outline: "#45475A", divider: "#313244",
                hoverBg: "#313244", hoverBgStrong: "#45475A",
                popupBg: "#1E1E2E", popupBorder: "#313244",
                red: "#F38BA8", green: "#A6E3A1", yellow: "#F9E2AF", blue: "#89B4FA",
                teal: "#94E2D5", peach: "#FAB387", mauve: "#CBA6F7",
                tooltipBg: "#313244", tooltipText: "#CDD6F4"
            },
            light: {
                bgColor: "#E0EFF1F5", bgSolid: "#EFF1F5",
                surface: "#E6E9EF", surface1: "#DCE0E8", surface2: "#CCD0DA",
                surfaceVariant: "#E0E9FF",
                textPrimary: "#4C4F69", textSecondary: "#5C5F77", textHint: "#8C8FA1",
                outline: "#ACB0BE", divider: "#BCC0CC",
                hoverBg: "#E6E9EF", hoverBgStrong: "#DCE0E8",
                popupBg: "#EFF1F5", popupBorder: "#BCC0CC",
                red: "#D20F39", green: "#40A02B", yellow: "#DF8E1D", blue: "#1E66F5",
                teal: "#179299", peach: "#FE640B", mauve: "#8839EF",
                tooltipBg: "#4C4F69", tooltipText: "#EFF1F5"
            }
        },
        {
            id: "catppuccin-macchiato",
            label: "Catppuccin Macchiato",
            accent_dark:  "#8AADF4",
            accent_light: "#1E66F5",
            dark: {
                bgColor: "#E0181926", bgSolid: "#181926",
                surface: "#1E2030", surface1: "#1E2030", surface2: "#2E3347",
                surfaceVariant: "#1E2740",
                textPrimary: "#CAD3F5", textSecondary: "#B8C0E0", textHint: "#6E738D",
                outline: "#494D64", divider: "#363A4F",
                hoverBg: "#2E3347", hoverBgStrong: "#494D64",
                popupBg: "#1E2030", popupBorder: "#363A4F",
                red: "#ED8796", green: "#A6DA95", yellow: "#EED49F", blue: "#8AADF4",
                teal: "#8BD5CA", peach: "#F5A97F", mauve: "#C6A0F6",
                tooltipBg: "#2E3347", tooltipText: "#CAD3F5"
            },
            light: {
                bgColor: "#E0EFF1F5", bgSolid: "#EFF1F5",
                surface: "#E6E9EF", surface1: "#DCE0E8", surface2: "#CCD0DA",
                surfaceVariant: "#E0E9FF",
                textPrimary: "#4C4F69", textSecondary: "#5C5F77", textHint: "#8C8FA1",
                outline: "#ACB0BE", divider: "#BCC0CC",
                hoverBg: "#E6E9EF", hoverBgStrong: "#DCE0E8",
                popupBg: "#EFF1F5", popupBorder: "#BCC0CC",
                red: "#D20F39", green: "#40A02B", yellow: "#DF8E1D", blue: "#1E66F5",
                teal: "#179299", peach: "#FE640B", mauve: "#8839EF",
                tooltipBg: "#4C4F69", tooltipText: "#EFF1F5"
            }
        },
        {
            id: "nord",
            label: "Nord",
            accent_dark:  "#88C0D0",
            accent_light: "#5E81AC",
            dark: {
                bgColor: "#E02E3440", bgSolid: "#2E3440",
                surface: "#2E3440", surface1: "#3B4252", surface2: "#434C5E",
                surfaceVariant: "#2B3A4A",
                textPrimary: "#ECEFF4", textSecondary: "#D8DEE9", textHint: "#4C566A",
                outline: "#4C566A", divider: "#3B4252",
                hoverBg: "#3B4252", hoverBgStrong: "#434C5E",
                popupBg: "#2E3440", popupBorder: "#3B4252",
                red: "#BF616A", green: "#A3BE8C", yellow: "#EBCB8B", blue: "#88C0D0",
                teal: "#8FBCBB", peach: "#D08770", mauve: "#B48EAD",
                tooltipBg: "#3B4252", tooltipText: "#ECEFF4"
            },
            light: {
                bgColor: "#E0ECEFF4", bgSolid: "#ECEFF4",
                surface: "#E5E9F0", surface1: "#D8DEE9", surface2: "#CBD0DA",
                surfaceVariant: "#DCE6F0",
                textPrimary: "#2E3440", textSecondary: "#3B4252", textHint: "#9099A8",
                outline: "#CBD0DA", divider: "#D8DEE9",
                hoverBg: "#E5E9F0", hoverBgStrong: "#D8DEE9",
                popupBg: "#ECEFF4", popupBorder: "#D8DEE9",
                red: "#B7182A", green: "#4E7A3D", yellow: "#C08A00", blue: "#5E81AC",
                teal: "#4D8A89", peach: "#A05A30", mauve: "#8A6A9A",
                tooltipBg: "#2E3440", tooltipText: "#ECEFF4"
            }
        },
        {
            id: "dracula",
            label: "Dracula",
            accent_dark:  "#BD93F9",
            accent_light: "#6272A4",
            dark: {
                bgColor: "#E0282A36", bgSolid: "#282A36",
                surface: "#282A36", surface1: "#21222C", surface2: "#44475A",
                surfaceVariant: "#2D2B4E",
                textPrimary: "#F8F8F2", textSecondary: "#6272A4", textHint: "#44475A",
                outline: "#44475A", divider: "#373B53",
                hoverBg: "#44475A", hoverBgStrong: "#6272A4",
                popupBg: "#21222C", popupBorder: "#44475A",
                red: "#FF5555", green: "#50FA7B", yellow: "#F1FA8C", blue: "#BD93F9",
                teal: "#8BE9FD", peach: "#FFB86C", mauve: "#FF79C6",
                tooltipBg: "#44475A", tooltipText: "#F8F8F2"
            },
            light: {
                bgColor: "#E0F8F8F2", bgSolid: "#F8F8F2",
                surface: "#EEEEEA", surface1: "#E4E4DF", surface2: "#D5D5CF",
                surfaceVariant: "#E8E6F8",
                textPrimary: "#282A36", textSecondary: "#44475A", textHint: "#6272A4",
                outline: "#D5D5CF", divider: "#E4E4DF",
                hoverBg: "#EEEEEA", hoverBgStrong: "#E4E4DF",
                popupBg: "#F8F8F2", popupBorder: "#D5D5CF",
                red: "#C23232", green: "#228B22", yellow: "#B8A800", blue: "#6272A4",
                teal: "#007A9A", peach: "#D07040", mauve: "#8B3A8B",
                tooltipBg: "#282A36", tooltipText: "#F8F8F2"
            }
        },
        {
            id: "gruvbox",
            label: "Gruvbox",
            accent_dark:  "#FABD2F",
            accent_light: "#B57614",
            dark: {
                bgColor: "#E0282828", bgSolid: "#282828",
                surface: "#282828", surface1: "#3C3836", surface2: "#504945",
                surfaceVariant: "#32302F",
                textPrimary: "#EBDBB2", textSecondary: "#A89984", textHint: "#665C54",
                outline: "#504945", divider: "#3C3836",
                hoverBg: "#3C3836", hoverBgStrong: "#504945",
                popupBg: "#1D2021", popupBorder: "#3C3836",
                red: "#FB4934", green: "#B8BB26", yellow: "#FABD2F", blue: "#83A598",
                teal: "#8EC07C", peach: "#FE8019", mauve: "#D3869B",
                tooltipBg: "#3C3836", tooltipText: "#EBDBB2"
            },
            light: {
                bgColor: "#E0FBF1C7", bgSolid: "#FBF1C7",
                surface: "#EDDBB2", surface1: "#D5C4A1", surface2: "#BDAE93",
                surfaceVariant: "#F2E5BC",
                textPrimary: "#3C3836", textSecondary: "#665C54", textHint: "#928374",
                outline: "#BDAE93", divider: "#D5C4A1",
                hoverBg: "#EDDBB2", hoverBgStrong: "#D5C4A1",
                popupBg: "#FBF1C7", popupBorder: "#D5C4A1",
                red: "#CC241D", green: "#79740E", yellow: "#B57614", blue: "#458588",
                teal: "#689D6A", peach: "#D65D0E", mauve: "#8F3F71",
                tooltipBg: "#3C3836", tooltipText: "#FBF1C7"
            }
        },
        {
            id: "rose-pine",
            label: "Rosé Pine",
            accent_dark:  "#EBBCBA",
            accent_light: "#B4637A",
            dark: {
                bgColor: "#E0191724", bgSolid: "#191724",
                surface: "#1F1D2E", surface1: "#26233A", surface2: "#403D52",
                surfaceVariant: "#2A2040",
                textPrimary: "#E0DEF4", textSecondary: "#908CAA", textHint: "#6E6A86",
                outline: "#403D52", divider: "#26233A",
                hoverBg: "#26233A", hoverBgStrong: "#403D52",
                popupBg: "#1F1D2E", popupBorder: "#26233A",
                red: "#EB6F92", green: "#31748F", yellow: "#F6C177", blue: "#9CCFD8",
                teal: "#31748F", peach: "#F6C177", mauve: "#C4A7E7",
                tooltipBg: "#26233A", tooltipText: "#E0DEF4"
            },
            light: {
                bgColor: "#E0FAF4ED", bgSolid: "#FAF4ED",
                surface: "#FFFAF3", surface1: "#F2E9E1", surface2: "#D4C9BF",
                surfaceVariant: "#F4EEF8",
                textPrimary: "#575279", textSecondary: "#797593", textHint: "#9893A5",
                outline: "#D4C9BF", divider: "#F2E9E1",
                hoverBg: "#FFFAF3", hoverBgStrong: "#F2E9E1",
                popupBg: "#FAF4ED", popupBorder: "#D4C9BF",
                red: "#B4637A", green: "#286983", yellow: "#EA9D34", blue: "#56949F",
                teal: "#286983", peach: "#D7827E", mauve: "#907AA9",
                tooltipBg: "#575279", tooltipText: "#FAF4ED"
            }
        },
        {
            id: "tokyo-night",
            label: "Tokyo Night",
            accent_dark:  "#7AA2F7",
            accent_light: "#2959A8",
            dark: {
                bgColor: "#E01A1B2E", bgSolid: "#1A1B2E",
                surface: "#16161E", surface1: "#1F2335", surface2: "#292E42",
                surfaceVariant: "#1A2040",
                textPrimary: "#C0CAF5", textSecondary: "#565F89", textHint: "#414868",
                outline: "#292E42", divider: "#1F2335",
                hoverBg: "#1F2335", hoverBgStrong: "#292E42",
                popupBg: "#16161E", popupBorder: "#1F2335",
                red: "#F7768E", green: "#9ECE6A", yellow: "#E0AF68", blue: "#7AA2F7",
                teal: "#73DACA", peach: "#FF9E64", mauve: "#BB9AF7",
                tooltipBg: "#1F2335", tooltipText: "#C0CAF5"
            },
            light: {
                bgColor: "#E0D5D6DB", bgSolid: "#D5D6DB",
                surface: "#E1E2E7", surface1: "#CBCCD1", surface2: "#B9BAC1",
                surfaceVariant: "#D4D8F0",
                textPrimary: "#343B58", textSecondary: "#565A6E", textHint: "#848CB5",
                outline: "#B9BAC1", divider: "#CBCCD1",
                hoverBg: "#E1E2E7", hoverBgStrong: "#CBCCD1",
                popupBg: "#D5D6DB", popupBorder: "#B9BAC1",
                red: "#C0354D", green: "#5A7A3A", yellow: "#9C6E00", blue: "#2959A8",
                teal: "#007A87", peach: "#B05A1A", mauve: "#7049A8",
                tooltipBg: "#343B58", tooltipText: "#D5D6DB"
            }
        },
        {
            id: "solarized",
            label: "Solarized",
            accent_dark:  "#268BD2",
            accent_light: "#0F65A8",
            dark: {
                bgColor: "#E0002B36", bgSolid: "#002B36",
                surface: "#073642", surface1: "#073642", surface2: "#0D4D5F",
                surfaceVariant: "#003D4D",
                textPrimary: "#839496", textSecondary: "#657B83", textHint: "#586E75",
                outline: "#073642", divider: "#073642",
                hoverBg: "#073642", hoverBgStrong: "#0D4D5F",
                popupBg: "#002B36", popupBorder: "#073642",
                red: "#DC322F", green: "#859900", yellow: "#B58900", blue: "#268BD2",
                teal: "#2AA198", peach: "#CB4B16", mauve: "#6C71C4",
                tooltipBg: "#073642", tooltipText: "#FDF6E3"
            },
            light: {
                bgColor: "#E0FDF6E3", bgSolid: "#FDF6E3",
                surface: "#EEE8D5", surface1: "#EEE8D5", surface2: "#DDD8C3",
                surfaceVariant: "#E8F0D5",
                textPrimary: "#657B83", textSecondary: "#839496", textHint: "#93A1A1",
                outline: "#DDD8C3", divider: "#EEE8D5",
                hoverBg: "#EEE8D5", hoverBgStrong: "#DDD8C3",
                popupBg: "#FDF6E3", popupBorder: "#DDD8C3",
                red: "#DC322F", green: "#859900", yellow: "#B58900", blue: "#0F65A8",
                teal: "#2AA198", peach: "#CB4B16", mauve: "#6C71C4",
                tooltipBg: "#073642", tooltipText: "#FDF6E3"
            }
        },
        {
            id: "everforest",
            label: "Everforest",
            accent_dark:  "#A7C080",
            accent_light: "#5A7A50",
            dark: {
                bgColor: "#E0272E33", bgSolid: "#272E33",
                surface: "#2D353B", surface1: "#343F44", surface2: "#3D484D",
                surfaceVariant: "#2E3A2E",
                textPrimary: "#D3C6AA", textSecondary: "#859289", textHint: "#5C6A72",
                outline: "#3D484D", divider: "#343F44",
                hoverBg: "#343F44", hoverBgStrong: "#3D484D",
                popupBg: "#2D353B", popupBorder: "#343F44",
                red: "#E67E80", green: "#A7C080", yellow: "#DBBC7F", blue: "#7FBBB3",
                teal: "#83C092", peach: "#E69875", mauve: "#D699B6",
                tooltipBg: "#343F44", tooltipText: "#D3C6AA"
            },
            light: {
                bgColor: "#E0FDF6E3", bgSolid: "#FDF6E3",
                surface: "#F2EFDF", surface1: "#EDEADA", surface2: "#E0DDD0",
                surfaceVariant: "#ECF0E4",
                textPrimary: "#5C6A72", textSecondary: "#859289", textHint: "#A6B0A0",
                outline: "#E0DDD0", divider: "#EDEADA",
                hoverBg: "#F2EFDF", hoverBgStrong: "#EDEADA",
                popupBg: "#FDF6E3", popupBorder: "#E0DDD0",
                red: "#C44D52", green: "#5A7A50", yellow: "#A07830", blue: "#4A9095",
                teal: "#4A8A60", peach: "#C07040", mauve: "#8A5A7A",
                tooltipBg: "#5C6A72", tooltipText: "#FDF6E3"
            }
        }
    ]

    // ── Función principal — devuelve la paleta para Config.qml ────────────
    function palette(id, dark) {
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === id)
                return dark ? themes[i].dark : themes[i].light
        }
        // fallback: default
        var def = themes[0]
        return dark ? def.dark : def.light
    }

    // ── Accent por defecto de un tema (para pre-seleccionar en el picker) ─
    function defaultAccent(id, dark) {
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].id === id)
                return dark ? themes[i].accent_dark : themes[i].accent_light
        }
        return dark ? "#89B4FA" : "#4d6a9e"
    }
}
