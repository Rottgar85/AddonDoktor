-- Minimale Nachbildung der WoW-API, um das Addon außerhalb des Spiels laufen zu lassen.
-- Prüft: Laden aller Dateien, Events, Diagnose, Fenster, Knöpfe, Profile.
local LOCALE, CLIENT_TOC = arg[1] or "deDE", tonumber(arg[2] or "16001")

-- Lua 5.1-Kompatibilität
unpack = unpack or table.unpack
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
strlower, strtrim = string.lower, function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert = table.insert
math.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

local printed = {}
local realprint = print
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, " ") end

-- Fake-Addons: Name, Titel, Notes, geladen, an, Grund, Interface, Abhängigkeiten
ADDONS = {
  { "AddonDoktor", "Addon-Doktor", "", true, true, nil, 16001 },
  { "Questie", "Questie", "Quest helper", true, true, nil, 16001 },
  { "ForeverQuestPins", "Forever Quest Pins", "", true, true, nil, 16001 },
  { "Details", "Details! Damage Meter", "damage meter", true, true, nil, 16001 },
  { "Routewise", "Routewise", "Route planner for Azeroth", true, true, nil, 16001 },
  { "ForeverPath", "ForeverPath", "Fastest route to any destination", true, true, nil, 16001 },
  { "OldFrames", "OldFrames", "", false, true, "INTERFACE_VERSION", 11508 },
  { "BrokenThing", "BrokenThing", "", false, true, "DEP_MISSING", 16001, { "LibMissing" } },
  { "Leatrix_Plus", "|cff00ff00Leatrix|r Plus", "", true, true, nil, 16001 },
  { "LibFoo", "LibFoo", "", true, true, nil, 16001 },
  { "UsesLibFoo", "UsesLibFoo", "", true, true, nil, 16001, { "LibFoo" } },
  { "Disabled1", "Disabled1", "", false, false, nil, 16001 },
}
local enabled, byName = {}, {}
for i, a in ipairs(ADDONS) do byName[a[1]] = i; enabled[a[1]] = a[5] end
local function idx(x) return type(x) == "number" and x or byName[x] end

C_AddOns = {
  GetNumAddOns = function() return #ADDONS end,
  GetAddOnInfo = function(x) local a = ADDONS[idx(x)]; return a[1], a[2], a[3], a[6] == nil, a[6], "INSECURE" end,
  GetAddOnMetadata = function(x, k) local a = ADDONS[idx(x)]; if not a then return nil end
    if k == "Version" then return "0.9.4-beta" end; if k == "Notes" then return a[3] end; return nil end,
  GetAddOnNotes = function(x) return ADDONS[idx(x)][3] end,
  GetAddOnInterfaceVersion = function(x) return ADDONS[idx(x)][7] end,
  IsAddOnLoaded = function(x) local a = ADDONS[idx(x)]; return a[4], a[4] end,
  IsAddOnLoadOnDemand = function() return false end,
  GetAddOnEnableState = function(x) return enabled[ADDONS[idx(x)][1]] and 2 or 0 end,
  DoesAddOnHaveLoadError = function(x) return ADDONS[idx(x)][6] == "DEP_MISSING" end,
  GetAddOnDependencies = function(x) local a = ADDONS[idx(x)]; return unpack(a and a[8] or {}) end,
  DoesAddOnExist = function(x) return idx(x) ~= nil end,
  EnableAddOn = function(x) enabled[ADDONS[idx(x)][1]] = true end,
  DisableAddOn = function(x) enabled[ADDONS[idx(x)][1]] = false end,
}
Enum = { AddOnProfilerMetric = { SessionAverageTime = 0 } }
local cpu = { Questie = 3.8, ForeverQuestPins = 1.0, Details = 1.1, Routewise = 0.4, ForeverPath = 9.5, Leatrix_Plus = 0.1, AddonDoktor = 0.05, LibFoo = 0.02, UsesLibFoo = 0.1 }
C_AddOnProfiler = { IsEnabled = function() return true end,
  GetAddOnMetric = function(n) return cpu[n] or 0 end,
  GetOverallMetric = function() local s = 0 for _, v in pairs(cpu) do s = s + v end return s end }
UpdateAddOnMemoryUsage = function() end
GetAddOnMemoryUsage = function(n) return 1234 end
GetBuildInfo = function() return "1.60.1", "1", "Nov 2026", CLIENT_TOC end
GetLocale = function() return LOCALE end
UnitName = function() return "Rottgar" end
InCombatLockdown = function() return COMBAT == true end
IsInInstance = function() return INSTANCE or false, INSTANCE and "party" or "none" end
IsResting = function() return RESTING == true end
GetCursorPosition = function() return 100, 100 end
local timers = {}
C_Timer = { After = function(_, f) timers[#timers+1] = f end,
  NewTimer = function(_, f) timers[#timers+1] = f; return { Cancel = function() end } end }
local function RunTimers() local t = timers; timers = {}; for _, f in ipairs(t) do f() end end
RELOADS = 0
C_UI = { Reload = function() RELOADS = RELOADS + 1 end }
UISpecialFrames = {}
SlashCmdList = {}
GameTooltip_Hide = function() end
HideUIPanel = function() end
SettingsPanel = {}
local registered = {}
Settings = { RegisterCanvasLayoutCategory = function(p, n) return { name = n } end,
  RegisterAddOnCategory = function(c) registered[#registered+1] = c end }
GameFont_Gigantic = {}

-- Generisches Widget: merkt sich Skripte, Text, Sichtbarkeit; alle anderen Methoden tun nichts
local allFrames = {}
local Widget = {}
Widget.__index = function(t, k)
  local v = rawget(Widget, k); if v then return v end
  return function() end
end
function Widget:SetScript(n, f) self.scripts[n] = f end
function Widget:GetScript(n) return self.scripts[n] end
function Widget:RegisterEvent(e) self.events[e] = true end
function Widget:UnregisterEvent(e) self.events[e] = nil end
function Widget:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Widget:Hide() self.shown = false end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:IsShown() return self.shown end
function Widget:SetText(t) self.text = t end
function Widget:GetText() return self.text end
function Widget:SetChecked(v) self.checked = v and true or false end
function Widget:GetChecked() return self.checked end
function Widget:SetEnabled(v) self.enabled = v end
function Widget:GetCenter() return 0, 0 end
function Widget:GetEffectiveScale() return 1 end
function Widget:Click(button) if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end end
local function NewWidget(kind, name, parent, template)
  local w = setmetatable({ kind = kind, scripts = {}, events = {}, shown = true, parent = parent, children = {}, template = template }, Widget)
  if parent and parent.children then parent.children[#parent.children+1] = w; if parent.shown == false then end end
  w.CreateFontString = function(self) local fs = NewWidget("FontString", nil, self); return fs end
  w.CreateTexture = function(self) return NewWidget("Texture", nil, self) end
  if name then _G[name] = w end
  allFrames[#allFrames+1] = w
  return w
end
KNOWN_TEMPLATES = { BasicFrameTemplateWithInset = true, BasicFrameTemplate = true, InsetFrameTemplate3 = TEMPLATE3 ~= false,
  InsetFrameTemplate = true, UIPanelButtonTemplate = true, UICheckButtonTemplate = true }
function CreateFrame(kind, name, parent, template)
  if template and not KNOWN_TEMPLATES[template] then error("Unbekannte Vorlage: " .. template) end
  return NewWidget(kind, name, parent, template)
end
UIParent = NewWidget("Frame", "UIParent"); Minimap = NewWidget("Frame", "Minimap")
GameTooltip = NewWidget("GameTooltip", "GameTooltip")

-- Addon laden (Reihenfolge wie in der .toc)
local ns = {}
local function LoadToc()
  for line in io.lines("../AddonDoktor.toc") do
    line = line:gsub("\r", "")
    if line ~= "" and not line:match("^#") then
      local path = "../" .. line:gsub("\\", "/")
      local chunk = assert(loadfile(path))
      chunk("AddonDoktor", ns)
    end
  end
end

local function Fire(event, ...)
  for _, f in ipairs(allFrames) do
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

local function FindButton(root, text)
  local stack = { root }
  while #stack > 0 do
    local w = table.remove(stack)
    if w.kind == "Button" and w.text == text and w.shown ~= false then return w end
    for _, c in ipairs(w.children or {}) do stack[#stack+1] = c end
  end
end

local steps, fails = 0, 0
local function Step(name, fn)
  steps = steps + 1
  local ok, err = xpcall(fn, debug.traceback)
  if ok then realprint("  OK    " .. name) else fails = fails + 1; realprint("  FEHLER " .. name .. "\n" .. err) end
end
local function Check(cond, msg) if not cond then error(msg, 2) end end

realprint(("Test: Sprache %s, Client-Interface %d"):format(LOCALE, CLIENT_TOC))
Step("Alle Dateien laden", LoadToc)
Step("ADDON_LOADED (fremdes Addon wird ignoriert)", function() Fire("ADDON_LOADED", "Questie"); Check(ns.db == nil, "db zu früh gesetzt") end)
Step("ADDON_LOADED (eigenes Addon)", function() Fire("ADDON_LOADED", "AddonDoktor"); Check(ns.db and ns.db.minimap, "SavedVariables fehlen") end)
Step("PLAYER_LOGIN + Diagnose nach Timer", function() Fire("PLAYER_LOGIN"); Fire("PLAYER_ENTERING_WORLD"); RunTimers(); Check(ns.lastResult, "keine Diagnose") end)
Step("Diagnose-Ergebnis plausibel", function()
  local r = ns.lastResult
  local kinds = {}
  for _, i in ipairs(r.issues) do kinds[i.kind] = (kinds[i.kind] or 0) + 1; realprint("          [" .. i.kind .. "] " .. i.text) end
  realprint(("          Note %s (%d/100), %d Addons geladen"):format(r.grade, r.score, r.loadedCount))
  Check(kinds.loaderror == 1, "Ladefehler nicht erkannt")
  Check((kinds.outdated or 0) >= 1, "veraltetes Addon nicht erkannt")
  Check((kinds.duplicate or 0) >= 1, "Quest-Helfer-Duplikat nicht erkannt")
  Check((kinds.duplicate_auto or 0) >= 1, "Reiseplaner-Duplikat (automatisch) nicht erkannt")
  if (CLIENT_TOC >= 16000 and CLIENT_TOC < 17000) or CLIENT_TOC >= 100000 then Check(kinds.builtin == 1, "eingebauter Damage-Meter nicht gemeldet")
  else Check(kinds.builtin == nil, "eingebauter Damage-Meter fälschlich gemeldet") end
  Check(kinds.cpu == 1, "Leistungsfresser nicht erkannt")
  for _, i in ipairs(r.issues) do Check(not i.text:find("Addon%-Doktor") and not i.text:find("^LibFoo "), "eigenes Addon/Bibliothek gemeldet") end
end)
Step("Login-Hinweis im Chat", function() local found = false for _, p in ipairs(printed) do if p:find("Note") or p:find("grade") then found = true end end Check(found, "kein Hinweis") end)
Step("Slash-Befehle", function() SlashCmdList.ADDONDOKTOR("bericht"); SlashCmdList.ADDONDOKTOR("report"); SlashCmdList.ADDONDOKTOR("hilfe"); SlashCmdList.ADDONDOKTOR("") end)
local frame
Step("Fenster öffnet über /doktor", function() frame = _G.AddonDoktorFrame; Check(frame and frame.shown, "Fenster nicht sichtbar") end)
Step("Tab-Wechsel", function()
  for _, t in ipairs({ ns.L["TAB_ADDONS"], ns.L["TAB_PROFILES"], ns.L["TAB_SETTINGS"], ns.L["TAB_OVERVIEW"] }) do
    local b = FindButton(frame, t); Check(b, "Tab fehlt: " .. t); b:Click()
  end
end)
Step("Karte 'Deaktivieren' -> Neulade-Leiste", function()
  local b = FindButton(frame, ns.L["BTN_DISABLE"]); Check(b, "kein Deaktivieren-Knopf"); b:Click()
  local n = 0 for _ in pairs(ns.pending) do n = n + 1 end
  Check(n == 1, "Änderung nicht vorgemerkt"); Check(frame.reloadBar.shown, "Neulade-Leiste nicht sichtbar")
end)
Step("Rückgängig", function() FindButton(frame, ns.L["BTN_UNDO"]):Click(); Check(next(ns.pending) == nil, "nicht zurückgesetzt") end)
Step("Bibliothek mit Abhängigen nicht abschaltbar", function() Check(ns.HasDependents("LibFoo"), "Abhängigkeit nicht erkannt") end)
Step("Ignorieren blendet Tipp aus", function()
  local before = #ns.lastResult.issues
  FindButton(frame, ns.L["BTN_IGNORE"]):Click()
  Check(#ns.lastResult.issues == before - 1, "Tipp nicht ausgeblendet")
end)
Step("Addons-Tab: Kästchen, Sortierung, Speicher", function()
  FindButton(frame, ns.L["TAB_ADDONS"]):Click()
  FindButton(frame, ns.L["MEMORY_SCAN"]):Click()
  for _, w in ipairs(allFrames) do if w.kind == "Button" and w.text == ns.L["COL_NAME"] then w:Click() end end
  for _, w in ipairs(allFrames) do local par = rawget(w, "parent"); local e = type(par) == "table" and rawget(par, "entry"); if w.kind == "CheckButton" and type(e) == "table" and e.name == "Disabled1" then w.checked = true; w:Click() end end
  Check(ns.pending.Disabled1 == true, "Kästchen setzt keine Änderung")
  for _, w in ipairs(allFrames) do if w.scripts.OnEnter and type(rawget(w, "entry")) == "table" then w.scripts.OnEnter(w); break end end
  ns.UndoPending()
end)
Step("Neuladen im Kampf gesperrt", function()
  ns.SetAddonEnabled("Questie", false); COMBAT = true
  FindButton(frame, ns.L["BTN_RELOAD"]):Click(); Check(RELOADS == 0, "Reload im Kampf ausgelöst")
  COMBAT = false; FindButton(frame, ns.L["BTN_RELOAD"]):Click(); Check(RELOADS == 1, "Reload ausserhalb des Kampfs fehlt")
  ns.UndoPending()
end)
Step("Profil speichern (Stadt) + Hinweis beim Betreten", function()
  RESTING = true
  FindButton(frame, ns.L["TAB_PROFILES"]):Click()
  ns.SetAddonEnabled("Details", false, true)
  ns.Profiles.SaveCurrent("city"); ns.UndoPending()
  Check(ns.db.profiles.city and not ns.db.profiles.city.addons.Details, "Profil falsch gespeichert")
  Fire("PLAYER_UPDATE_RESTING"); RunTimers()
  local p = _G.AddonDoktorPrompt; Check(p and p.shown, "Profil-Hinweis erscheint nicht")
  FindButton(p, ns.L["PROMPT_LOAD"]):Click()
  Check(RELOADS == 2, "Profil laden löst keinen Reload aus")
  Check(ns.pending.Details == false, "Profil nicht angewendet")
  Check(ns.pending.LibFoo == nil, "Bibliothek fälschlich abgeschaltet")
end)
Step("Minimap-Knopf", function()
  local b = _G.AddonDoktorMinimapButton; Check(b, "kein Minimap-Knopf")
  b.scripts.OnClick(b, "RightButton"); b.scripts.OnClick(b, "LeftButton"); b.scripts.OnEnter(b)
  b.scripts.OnDragStart(b); if b.scripts.OnUpdate then b.scripts.OnUpdate(b) end; b.scripts.OnDragStop(b)
end)
Step("Einstellungen-Eintrag registriert", function() Check(#registered == 1, "kein Eintrag im Optionsmenü") end)
Step("Addon-Fach", function() AddonDoktor_OnCompartmentClick() end)
Step("Keine unerwarteten globalen Variablen", function()
  local allowed = { AddonDoktorDB = 1, AddonDoktorCharDB = 1, SLASH_ADDONDOKTOR1 = 1, SLASH_ADDONDOKTOR2 = 1,
    AddonDoktor_OnCompartmentClick = 1, AddonDoktorFrame = 1, AddonDoktorPrompt = 1, AddonDoktorMinimapButton = 1 }
  for k in pairs(_G) do if type(k) == "string" and k:find("^AddonDoktor") or k == "L" or k == "ns" then Check(allowed[k], "globale Variable: " .. k) end end
end)
realprint(("Ergebnis: %d/%d Schritte bestanden"):format(steps - fails, steps))
os.exit(fails == 0 and 0 or 1)
