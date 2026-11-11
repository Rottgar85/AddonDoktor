-- Profiler: CPU über den eingebauten C_AddOnProfiler, Speicher nur auf Knopfdruck
local addonName, ns = ...

local Profiler = {}
ns.Profiler = Profiler
Profiler.totalCPU = 0

function Profiler.IsAvailable()
    return C_AddOnProfiler ~= nil
        and C_AddOnProfiler.IsEnabled ~= nil
        and C_AddOnProfiler.IsEnabled()
end

-- Welche Kennzahl wir lesen: Durchschnitt seit Login/Reload.
-- Name laut warcraft.wiki.gg; Fallback 0 = SessionAverageTime.
local function GetMetric()
    local enum = Enum and Enum.AddOnProfilerMetric
    return (enum and enum.SessionAverageTime) or 0
end

function Profiler.UpdateCPU()
    Profiler.totalCPU = 0
    if not Profiler.IsAvailable() then return false end
    local metric = GetMetric()

    for _, entry in ipairs(ns.Scanner.addons) do
        if entry.loaded then
            -- pcall: Abfrage eines unbekannten Addons soll nie einen Fehler werfen
            local ok, value = pcall(C_AddOnProfiler.GetAddOnMetric, entry.name, metric)
            entry.cpu = (ok and type(value) == "number") and value or 0
        else
            entry.cpu = 0
        end
    end

    local ok, overall = pcall(C_AddOnProfiler.GetOverallMetric, metric)
    if ok and type(overall) == "number" and overall > 0 then
        Profiler.totalCPU = overall
    else
        for _, entry in ipairs(ns.Scanner.addons) do
            Profiler.totalCPU = Profiler.totalCPU + entry.cpu
        end
    end
    return true
end

-- Speicher messen ist teuer -> nur manuell und nie im Kampf
function Profiler.UpdateMemory()
    if InCombatLockdown() then return false end
    UpdateAddOnMemoryUsage()
    for _, entry in ipairs(ns.Scanner.addons) do
        if entry.loaded then
            local ok, kb = pcall(GetAddOnMemoryUsage, entry.name)
            entry.memory = ok and kb or nil
        end
    end
    return true
end

-- Anteil eines Addons an der gesamten Addon-CPU in Prozent
function Profiler.Share(entry)
    if Profiler.totalCPU <= 0 then return 0 end
    return entry.cpu / Profiler.totalCPU * 100
end
