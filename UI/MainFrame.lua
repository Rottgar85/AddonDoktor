-- Hauptfenster: komplett per Maus bedienbar, keine Chat-Befehle nötig.
-- Tabs: Übersicht (Note + Tipps mit Knöpfen) · Addons (an/aus per Kästchen) · Einstellungen
local addonName, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local WIDTH, HEIGHT = 600, 500
local ROW_HEIGHT = 20
local MAX_ROWS = 17
local MAX_CARDS = 5

local GRADE_COLORS = {
    A = { 0.3, 0.9, 0.3 }, B = { 0.6, 0.9, 0.3 }, C = { 1, 0.85, 0.2 },
    D = { 1, 0.6, 0.2 },   E = { 1, 0.4, 0.2 },   F = { 1, 0.2, 0.2 },
}
local KIND_COLORS = {
    loaderror = { 1, 0.25, 0.25 }, duplicate = { 1, 0.6, 0.2 }, duplicate_auto = { 1, 0.75, 0.3 }, cpu = { 1, 0.6, 0.2 },
    outdated = { 1, 0.85, 0.2 }, builtin = { 0.4, 0.75, 1 }, toomany = { 0.4, 0.75, 1 },
}

local frame, tabs, panels = nil, {}, {}
local cards, rows = {}, {}
local sortKey, sortDesc = "cpu", true
local scrollOffset = 0

------------------------------------------------------------------------
-- Vorgemerkte Änderungen (wirken erst nach dem Neuladen)
------------------------------------------------------------------------
ns.pending = {}   -- [Ordnername] = gewünschter Zustand (true = an, false = aus)

local function FindEntry(name)
    for _, entry in ipairs(ns.Scanner.addons) do
        if entry.name == name then return entry end
    end
end

local function IsProtected(name)
    return name == addonName or C_AddOns.GetAddOnMetadata(name, "GuardedAddOn") ~= nil
end
ns.IsProtected = IsProtected

-- Braucht ein anderes aktives Addon dieses Addon? Dann nicht einzeln abschalten.
function ns.HasDependents(name)
    for _, entry in ipairs(ns.Scanner.addons) do
        local wanted = ns.pending[entry.name]
        if wanted == nil then wanted = entry.enabled end
        if wanted and entry.name ~= name then
            for _, dep in ipairs({ C_AddOns.GetAddOnDependencies(entry.name) }) do
                if dep == name then return true end
            end
        end
    end
    return false
end

function ns.SetAddonEnabled(name, enabled, silent)
    if IsProtected(name) then return end
    local player = UnitName("player")
    if enabled then C_AddOns.EnableAddOn(name, player) else C_AddOns.DisableAddOn(name, player) end
    local entry = FindEntry(name)
    -- Zurück auf den Ausgangszustand = keine offene Änderung mehr
    if entry and entry.enabled == enabled then ns.pending[name] = nil else ns.pending[name] = enabled end
    if not silent then UI.Refresh() end
end

function ns.UndoPending()
    for name, enabled in pairs(ns.pending) do
        local player = UnitName("player")
        if enabled then C_AddOns.DisableAddOn(name, player) else C_AddOns.EnableAddOn(name, player) end
    end
    wipe(ns.pending)
    UI.Refresh()
end

local function PendingCount()
    local n = 0
    for _ in pairs(ns.pending) do n = n + 1 end
    return n
end

------------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------------
-- Stil: dunkel, flach, Akzentfarbe aus dem Logo (Türkis)
local LOGO = "Interface\\AddOns\\AddonDoktor\\Media\\Logo128"
local C = {
    bg      = { 0.05, 0.08, 0.12, 0.97 },
    header  = { 0.07, 0.11, 0.16, 1 },
    panel   = { 0.09, 0.13, 0.18, 0.95 },
    border  = { 0.16, 0.22, 0.29, 1 },
    accent  = { 0.12, 0.82, 0.68, 1 },
    button  = { 0.12, 0.17, 0.23, 1 },
    hover   = { 0.16, 0.24, 0.31, 1 },
}
UI.COLORS, UI.LOGO = C, LOGO

-- Hintergrund + 1-Pixel-Rahmen ohne Vorlagen (läuft in jeder Client-Version)
local function Skin(f, bg, border)
    f.bg = rawget(f, "bg") or f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(unpack(bg or C.panel))
    local b = border or C.border
    local edges = {
        { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
        { "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil },
    }
    f.edges = rawget(f, "edges") or {}
    for i, e in ipairs(edges) do
        local t = f.edges[i] or f:CreateTexture(nil, "BORDER")
        t:ClearAllPoints()
        t:SetPoint(e[1]); t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
        t:SetColorTexture(unpack(b))
        f.edges[i] = t
    end
    return f
end
UI.Skin = Skin

local function NewPanel(parent)
    return Skin(CreateFrame("Frame", nil, parent))
end

local function MakeButton(parent, text, width, accent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 100, 22)
    Skin(button, accent and { C.accent[1] * 0.55, C.accent[2] * 0.55, C.accent[3] * 0.55, 1 } or C.button,
        accent and C.accent or C.border)
    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    button:SetFontString(fs)
    button.label = fs
    button:SetText(text)
    button:SetScript("OnEnter", function(self)
        if self:IsEnabled() and not self.active then self.bg:SetColorTexture(unpack(C.hover)) end
    end)
    button:SetScript("OnLeave", function(self)
        if not self.active then
            self.bg:SetColorTexture(unpack(accent and { C.accent[1] * 0.55, C.accent[2] * 0.55, C.accent[3] * 0.55, 1 } or C.button))
        end
    end)
    button:SetScript("OnDisable", function(self) fs:SetTextColor(0.45, 0.5, 0.55) end)
    button:SetScript("OnEnable", function(self) fs:SetTextColor(1, 1, 1) end)
    return button
end

local function StatusText(entry)
    if IsProtected(entry.name) then return "|cff888888" .. L["PROTECTED"] .. "|r" end
    if entry.loadError then return "|cffff4444" .. L["STATUS_ERROR"] .. "|r" end
    if entry.enabled and entry.outdated then return "|cffffaa33" .. L["STATUS_OUTDATED"] .. "|r" end
    if entry.loaded then return "|cff66ff66" .. L["STATUS_LOADED"] .. "|r" end
    if entry.enabled and entry.loadOnDemand then return "|cffaaaaaa" .. L["STATUS_LOD"] .. "|r" end
    return "|cff888888" .. L["STATUS_DISABLED"] .. "|r"
end

local function FormatMemory(kb)
    if not kb then return "–" end
    if kb >= 1024 then return ("%.1f MB"):format(kb / 1024) end
    return ("%d KB"):format(kb)
end

------------------------------------------------------------------------
-- Grundfenster mit Tabs und Neulade-Leiste
------------------------------------------------------------------------
local function CreateMainFrame()
    frame = CreateFrame("Frame", "AddonDoktorFrame", UIParent)
    Skin(frame, C.bg, C.border)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()
    tinsert(UISpecialFrames, "AddonDoktorFrame") -- mit ESC schließbar

    -- Kopfzeile mit Logo, Titel und Schließen-Knopf
    local header = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(40)
    header:SetColorTexture(unpack(C.header))
    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT"); line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT"); line:SetHeight(2)
    line:SetColorTexture(unpack(C.accent))
    frame.logo = frame:CreateTexture(nil, "ARTWORK")
    frame.logo:SetTexture(LOGO)
    frame.logo:SetSize(30, 30)
    frame.logo:SetPoint("LEFT", header, "LEFT", 8, 0)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("LEFT", frame.logo, "RIGHT", 8, 0)
    frame.title:SetText("|cffffffff" .. L["TITLE"] .. "|r  |cff1fd1adv" .. ns.version .. "|r")
    local close = MakeButton(frame, "×", 24)
    close:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    close.label:SetFontObject("GameFontNormalLarge")
    close:SetScript("OnClick", function() frame:Hide() end)

    local tabNames = { { "overview", L["TAB_OVERVIEW"] }, { "addons", L["TAB_ADDONS"] }, { "profiles", L["TAB_PROFILES"] }, { "settings", L["TAB_SETTINGS"] } }
    for i, info in ipairs(tabNames) do
        local tab = MakeButton(frame, info[2], 104)
        tab:SetHeight(26)
        tab:SetPoint("TOPLEFT", 12 + (i - 1) * 108, -52)
        tab.underline = tab:CreateTexture(nil, "OVERLAY")
        tab.underline:SetPoint("BOTTOMLEFT", 1, 1); tab.underline:SetPoint("BOTTOMRIGHT", -1, 1); tab.underline:SetHeight(2)
        tab.underline:SetColorTexture(unpack(C.accent))
        tab:SetScript("OnClick", function() UI.ShowTab(info[1]) end)
        tabs[info[1]] = tab
    end

    local rescan = MakeButton(frame, L["RESCAN"], 100, true)
    rescan:SetHeight(26)
    rescan:SetPoint("TOPRIGHT", -12, -52)
    rescan:SetScript("OnClick", function() ns.RunDiagnosis() end)

    -- Neulade-Leiste unten, nur sichtbar bei offenen Änderungen
    local bar = NewPanel(frame)
    bar:SetPoint("BOTTOMLEFT", 8, 8)
    bar:SetPoint("BOTTOMRIGHT", -8, 8)
    bar:SetHeight(34)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.text:SetPoint("LEFT", 10, 0)
    bar.reload = MakeButton(bar, L["BTN_RELOAD"], 130, true)
    bar.reload:SetPoint("RIGHT", -6, 0)
    bar.reload:SetScript("OnClick", function()
        if InCombatLockdown() then ns.Print(L["IN_COMBAT"]) return end
        C_UI.Reload() -- erlaubt, weil durch Mausklick ausgelöst
    end)
    bar.undo = MakeButton(bar, L["BTN_UNDO"], 100)
    bar.undo:SetPoint("RIGHT", bar.reload, "LEFT", -4, 0)
    bar.undo:SetScript("OnClick", ns.UndoPending)
    frame.reloadBar = bar

    for _, key in ipairs({ "overview", "addons", "profiles", "settings" }) do
        local panel = CreateFrame("Frame", nil, frame)
        panel:SetPoint("TOPLEFT", 12, -88)
        panel:SetPoint("BOTTOMRIGHT", -12, 48)
        panels[key] = panel
    end
end

------------------------------------------------------------------------
-- Tab 1: Übersicht – Note und Tipp-Karten mit Knöpfen
------------------------------------------------------------------------
local function CreateOverview()
    local p = panels.overview
    p.grade = p:CreateFontString(nil, "OVERLAY", ns.Font("GameFont_Gigantic", "GameFontNormalHuge"))
    p.grade:SetPoint("TOPLEFT", 8, -4)
    p.score = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    p.score:SetPoint("TOPLEFT", p.grade, "TOPRIGHT", 16, -6)
    p.summary = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    p.summary:SetPoint("TOPLEFT", p.score, "BOTTOMLEFT", 0, -4)
    p.header = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    p.header:SetPoint("TOPLEFT", 8, -66)
    p.header:SetText(L["TOP_TIPS"])
    p.empty = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    p.empty:SetPoint("TOPLEFT", p.header, "BOTTOMLEFT", 0, -12)
    p.empty:SetText(L["NO_ISSUES"])
    p.note = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    p.note:SetPoint("BOTTOMLEFT", 8, 0)

    for i = 1, MAX_CARDS do
        local card = NewPanel(p)
        card:SetSize(WIDTH - 36, 52)
        card:SetPoint("TOPLEFT", 4, -90 - (i - 1) * 56)
        card.stripe = card:CreateTexture(nil, "ARTWORK")
        card.stripe:SetPoint("TOPLEFT", 1, -1)
        card.stripe:SetPoint("BOTTOMLEFT", 1, 1)
        card.stripe:SetWidth(4)
        card.text = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        card.text:SetPoint("LEFT", 14, 0)
        card.text:SetWidth(WIDTH - 260)
        card.text:SetJustifyH("LEFT")
        card.ignore = MakeButton(card, L["BTN_IGNORE"], 90)
        card.ignore:SetPoint("RIGHT", -6, 0)
        card.disable = MakeButton(card, L["BTN_DISABLE"], 100)
        card.disable:SetPoint("RIGHT", card.ignore, "LEFT", -4, 0)
        cards[i] = card
    end
end

local function RefreshOverview()
    local p, result = panels.overview, ns.lastResult
    if not result then return end
    local color = GRADE_COLORS[result.grade] or GRADE_COLORS.F
    p.grade:SetText(result.grade)
    p.grade:SetTextColor(color[1], color[2], color[3])
    p.score:SetText(L["GRADE"] .. ": " .. result.score .. "/100")
    p.summary:SetText(L["SUMMARY"]:format(result.loadedCount, #result.issues))
    p.empty:SetShown(#result.issues == 0)
    p.note:SetText(ns.Profiler.IsAvailable() and "" or L["PROFILER_OFF"])

    for i, card in ipairs(cards) do
        local issue = result.issues[i]
        if issue then
            local c = KIND_COLORS[issue.kind] or KIND_COLORS.builtin
            card.stripe:SetColorTexture(c[1], c[2], c[3])
            card.text:SetText(issue.text)
            -- "Deaktivieren" nur, wenn ein Addon betroffen und noch nicht vorgemerkt ist
            local canDisable = issue.addon and not IsProtected(issue.addon) and ns.pending[issue.addon] ~= false
                and not ns.HasDependents(issue.addon)
            card.disable:SetShown(canDisable and true or false)
            card.disable:SetScript("OnClick", function() ns.SetAddonEnabled(issue.addon, false) end)
            card.ignore:SetShown(issue.ignoreKey ~= nil)
            card.ignore:SetScript("OnClick", function()
                ns.db.ignoredIssues[issue.ignoreKey] = true
                ns.RunDiagnosis()
            end)
            card:Show()
        else
            card:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Tab 2: Addons – Liste mit Kästchen zum An-/Ausschalten
------------------------------------------------------------------------
local function SortedAddons()
    local list = {}
    for _, entry in ipairs(ns.Scanner.addons) do list[#list + 1] = entry end
    table.sort(list, function(a, b)
        local va, vb
        if sortKey == "name" then va, vb = a.title:lower(), b.title:lower()
        elseif sortKey == "mem" then va, vb = a.memory or -1, b.memory or -1
        else va, vb = a.cpu or 0, b.cpu or 0 end
        if va == vb then return a.title:lower() < b.title:lower() end
        if sortDesc then return va > vb end
        return va < vb
    end)
    return list
end

local function CreateAddonsPanel()
    local p = panels.addons
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta)
        local maxOffset = math.max(0, #ns.Scanner.addons - MAX_ROWS)
        scrollOffset = math.min(maxOffset, math.max(0, scrollOffset - delta * 3))
        UI.Refresh()
    end)

    local memory = MakeButton(p, L["MEMORY_SCAN"], 130)
    memory:SetPoint("TOPRIGHT", 0, 2)
    memory:SetScript("OnClick", function()
        if ns.Profiler.UpdateMemory() then UI.Refresh() else ns.Print(L["IN_COMBAT"]) end
    end)

    local columns = {
        { key = "name", text = L["COL_NAME"],   x = 28,  width = 250 },
        { key = nil,    text = L["COL_STATUS"], x = 285, width = 100 },
        { key = "cpu",  text = L["COL_CPU"],    x = 390, width = 70 },
        { key = "mem",  text = L["COL_MEM"],    x = 465, width = 80 },
    }
    for _, col in ipairs(columns) do
        local header = CreateFrame("Button", nil, p)
        header:SetSize(col.width, ROW_HEIGHT)
        header:SetPoint("TOPLEFT", col.x, -26)
        local text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetAllPoints()
        text:SetJustifyH("LEFT")
        text:SetText(col.text)
        if col.key then
            header:SetScript("OnClick", function()
                if sortKey == col.key then sortDesc = not sortDesc
                else sortKey, sortDesc = col.key, col.key ~= "name" end
                UI.Refresh()
            end)
        end
    end

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Frame", nil, p)
        row:SetSize(WIDTH - 36, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -26 - i * ROW_HEIGHT)
        row:EnableMouse(true)
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.035 or 0)

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(20, 20)
        row.check:SetPoint("LEFT", 2, 0)

        row.cells = {}
        for c, col in ipairs(columns) do
            local cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell:SetPoint("LEFT", col.x, 0)
            cell:SetWidth(col.width)
            cell:SetJustifyH("LEFT")
            cell:SetWordWrap(false)
            row.cells[c] = cell
        end

        -- Tooltip mit Details
        row:SetScript("OnEnter", function(self)
            local entry = self.entry
            if not entry then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(entry.title, 1, 1, 1)
            local notes = C_AddOns.GetAddOnNotes and C_AddOns.GetAddOnNotes(entry.name)
            if notes and notes ~= "" then GameTooltip:AddLine(notes, nil, nil, nil, true) end
            if entry.loaded and ns.Profiler.totalCPU > 0 then
                GameTooltip:AddLine(L["CPU_SHARE"]:format(math.floor(ns.Profiler.Share(entry) + 0.5)), 0.6, 0.8, 1)
            end
            GameTooltip:AddLine(L["ROW_TT_ENABLE"], 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        rows[i] = row
    end
end

local function RefreshAddons()
    local list = SortedAddons()
    for i, row in ipairs(rows) do
        local entry = list[i + scrollOffset]
        row.entry = entry
        if entry then
            local wanted = ns.pending[entry.name]
            if wanted == nil then wanted = entry.enabled end
            row.check:SetChecked(wanted)
            row.check:SetEnabled(not IsProtected(entry.name))
            row.check:SetScript("OnClick", function(self) ns.SetAddonEnabled(entry.name, self:GetChecked()) end)
            local title = entry.title
            if ns.pending[entry.name] ~= nil then title = title .. " |cffffd100*|r" end
            row.cells[1]:SetText(title)
            row.cells[2]:SetText(StatusText(entry))
            row.cells[3]:SetText(entry.loaded and ("%.2f"):format(entry.cpu or 0) or "–")
            row.cells[4]:SetText(FormatMemory(entry.memory))
            row:Show()
        else
            row:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Tab 3: Profile – je Situation speichern, laden, nachfragen
------------------------------------------------------------------------
local profileRows = {}

local function CreateProfilesPanel()
    local p = panels.profiles
    p.help = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.help:SetPoint("TOPLEFT", 4, -2)
    p.help:SetWidth(WIDTH - 40)
    p.help:SetJustifyH("LEFT")
    p.help:SetText(L["PROFILES_HELP"])

    for i, situation in ipairs(ns.Profiles.SITUATIONS) do
        local row = NewPanel(p)
        row:SetSize(WIDTH - 36, 74)
        row:SetPoint("TOPLEFT", 0, -48 - (i - 1) * 80)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        row.name:SetPoint("TOPLEFT", 10, -8)
        row.name:SetText(L["SIT_" .. situation])
        row.info = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.info:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)

        row.save = MakeButton(row, L["PROFILE_SAVE"], 150)
        row.save:SetPoint("BOTTOMLEFT", 8, 8)
        row.save:SetScript("OnClick", function() ns.Profiles.SaveCurrent(situation); UI.Refresh() end)
        row.load = MakeButton(row, L["PROFILE_LOAD"], 110)
        row.load:SetPoint("LEFT", row.save, "RIGHT", 4, 0)
        row.load:SetScript("OnClick", function() ns.Profiles.Apply(situation) end)
        row.delete = MakeButton(row, L["PROFILE_DELETE"], 90)
        row.delete:SetPoint("LEFT", row.load, "RIGHT", 4, 0)
        row.delete:SetScript("OnClick", function() ns.Profiles.Delete(situation); UI.Refresh() end)

        row.ask = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.ask:SetSize(22, 22)
        row.ask:SetPoint("TOPRIGHT", -120, -6)
        row.ask.label = row.ask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.ask.label:SetPoint("LEFT", row.ask, "RIGHT", 2, 0)
        row.ask.label:SetText(L["PROFILE_ASK"])
        row.ask:SetScript("OnClick", function(self)
            local profile = ns.Profiles.Get(situation)
            if profile then profile.ask = self:GetChecked() end
        end)
        profileRows[situation] = row
    end
end

local function RefreshProfiles()
    local current = ns.Profiles.CurrentSituation()
    for situation, row in pairs(profileRows) do
        local profile = ns.Profiles.Get(situation)
        local label = L["SIT_" .. situation]
        if situation == current then label = label .. "  |cff66ff66(" .. L["PROFILE_HERE"] .. ")|r" end
        row.name:SetText(label)
        if profile then
            local n = 0
            for _ in pairs(profile.addons) do n = n + 1 end
            row.info:SetText(L["PROFILE_INFO"]:format(n))
        else
            row.info:SetText(L["PROFILE_EMPTY"])
        end
        row.load:SetShown(profile ~= nil)
        row.delete:SetShown(profile ~= nil)
        row.ask:SetShown(profile ~= nil)
        row.ask:SetChecked(profile and profile.ask or false)
    end
end

------------------------------------------------------------------------
-- Tab 4: Einstellungen
------------------------------------------------------------------------
local function MakeCheck(parent, label, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 4, y)
    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.label:SetText(label)
    check:SetScript("OnShow", function(self) self:SetChecked(getter()) end)
    check:SetScript("OnClick", function(self) setter(self:GetChecked()) end)
    return check
end

local function CreateSettingsPanel()
    local p = panels.settings
    MakeCheck(p, L["SET_MINIMAP"], -4,
        function() return not ns.db.minimap.hide end,
        function(on) ns.db.minimap.hide = not on; UI.UpdateMinimapButton() end)
    MakeCheck(p, L["SET_SCAN_LOGIN"], -34,
        function() return ns.db.scanOnLogin end,
        function(on) ns.db.scanOnLogin = on end)
    MakeCheck(p, L["SET_LOGIN_HINT"], -64,
        function() return ns.db.loginHint end,
        function(on) ns.db.loginHint = on end)
    MakeCheck(p, L["SET_PROFILE_PROMPTS"], -94,
        function() return ns.db.profilePrompts end,
        function(on) ns.db.profilePrompts = on end)
    local reset = MakeButton(p, L["SET_RESET_IGNORE"], 240)
    reset:SetPoint("TOPLEFT", 8, -136)
    reset:SetScript("OnClick", function()
        wipe(ns.db.ignoredIssues)
        ns.RunDiagnosis()
        UI.ShowTab("overview")
    end)
end

------------------------------------------------------------------------
-- Öffentliche Funktionen
------------------------------------------------------------------------
function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    if panels.overview:IsShown() then RefreshOverview() end
    if panels.addons:IsShown() then RefreshAddons() end
    if panels.profiles:IsShown() then RefreshProfiles() end
    local count = PendingCount()
    frame.reloadBar:SetShown(count > 0)
    frame.reloadBar.text:SetText(L["RELOAD_BAR"]:format(count))
end

function UI.ShowTab(name)
    for key, panel in pairs(panels) do panel:SetShown(key == name) end
    for key, tab in pairs(tabs) do
        tab.active = key == name
        tab.underline:SetShown(tab.active)
        tab.bg:SetColorTexture(unpack(tab.active and C.hover or C.button))
        tab.label:SetTextColor(tab.active and C.accent[1] or 0.8, tab.active and C.accent[2] or 0.85, tab.active and C.accent[3] or 0.9)
    end
    UI.Refresh()
end

local function EnsureFrame()
    if frame then return end
    CreateMainFrame()
    CreateOverview()
    CreateAddonsPanel()
    CreateProfilesPanel()
    CreateSettingsPanel()
    UI.ShowTab("overview")
end

function UI.Show()
    EnsureFrame()
    if not ns.lastResult then ns.RunDiagnosis() end
    frame:Show()
    UI.Refresh()
end

function UI.Toggle()
    EnsureFrame()
    if frame:IsShown() then frame:Hide() else UI.Show() end
end
