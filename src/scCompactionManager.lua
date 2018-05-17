----------------------------------------------------------------------------------------------------
-- (SOIL) COMPACTION MANAGER SCRIPT
----------------------------------------------------------------------------------------------------
-- Purpose:  To add soil compaction
-- Authors:  baron, reallogger
--
-- Copyright (c) Realismus Modding, 2017
----------------------------------------------------------------------------------------------------

scCompactionManager = {}

--scCompactionManager.superFunc = {} -- To store function pointers in Utils that we intend to overwrite
scCompactionManager.cultivatorDecompactionDelta = 1 -- Cultivators additive effect on the compaction layer

local modItem = ModsUtil.findModItemByModName(g_currentModName)
scCompactionManager.modDir = g_currentModDirectory

scCompactionManager.overlayColor = {} -- Additional colors for the compaction overlay (false/true: useColorblindMode)
scCompactionManager.overlayColor[false] = {
    {0.6172, 0.0510, 0.0510, 1},
    {0.6400, 0.1710, 0.1710, 1},
    {0.6672, 0.3333, 0.3333, 1},
}

scCompactionManager.overlayColor[true] = {
    {0.6172, 0.0510, 0.0510, 1},
    {0.6400, 0.1710, 0.1710, 1},
    {0.6672, 0.3333, 0.3333, 1},
}

function scCompactionManager:installVehicleSpecializations()
    for _, vehicleType in pairs(VehicleTypeUtil.vehicleTypes) do
        if vehicleType ~= nil then
            table.insert(vehicleType.specializations, SpecializationUtil.getSpecialization("soilCompaction"))
            table.insert(vehicleType.specializations, SpecializationUtil.getSpecialization("atWorkshop"))

            if SpecializationUtil.hasSpecialization(Motorized, vehicleType.specializations) then
                table.insert(vehicleType.specializations, SpecializationUtil.getSpecialization("tirePressure"))
            end

            if SpecializationUtil.hasSpecialization(Cultivator, vehicleType.specializations) then
                table.insert(vehicleType.specializations, SpecializationUtil.getSpecialization("deepCultivator"))
            end
        end
    end
end

function scCompactionManager:load(savegame, key)
end

function scCompactionManager:save(savegame, key)
end

function scCompactionManager:loadMap()
    self:installVehicleSpecializations()
end

function scCompactionManager:mouseEvent(posX, posY, isDown, isUp, button)
end

function scCompactionManager:keyEvent(unicode, sym, modifier, isDown)
end

function scCompactionManager:readStream(streamId, connection)
end

function scCompactionManager:writeStream(streamId, connection)
end

function scCompactionManager:update(dt)
end

function scCompactionManager:draw()
end

function scCompactionManager:deleteMap()
end

-- Cutting fruit no longer increases the ploughcounter: only driving over an area does.
function scCompactionManager.cutFruitArea(superFunc, fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
    --if not scCompactionManager.enabled then
     --   return superFunc(fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
    --end
    local tmpNumChannels = g_currentMission.ploughCounterNumChannels

    -- Setting to 0 makes the use of it affect nothing
    g_currentMission.ploughCounterNumChannels = 0

    local volume, area, sprayFactor, ploughFactor, growthState, growthStateArea = superFunc(fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)

    g_currentMission.ploughCounterNumChannels = tmpNumChannels

    -- Depending on compaction yield is determined
    local x0, z0, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(detailId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    local densityC, areaC, _ = getDensityParallelogram(g_currentMission.terrainDetailId, x0, z0, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels)
    local compactionLayers = densityC / areaC

    ploughFactor = 2 * compactionLayers - 5

    -- Special rules for grass
    if fruitId == FruitUtil.FRUITTYPE_GRASS then
      local sprayRatio = g_currentMission.harvestSprayScaleRatio
      local ploughRatio = g_currentMission.harvestPloughScaleRatio

      ploughFactor = (1 + ploughFactor * ploughRatio + sprayFactor * sprayRatio) / (1 + ploughRatio + sprayFactor * sprayRatio)
      volume = volume * ploughFactor
    end

    return volume, area, sprayFactor, ploughFactor, growthState, growthStateArea
end

-- When running a cultivator, decompact a bit as well.
-- The plough already decompacts in vanilla. Using a cultivator now allows being more effective.
function scCompactionManager.updateCultivatorArea(superFunc, x, z, x1, z1, x2, z2, forced, commonForced, angle, delta)
    local realArea, area = superFunc(x, z, x1, z1, x2, z2, forced, commonForced, angle)

    local detailId = g_currentMission.terrainDetailId
    local compactFirstChannel = g_currentMission.ploughCounterFirstChannel
    local compactNumChannels = g_currentMission.ploughCounterNumChannels
    local x0, z0, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(detailId, x, z, x1, z1, x2, z2)

    -- Apply decompaction delta where ground is field but not yet cultivated
    setDensityMaskParams(detailId, "greater", g_currentMission.cultivatorValue)
    setDensityCompareParams(detailId, "greater", 0)

    addDensityMaskedParallelogram(
        detailId,
        x0, z0, widthX, widthZ, heightX, heightZ,
       compactFirstChannel, compactNumChannels,
       detailId,
        g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels,
        Utils.getNoNil(delta, scCompactionManager.cultivatorDecompactionDelta)
    )

    setDensityMaskParams(detailId, "greater", 0)
    setDensityCompareParams(detailId, "greater", -1)

    return realArea, area
end

-- Draw all the different states of compaction in overlay menu
function scCompactionManager:inGameMenuGenerateFruitOverlay(superFunc)
    -- If ploughing overlay is selected we override everything being drawn
    if self.mapNeedsPlowing and self.mapSelectorMapping[self.mapOverviewSelector:getState()] == InGameMenu.MAP_SOIL then
        if g_currentMission ~= nil and g_currentMission.terrainDetailId ~= 0 then

            -- Begin draw foliage state overlay
            resetFoliageStateOverlay(self.foliageStateOverlay)

            local colors = scCompactionManager.overlayColor[g_gameSettings:getValue("useColorblindMode")]
            local maxCompaction = bitShiftLeft(1, g_currentMission.ploughCounterNumChannels) - 1
            for level = 1, maxCompaction do
                local color = colors[math.min(level, #colors)]
                setFoliageStateOverlayGroundStateColor(self.foliageStateOverlay, g_currentMission.terrainDetailId, bitShiftLeft(bitShiftLeft(1, g_currentMission.terrainDetailTypeNumChannels)-1, g_currentMission.terrainDetailTypeFirstChannel), g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels, level-1, color[1], color[2], color[3])
            end

            -- End draw foliage state overlay
            generateFoliageStateOverlay(self.foliageStateOverlay)
            self.foliageStateOverlayIsReady = false
            self.dynamicMapImageLoading:setVisible(true)
            self:checkFoliageStateOverlayReady()
        end
    -- Else if ploughing is not selected use vanilla functionality
    else
        superFunc(self)
    end
end

function logInfo(...)
    local str = "[Soil Compaction]"
    for i = 1, select("#", ...) do
        str = str .. " " .. tostring(select(i, ...))
    end
    print(str)
end

function print_r(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    pos = tostring(pos)
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end
    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
    print()
end

function mathRound(value, idp)
    local mult = 10 ^ (idp or 0)
    return math.floor(value * mult + 0.5) / mult
end

SpecializationUtil.registerSpecialization("deepCultivator", "scDeepCultivator", scCompactionManager.modDir .. "src/scDeepCultivator.lua")
SpecializationUtil.registerSpecialization("soilCompaction", "scSoilCompaction", scCompactionManager.modDir .. "src/scSoilCompaction.lua")
SpecializationUtil.registerSpecialization("tirePressure", "scTirePressure", scCompactionManager.modDir .. "src/scTirePressure.lua")
SpecializationUtil.registerSpecialization("atWorkshop", "scAtWorkshop", scCompactionManager.modDir .. "src/scAtWorkshop.lua")

InGameMenu.generateFruitOverlay = Utils.overwrittenFunction(InGameMenu.generateFruitOverlay, scCompactionManager.inGameMenuGenerateFruitOverlay)
Utils.cutFruitArea = Utils.overwrittenFunction(Utils.cutFruitArea, scCompactionManager.cutFruitArea)
Utils.updateCultivatorArea = Utils.overwrittenFunction(Utils.updateCultivatorArea, scCompactionManager.updateCultivatorArea)

addModEventListener(scCompactionManager)