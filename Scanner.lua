-- Scanner: Bestandsaufnahme aller installierten Addons
local addonName, ns = ...

local Scanner = {}
ns.Scanner = Scanner
Scanner.addons = {}
Scanner.initialEnabled = {} -- [Ordnername] = an/aus beim Login (bis zum nächsten Reload gültig)

-- Interface-Nummer des laufenden Clients (z. B. 16001)
local function GetClientInterface()
    local _, _, _, tocVersion = GetBuildInfo()
    return tocVersion
end

local function IsIgnored(folderLower)
    if ns.IgnoredAddons[folderLower] then return true end
    for _, pattern in ipairs(ns.IgnoredPatterns) do
        if folderLower:find(pattern) then return true end
    end
    return false
end

-- Farbcodes aus Texten entfernen
local function StripColors(text)
    return (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Kategorie(n) eines Addons finden:
-- 1. sicher über den Ordnernamen (gepflegte Liste)
-- 2. sonst automatisch über Titel, Beschreibung und Kategorie aus der .toc
local function FindCategories(name, folderLower, title)
    local found, auto = {}, false
    for key, category in pairs(ns.Categories) do
        for _, pattern in ipairs(category.patterns) do
            if folderLower:find(pattern) then
                found[#found + 1] = key
                break
            end
        end
    end
    if #found > 0 then return found, auto end

    local meta = C_AddOns.GetAddOnMetadata
    local text = table.concat({
        StripColors(title),
        StripColors(C_AddOns.GetAddOnNotes and C_AddOns.GetAddOnNotes(name) or ""),
        meta(name, "Category") or "",
        meta(name, "X-Category") or "",
    }, " "):lower()
    for key, category in pairs(ns.Categories) do
        for _, word in ipairs(category.keywords or {}) do
            if text:find(word, 1, true) then -- einfache Textsuche, keine Muster
                found[#found + 1] = key
                auto = true
                break
            end
        end
    end
    return found, auto
end

function Scanner.Scan()
    wipe(Scanner.addons)
    local clientInterface = GetClientInterface()
    local playerName = UnitName("player")

    for index = 1, C_AddOns.GetNumAddOns() do
        local name, title, _, loadable, reason, security = C_AddOns.GetAddOnInfo(index)
        if name and security == "INSECURE" then -- nur Spieler-Addons; Blizzard-Addons (SECURE/SECURE_PROTECTED) überspringen
            local lower = name:lower()
            local tocInterface = C_AddOns.GetAddOnInterfaceVersion and C_AddOns.GetAddOnInterfaceVersion(index)
            local entry = {
                name = name,
                title = (title and title ~= "") and title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") or name,
                loaded = C_AddOns.IsAddOnLoaded(index) and true or false,
                enabled = C_AddOns.GetAddOnEnableState(index, playerName) > 0,
                loadOnDemand = C_AddOns.IsAddOnLoadOnDemand(index) and true or false,
                reason = reason,                -- z. B. "INTERFACE_VERSION", "MISSING", "DEP_MISSING"
                interface = tocInterface,
                outdated = (reason == "INTERFACE_VERSION")
                    -- nur ÄLTERE Interface-Nummern melden; Addons für mehrere Versionen nicht fälschlich warnen
                    or (tocInterface and tocInterface > 0 and clientInterface
                        and math.floor(tocInterface / 100) < math.floor(clientInterface / 100)) or false,
                loadError = C_AddOns.DoesAddOnHaveLoadError and C_AddOns.DoesAddOnHaveLoadError(index) or false,
                ignored = IsIgnored(lower),
                categories = nil, -- wird direkt danach gesetzt
                cpu = 0,       -- ms, wird vom Profiler gefüllt
                memory = nil,  -- KB, nur nach Speicher-Messung
            }
            entry.categories, entry.autoCategory = FindCategories(name, lower, title)
            -- Zustand beim Login merken: spätere Scans sehen schon vorgemerkte Änderungen
            if Scanner.initialEnabled[name] == nil then Scanner.initialEnabled[name] = entry.enabled end
            entry.enabled = Scanner.initialEnabled[name]
            Scanner.addons[#Scanner.addons + 1] = entry
        end
    end
    return Scanner.addons
end

function Scanner.GetLoaded()
    local list = {}
    for _, entry in ipairs(Scanner.addons) do
        if entry.loaded then list[#list + 1] = entry end
    end
    return list
end
