-- Situations-Profile: welche Addons in der Stadt, unterwegs oder im Dungeon laufen sollen.
-- Addons lassen sich nicht im laufenden Spiel entladen: ein Profil wird vorgemerkt
-- und wirkt nach einem Neuladen, das der Spieler selbst per Klick auslöst.
local addonName, ns = ...
local L = ns.L

local Profiles = {}
ns.Profiles = Profiles

-- Feste Situationen, Reihenfolge = Anzeige im Menü
Profiles.SITUATIONS = { "city", "world", "dungeon" }

-- Aktuelle Situation bestimmen
function Profiles.CurrentSituation()
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        return "dungeon"
    end
    if IsResting() then -- Hauptstadt oder Gasthaus
        return "city"
    end
    return "world"
end

function Profiles.Get(situation)
    return ns.db.profiles[situation]
end

-- Aktuelle An/Aus-Auswahl (inkl. vorgemerkter Änderungen) als Profil speichern
function Profiles.SaveCurrent(situation)
    local set = {}
    for _, entry in ipairs(ns.Scanner.addons) do
        local wanted = ns.pending[entry.name]
        if wanted == nil then wanted = entry.enabled end
        if wanted then set[entry.name] = true end
    end
    ns.db.profiles[situation] = { addons = set, ask = true }
end

function Profiles.Delete(situation)
    ns.db.profiles[situation] = nil
end

-- Abhängigkeiten der gewünschten Addons ebenfalls anlassen, sonst brechen sie
local function CollectNeeded(set)
    local needed = {}
    local function Add(name)
        if needed[name] then return end
        needed[name] = true
        for _, dep in ipairs({ C_AddOns.GetAddOnDependencies(name) }) do
            if C_AddOns.DoesAddOnExist(dep) then Add(dep) end
        end
    end
    for name in pairs(set) do
        if C_AddOns.DoesAddOnExist(name) then Add(name) end
    end
    needed[addonName] = true -- uns selbst nie abschalten
    return needed
end

-- Weicht der aktuelle Zustand vom Profil ab?
function Profiles.Differs(situation)
    local profile = Profiles.Get(situation)
    if not profile then return false end
    local needed = CollectNeeded(profile.addons)
    for _, entry in ipairs(ns.Scanner.addons) do
        if not ns.IsProtected(entry.name) and (needed[entry.name] or false) ~= entry.enabled then
            return true
        end
    end
    return false
end

-- Profil vormerken (Neuladen nötig)
function Profiles.Apply(situation)
    local profile = Profiles.Get(situation)
    if not profile then return false end
    local needed = CollectNeeded(profile.addons)
    for _, entry in ipairs(ns.Scanner.addons) do
        if not ns.IsProtected(entry.name) then
            ns.SetAddonEnabled(entry.name, needed[entry.name] or false, true)
        end
    end
    ns.charDB.activeProfile = situation
    ns.UI.Refresh()
    return true
end

------------------------------------------------------------------------
-- Hinweis beim Betreten einer neuen Situation
------------------------------------------------------------------------
local prompt
local askedThisSession = {} -- pro Situation höchstens einmal je Sitzung fragen

local function CreatePrompt()
    prompt = ns.CreateFrameSafe("Frame", "AddonDoktorPrompt", UIParent, "BasicFrameTemplate", nil)
    prompt:SetSize(360, 110)
    prompt:SetPoint("TOP", 0, -140)
    prompt:SetFrameStrata("DIALOG")
    prompt:Hide()
    prompt.title = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    prompt.title:SetPoint("TOP", 0, -5)
    prompt.title:SetText(L["TITLE"])
    prompt.text = prompt:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    prompt.text:SetPoint("TOP", 0, -32)
    prompt.text:SetWidth(330)

    local function MakeButton(text, x, onClick)
        local b = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
        b:SetSize(108, 22)
        b:SetPoint("BOTTOM", x, 12)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end
    MakeButton(L["PROMPT_LOAD"], -112, function()
        prompt:Hide()
        if InCombatLockdown() then ns.Print(L["IN_COMBAT"]) return end
        Profiles.Apply(prompt.situation)
        C_UI.Reload() -- durch Klick ausgelöst, daher erlaubt
    end)
    MakeButton(L["PROMPT_LATER"], 0, function() prompt:Hide() end)
    MakeButton(L["PROMPT_NEVER"], 112, function()
        local profile = Profiles.Get(prompt.situation)
        if profile then profile.ask = false end
        prompt:Hide()
    end)
end

function Profiles.CheckSituation()
    if not ns.db.profilePrompts or InCombatLockdown() then return end
    if #ns.Scanner.addons == 0 then ns.Scanner.Scan() end
    local situation = Profiles.CurrentSituation()
    local profile = Profiles.Get(situation)
    if not profile or not profile.ask or askedThisSession[situation] then return end
    if not Profiles.Differs(situation) then return end
    askedThisSession[situation] = true
    if not prompt then CreatePrompt() end
    prompt.situation = situation
    prompt.text:SetText(L["PROMPT_TEXT"]:format(L["SIT_" .. situation]))
    prompt:Show()
end

-- Wechsel erst nach kurzer Pause prüfen (Ladebildschirme, Zonenwechsel)
local pendingCheck
function Profiles.ScheduleCheck()
    if pendingCheck then pendingCheck:Cancel() end
    pendingCheck = C_Timer.NewTimer(3, function()
        pendingCheck = nil
        Profiles.CheckSituation()
    end)
end
