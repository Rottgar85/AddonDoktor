-- Regeln: aus Scan- und Messdaten werden verständliche Befunde und eine Note
local addonName, ns = ...
local L = ns.L

local Rules = {}
ns.Rules = Rules

local isGerman = GetLocale() == "deDE"
local CPU_HEAVY_SHARE = 35   -- ab diesem Anteil an der Addon-CPU gilt ein Addon als Fresser
local MIN_ADDONS_FOR_CPU = 4 -- bei sehr wenigen Addons ist ein hoher Anteil normal
local MANY_ADDONS = 40

-- Abzüge pro Befund (Note startet bei 100)
local PENALTY = { loaderror = 15, duplicate = 12, duplicate_auto = 6, outdated = 8, cpu = 10, builtin = 4, toomany = 6 }

local function Label(tbl)
    return isGerman and tbl.de or tbl.en
end

local function PairKey(a, b)
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

-- addon: Ordnername des betroffenen Addons (für den "Deaktivieren"-Knopf)
-- ignoreKey: Schlüssel, unter dem der Befund dauerhaft ausgeblendet werden kann
local function AddIssue(issues, kind, text, addon, ignoreKey)
    if ignoreKey and ns.db.ignoredIssues[ignoreKey] then return end
    issues[#issues + 1] = { kind = kind, text = text, penalty = PENALTY[kind] or 0, addon = addon, ignoreKey = ignoreKey }
end

function Rules.Evaluate()
    local issues = {}
    local loaded = ns.Scanner.GetLoaded()
    local byCategory = {}
    local relevantLoaded = 0

    for _, entry in ipairs(ns.Scanner.addons) do
        if not entry.ignored then
            -- Ladefehler (nur bei aktivierten Addons interessant)
            if entry.enabled and entry.loadError then
                AddIssue(issues, "loaderror", L["ISSUE_LOADERROR"]:format(entry.title, tostring(entry.reason or "?")), entry.name, "err:" .. entry.name)
            -- Veraltet, aber trotzdem aktiv
            elseif entry.enabled and entry.outdated then
                AddIssue(issues, "outdated", L["ISSUE_OUTDATED"]:format(entry.title, tostring(entry.interface or "?")), entry.name, "old:" .. entry.name)
            end
        end
    end

    for _, entry in ipairs(loaded) do
        if not entry.ignored then
            relevantLoaded = relevantLoaded + 1
            for _, key in ipairs(entry.categories) do
                byCategory[key] = byCategory[key] or {}
                table.insert(byCategory[key], entry)
            end
        end
    end

    -- Doppelte Funktionen und Nachbauten von eingebauten Funktionen
    for key, members in pairs(byCategory) do
        local category = ns.Categories[key]
        if category.exclusive and #members > 1 then
            for i = 1, #members - 1 do
                for j = i + 1, #members do
                    local a, b = members[i], members[j]
                    -- Vorschlag: das Addon mit mehr Rechenzeit deaktivieren
                    local heavier = (a.cpu or 0) >= (b.cpu or 0) and a or b
                    -- automatisch erkannt = unsicherer, daher weicherer Abzug
                    local kind = (a.autoCategory or b.autoCategory) and "duplicate_auto" or "duplicate"
                    AddIssue(issues, kind, L["ISSUE_DUPLICATE"]:format(a.title, b.title, Label(category)),
                        heavier.name, "dup:" .. PairKey(a.name, b.name))
                end
            end
        end
        if category.builtin and category.builtin.clients[ns.client] then
            for _, entry in ipairs(members) do
                AddIssue(issues, "builtin", L["ISSUE_BUILTIN"]:format(entry.title, Label(category.builtin)), entry.name, "builtin:" .. entry.name)
            end
        end
    end

    -- Leistungsfresser
    if ns.Profiler.totalCPU > 0 and relevantLoaded >= MIN_ADDONS_FOR_CPU then
        for _, entry in ipairs(loaded) do
            local share = ns.Profiler.Share(entry)
            if not entry.ignored and share >= CPU_HEAVY_SHARE then
                AddIssue(issues, "cpu", L["ISSUE_CPU_HEAVY"]:format(entry.title, math.floor(share + 0.5)), entry.name, "cpu:" .. entry.name)
            end
        end
    end

    if relevantLoaded >= MANY_ADDONS then
        AddIssue(issues, "toomany", L["ISSUE_TOO_MANY"]:format(relevantLoaded), nil, "toomany")
    end

    -- Wichtigste Befunde zuerst
    table.sort(issues, function(x, y) return x.penalty > y.penalty end)

    local score = 100
    for _, issue in ipairs(issues) do
        score = score - issue.penalty
    end
    score = math.max(0, score)

    return {
        issues = issues,
        score = score,
        grade = Rules.Grade(score),
        loadedCount = relevantLoaded,
    }
end

function Rules.Grade(score)
    if score >= 90 then return "A"
    elseif score >= 75 then return "B"
    elseif score >= 60 then return "C"
    elseif score >= 45 then return "D"
    elseif score >= 30 then return "E"
    end
    return "F"
end
