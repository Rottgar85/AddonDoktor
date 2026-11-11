-- Eigener Minimap-Knopf ohne Libraries: Linksklick öffnet, Rechtsklick prüft neu, Ziehen verschiebt
local addonName, ns = ...
local L = ns.L
local UI = ns.UI

local button
local RADIUS = 105

local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle or 215)
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end

local function OnDragUpdate()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    ns.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
    UpdatePosition()
end

function UI.CreateMinimapButton()
    if button then return end
    button = CreateFrame("Button", "AddonDoktorMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Bandage_15")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    button:SetScript("OnClick", function(_, mouse)
        if mouse == "RightButton" then
            local result = ns.RunDiagnosis()
            ns.Print(L["GRADE"] .. ": " .. result.grade .. " – " .. L["SUMMARY"]:format(result.loadedCount, #result.issues))
        else
            UI.Toggle()
        end
    end)
    button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
    button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(L["TITLE"], 1, 1, 1)
        if ns.lastResult then
            GameTooltip:AddLine(L["GRADE"] .. ": " .. ns.lastResult.grade, 0.4, 0.8, 1)
        end
        GameTooltip:AddLine(L["MINIMAP_TT_LEFT"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["MINIMAP_TT_RIGHT"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["MINIMAP_TT_DRAG"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)

    UpdatePosition()
    UI.UpdateMinimapButton()
end

function UI.UpdateMinimapButton()
    if not button then return end
    button:SetShown(not ns.db.minimap.hide)
end
