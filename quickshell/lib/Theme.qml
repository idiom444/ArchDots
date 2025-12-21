pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: theme

    // fallbacks (so your bar never goes invisible)
    property color bg: "#201f25"
    property color fg: "#e5e1e9"
    property color accent: "#c7bfff"
    property color outlineFallback: "#928f99"
    property font uiFont: Qt.font({
        family: "Cascadia Code",
	features: { "zero": 1 },
	pointSize: 10 
    })
    FileView {
        id: file
        // use an absolute path (no ~ expansion)
        path: "/home/Idiom/.config/wallpaper/material.json"

        watchChanges: true
        onFileChanged: this.reload()   // documented pattern :contentReference[oaicite:2]{index=2}

        JsonAdapter {
            id: j

            // your matugen JSON shape: colors.<role>.<dark|light|default>
            // (don't declare "default" as a property — it's a QML keyword)
            property JsonObject colors: JsonObject {
                property JsonObject background: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_background: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_dim: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_bright: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_container_lowest: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_container_low: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_container_high: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_container_highest: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_variant: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_surface: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_surface_variant: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject inverse_surface: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject inverse_on_surface: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject primary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_primary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject primary_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_primary_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject primary_fixed: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject primary_fixed_dim: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_primary_fixed: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_primary_fixed_variant: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject secondary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_secondary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject secondary_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_secondary_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject secondary_fixed: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject secondary_fixed_dim: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_secondary_fixed: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_secondary_fixed_variant: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject tertiary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_tertiary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject tertiary_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_tertiary_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject tertiary_fixed: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject tertiary_fixed_dim: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_tertiary_fixed: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_tertiary_fixed_variant: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject error: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_error: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject error_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject on_error_container: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject outline_variant: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject shadow: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject scrim: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject surface_tint: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject inverse_primary: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject source_color: JsonObject {
                    property string dark
                    property string light
                }
                property JsonObject outline: JsonObject {
                    property string dark
                    property string light
                }
            }

            property string mode
            property bool is_dark_mode
        }
    }

    FileView {
        id: hyprFile
        path: "/home/Idiom/.config/hypr/hyprland.conf"
        watchChanges: true
        onFileChanged: this.reload()
    }

    // reactive derived values (updates automatically when file reloads)
    property bool useDark: j.is_dark_mode || (j.mode === "dark")

    function pickColor(colorObj, fallback) {
        if (!colorObj) {
            return fallback
        }
        var value = useDark ? colorObj.dark : colorObj.light
        return value || fallback
    }

    function pickHyprOpacity(content, fallback) {
        if (!content) {
            return fallback
        }
        var match = content.match(/^\s*\$activeOpacity\s*=\s*([0-9]*\.?[0-9]+)/m)
        if (!match) {
            match = content.match(/^\s*active_opacity\s*=\s*([0-9]*\.?[0-9]+)/m)
        }
        if (match && match[1]) {
            var value = Number(match[1])
            if (!isNaN(value)) {
                return Math.max(0, Math.min(1, value))
            }
        }
        return fallback
    }

    property string hyprText: hyprFile.text()
    property real barOpacity: pickHyprOpacity(hyprText, 1.0)

    property color bg2: pickColor(j.colors.surface_container, bg)
    property color fg2: pickColor(j.colors.on_surface, fg)
    property color accent2: pickColor(j.colors.primary, accent)
    property color outline2: pickColor(j.colors.outline, outlineFallback)

    // full Material roles for wider use
    property color background: pickColor(j.colors.background, bg)
    property color on_background: pickColor(j.colors.on_background, fg)
    property color surface: pickColor(j.colors.surface, bg)
    property color surface_dim: pickColor(j.colors.surface_dim, bg)
    property color surface_bright: pickColor(j.colors.surface_bright, bg)
    property color surface_container_lowest: pickColor(j.colors.surface_container_lowest, bg)
    property color surface_container_low: pickColor(j.colors.surface_container_low, bg)
    property color surface_container: pickColor(j.colors.surface_container, bg)
    property color surface_container_high: pickColor(j.colors.surface_container_high, bg)
    property color surface_container_highest: pickColor(j.colors.surface_container_highest, bg)
    property color surface_variant: pickColor(j.colors.surface_variant, bg)
    property color on_surface: pickColor(j.colors.on_surface, fg)
    property color on_surface_variant: pickColor(j.colors.on_surface_variant, fg)
    property color inverse_surface: pickColor(j.colors.inverse_surface, fg)
    property color inverse_on_surface: pickColor(j.colors.inverse_on_surface, bg)
    property color primary: pickColor(j.colors.primary, accent)
    property color on_primary: pickColor(j.colors.on_primary, fg)
    property color primary_container: pickColor(j.colors.primary_container, accent)
    property color on_primary_container: pickColor(j.colors.on_primary_container, fg)
    property color primary_fixed: pickColor(j.colors.primary_fixed, accent)
    property color primary_fixed_dim: pickColor(j.colors.primary_fixed_dim, accent)
    property color on_primary_fixed: pickColor(j.colors.on_primary_fixed, fg)
    property color on_primary_fixed_variant: pickColor(j.colors.on_primary_fixed_variant, fg)
    property color secondary: pickColor(j.colors.secondary, accent)
    property color on_secondary: pickColor(j.colors.on_secondary, fg)
    property color secondary_container: pickColor(j.colors.secondary_container, accent)
    property color on_secondary_container: pickColor(j.colors.on_secondary_container, fg)
    property color secondary_fixed: pickColor(j.colors.secondary_fixed, accent)
    property color secondary_fixed_dim: pickColor(j.colors.secondary_fixed_dim, accent)
    property color on_secondary_fixed: pickColor(j.colors.on_secondary_fixed, fg)
    property color on_secondary_fixed_variant: pickColor(j.colors.on_secondary_fixed_variant, fg)
    property color tertiary: pickColor(j.colors.tertiary, accent)
    property color on_tertiary: pickColor(j.colors.on_tertiary, fg)
    property color tertiary_container: pickColor(j.colors.tertiary_container, accent)
    property color on_tertiary_container: pickColor(j.colors.on_tertiary_container, fg)
    property color tertiary_fixed: pickColor(j.colors.tertiary_fixed, accent)
    property color tertiary_fixed_dim: pickColor(j.colors.tertiary_fixed_dim, accent)
    property color on_tertiary_fixed: pickColor(j.colors.on_tertiary_fixed, fg)
    property color on_tertiary_fixed_variant: pickColor(j.colors.on_tertiary_fixed_variant, fg)
    property color error: pickColor(j.colors.error, accent)
    property color on_error: pickColor(j.colors.on_error, fg)
    property color error_container: pickColor(j.colors.error_container, accent)
    property color on_error_container: pickColor(j.colors.on_error_container, fg)
    property color outline: pickColor(j.colors.outline, outlineFallback)
    property color outline_variant: pickColor(j.colors.outline_variant, outlineFallback)
    property color shadow: pickColor(j.colors.shadow, "#000000")
    property color scrim: pickColor(j.colors.scrim, "#000000")
    property color surface_tint: pickColor(j.colors.surface_tint, accent)
    property color inverse_primary: pickColor(j.colors.inverse_primary, accent)
    property color source_color: pickColor(j.colors.source_color, accent)

    // expose final properties your bar will use
    // (alias keeps names simple in the rest of your config)
    property color barBg: bg2
    property color barFg: fg2
    property color barAccent: accent2
    property color barOutline: outline2
}
