-- Kern: Initialisierung, Events, SavedVariables, Slash-Befehle
local addonName, ns = ...
local L = ns.L

ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "?"

-- Welche WoW-Version läuft? Steuert, welche Regeln gelten (z. B. eingebauter Damage-Meter)
do
    local _, _, _, toc = GetBuildInfo()
    ns.clientInterface = toc or 0
    if toc >= 16000 and toc < 17000 then ns.client = "forever"
    elseif toc >= 100000 then ns.client = "retail"
    else ns.client = "classic" end -- Classic Era, Anniversary, MoP Classic
end

-- Vorlagen und Schriften gibt es nicht in jedem Client: sicher erzeugen mit Ausweichlösung
function ns.CreateFrameSafe(frameType, name, parent, template, fallback)
    local ok, f = pcall(CreateFrame, frameType, name, parent, template)
    if ok and f then return f end
    return CreateFrame(frameType, name, parent, fallback)
end

function ns.Font(preferred, fallback)
    return _G[preferred] and preferred or fallback
end

-- Standardwerte für gespeicherte Daten
local DEFAULTS = {
    ignoredIssues = {},  -- ["dup:A|B"] = true -> Befund dauerhaft ausblenden
    minimap = { hide = false, angle = 215 },
    profiles = {},       -- [Situation] = { addons = {[Name]=true}, ask = true }
    profilePrompts = true,
    scanOnLogin = true,  -- Diagnose automatisch nach dem Login
    loginHint = true,    -- Chat-Hinweis, wenn beim Login Probleme gefunden wurden
}
local CHAR_DEFAULTS = {}

-- Fehlende Schlüssel rekursiv mit Standardwerten auffüllen
local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

function ns.Print(msg)
    print("|cff4fc3f7[" .. L["TITLE"] .. "]|r " .. tostring(msg))
end

-- Event-Frame mit Dispatcher-Tabelle
local frame = CreateFrame("Frame")
local events = {}

function events:ADDON_LOADED(loaded)
    if loaded ~= addonName then return end
    AddonDoktorDB = AddonDoktorDB or {}
    AddonDoktorCharDB = AddonDoktorCharDB or {}
    ApplyDefaults(AddonDoktorDB, DEFAULTS)
    ApplyDefaults(AddonDoktorCharDB, CHAR_DEFAULTS)
    ns.db = AddonDoktorDB
    ns.charDB = AddonDoktorCharDB
    frame:UnregisterEvent("ADDON_LOADED")
end

function events:PLAYER_LOGIN()
    -- Erste Diagnose kurz nach dem Login, damit andere Addons fertig geladen sind
    ns.UI.CreateMinimapButton()
    ns.UI.RegisterSettings()
    if not ns.db.scanOnLogin then return end
    C_Timer.After(5, function()
        local result = ns.RunDiagnosis()
        if ns.db.loginHint and #result.issues > 0 then
            ns.Print(L["LOGIN_HINT"]:format(result.grade, #result.issues))
        end
    end)
end

-- Situationswechsel -> evtl. Profil-Hinweis zeigen
local function SituationChanged() ns.Profiles.ScheduleCheck() end
events.PLAYER_ENTERING_WORLD = SituationChanged
events.ZONE_CHANGED_NEW_AREA = SituationChanged
events.PLAYER_UPDATE_RESTING = SituationChanged
events.PLAYER_REGEN_ENABLED = SituationChanged

frame:SetScript("OnEvent", function(self, event, ...)
    local handler = events[event]
    if handler then handler(self, ...) end
end)
for event in pairs(events) do
    frame:RegisterEvent(event)
end

-- Komplette Diagnose: Scannen, Messen, Regeln anwenden
function ns.RunDiagnosis()
    ns.Scanner.Scan()
    ns.Profiler.UpdateCPU()
    ns.lastResult = ns.Rules.Evaluate()
    if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
    return ns.lastResult
end

-- Kurzbericht im Chat (zum Kopieren für Fehlermeldungen)
local function PrintReport()
    local result = ns.RunDiagnosis()
    ns.Print(L["GRADE"] .. ": " .. result.grade .. " (" .. result.score .. "/100) · v" .. ns.version .. " · DB " .. ns.DataVersion)
    if #result.issues == 0 then
        ns.Print(L["NO_ISSUES"])
        return
    end
    for i, issue in ipairs(result.issues) do
        ns.Print(i .. ". " .. issue.text)
    end
end

SLASH_ADDONDOKTOR1 = "/doktor"
SLASH_ADDONDOKTOR2 = "/addondoktor"
SlashCmdList["ADDONDOKTOR"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    if msg == "" then
        ns.UI.Toggle()
    elseif msg == "scan" then
        ns.RunDiagnosis()
        ns.UI.Show()
    elseif msg == "bericht" or msg == "report" then
        PrintReport()
    else
        ns.Print(L["HELP"])
    end
end

-- Aufruf aus dem Addon-Fach (Retail-Minimap-Menü), siehe .toc
function AddonDoktor_OnCompartmentClick()
    ns.UI.Toggle()
end
