-- Eintrag im Blizzard-Menü (Esc > Optionen > AddOns), damit man den Doktor auch ohne Befehl findet
local addonName, ns = ...
local L = ns.L
local UI = ns.UI

function UI.RegisterSettings()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = L["TITLE"]

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L["TITLE"])

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    open:SetText(L["SET_OPEN"])
    open:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel) -- Optionsfenster schließen, damit der Doktor vorne ist
        UI.Show()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, L["TITLE"])
    Settings.RegisterAddOnCategory(category)
    -- Ältere Clients ohne neues Optionsmenü: Eintrag fehlt, Fenster bleibt über Minimap erreichbar
end
