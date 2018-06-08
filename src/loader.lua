----------------------------------------------------------------------------------------------------
-- Loader
----------------------------------------------------------------------------------------------------
-- Purpose:  Loads the mod.
-- Authors:  Wopster
--
-- Copyright (c) Realismus Modding, 2018
----------------------------------------------------------------------------------------------------

local srcDirectory = g_currentModDirectory .. "src"

---
-- Compatibility: Lua-5.1
-- http://lua-users.org/wiki/SplitJoin
--
local function split(str, pat)
    local t = {} -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)

    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e + 1
        s, e, cap = str:find(fpat, last_end)
    end

    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end

    return t
end

-- Variables controlled by the farmsim tool
local debugRendering = false --<%=debug %>
local isNoRestart = false --<%=norestart %>

-- Source files
local files = {
    -- main
    ('%s/misc/%s'):format(srcDirectory, 'scCompactionManager'),
    -- placeables
    ('%s/placeables/%s'):format(srcDirectory, 'scAirCompressorPlaceable'),
}

-- Insert class name to preload
local classes = {}

for _, directory in pairs(files) do
    local splittedPath = split(directory, "[\\/]+")
    table.insert(classes, splittedPath[#splittedPath])

    source(directory .. ".lua")
end

---
--
local function loadSoilCompaction()
    for i, _ in pairs(files) do
        local class = classes[i]

        if _G[class] ~= nil and _G[class].preLoadSoilCompaction ~= nil then
            _G[class]:preLoadSoilCompaction()
        end
    end
end

---
--
local function loadMapFinished()
    local requiredMethods = { "deleteMap", "mouseEvent", "keyEvent", "draw", "update" }
    local function noopFunction() end

    -- Before loading the savegame, allow classes to set their default values
    -- and let the settings system know that they need values
    for _, k in pairs(classes) do
        if _G[k] ~= nil and _G[k].loadMap ~= nil then
            -- Set any missing functions with dummies. This is because it makes code in classes cleaner
            for _, method in pairs(requiredMethods) do
                if _G[k][method] == nil then
                    _G[k][method] = noopFunction
                end
            end

            addModEventListener(_G[k])
        end
    end
end

-- Vehicle specializations
local specializations = {
    ["deepCultivator"] = ('%s/vehicles/'):format(srcDirectory),
    ["soilCompaction"] = ('%s/vehicles/'):format(srcDirectory),
    ["tirePressure"] = ('%s/vehicles/'):format(srcDirectory),
    ["atWorkshop"] = ('%s/vehicles/'):format(srcDirectory)
}

---
-- @param str
--
local function mapToScClassname(str)
    return "sc" .. (str:gsub("^%l", string.upper))
end

for name, directory in pairs(specializations) do
    if SpecializationUtil.specializations[name] == nil then
        local classname = mapToScClassname(name)
        SpecializationUtil.registerSpecialization(name, classname, directory .. classname .. ".lua")
    end
end

-- Hook on early load
Mission00.load = Utils.prependedFunction(Mission00.load, loadSoilCompaction)

FSBaseMission.loadMapFinished = Utils.prependedFunction(FSBaseMission.loadMapFinished, loadMapFinished)