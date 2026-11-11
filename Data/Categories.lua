-- Datenbank: welche Addons dieselbe Aufgabe erfüllen.
-- Erkennung über Teile des Ordnernamens (klein geschrieben).
-- patterns: Teile des Ordnernamens (sichere Erkennung, gepflegte Liste)
-- keywords: Begriffe in Titel, Beschreibung oder Kategorie der .toc (automatische Erkennung
--           für Addons, die nicht in der Liste stehen)
-- STARTSET – Ordnernamen werden mit echten Addons abgeglichen und regelmäßig erweitert.
local addonName, ns = ...

ns.DataVersion = "2026-11-11"  -- Stand der Datenbank, wird bei jedem Daten-Update erhöht

-- exclusive = true: zwei Addons dieser Kategorie gleichzeitig sind fast immer doppelt
-- builtin   = Name einer Funktion, die Forever schon eingebaut hat
ns.Categories = {
    questhelper = {
        de = "Quest-Helfer", en = "quest helper", exclusive = true,
        keywords = { "quest helper", "questhelper", "quest database", "quest markers" },
        patterns = { "^questie", "foreverquest", "foreverquestpins", "voidquest", "upquest" },
    },
    ui_suite = {
        de = "komplette UI-Suiten", en = "full UI suite", exclusive = true,
        keywords = { "ui suite", "interface replacement", "complete ui", "full ui", "ui-suite", "komplette ui" },
        patterns = { "^elvui", "ellesmereui", "foreverui", "daylightui", "melloui", "luckyoneui" },
    },
    bags = {
        de = "Taschen-Addons", en = "bag addon", exclusive = true,
        keywords = { "bag replacement", "bags and bank", "all-in-one bag", "bag addon", "taschen-addon" },
        patterns = { "^baganator", "^bagnon", "^adibags", "^satchel", "arkinventory" },
    },
    damage_meter = {
        de = "Schadensmesser", en = "damage meter", exclusive = true,
        builtin = { de = "Damage-Meter", en = "damage meter", clients = { forever = true, retail = true } },
        keywords = { "damage meter", "dps meter", "damage and healing meter", "schadensmesser" },
        patterns = { "^details", "^skada", "^recount", "forevermeter" },
    },
    swing_timer = {
        de = "Swing-Timer", en = "swing timer", exclusive = true,
        builtin = { de = "Swing-Timer", en = "swing timer", clients = { forever = true } },
        keywords = { "swing timer" },
        patterns = { "swingtimer", "weaponswing" },
    },
    gear_upgrade = {
        de = "Ausrüstungs-Berater", en = "gear advisor", exclusive = true,
        keywords = { "gear upgrade", "upgrade arrow", "best in slot", "stat weights", "gear advisor" },
        patterns = { "forevergear", "gearedforever", "gearquest", "bisgoblin", "upgrado",
                     "upgradearrow", "pathwisegear", "simgearforever", "evergear", "^pawn" },
    },
    travel = {
        de = "Reise-Planer", en = "travel planner", exclusive = true,
        keywords = { "route planner", "fastest route", "travel route", "travel planner" },
        patterns = { "^aznav", "slipstream", "travelcraft", "mapzeroth" },
    },
    nameplates = {
        de = "Namensplaketten-Addons", en = "nameplate addon", exclusive = true,
        keywords = { "nameplate addon", "nameplates replacement", "custom nameplates" },
        patterns = { "^plater", "platynator", "^kui_nameplates", "^threatplates" },
    },
    perf_monitor = {
        de = "Leistungsmonitore", en = "performance monitor", exclusive = true,
        keywords = { "memory usage", "cpu usage", "addon usage", "performance monitor" },
        patterns = { "freeloader", "donttouchmyram", "wowtaskmanager", "addonusage", "lagbuddy" },
    },
}

-- Addons, die nie als Problem gemeldet werden (Bibliotheken, wir selbst)
ns.IgnoredAddons = {
    [addonName:lower()] = true,
}
ns.IgnoredPatterns = { "^lib", "^ace3", "^!bug", "^bugsack", "^buggrabber" }
