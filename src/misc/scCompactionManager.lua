----------------------------------------------------------------------------------------------------
-- (SOIL) COMPACTION MANAGER SCRIPT
----------------------------------------------------------------------------------------------------
-- Purpose:  To add soil compaction
-- Authors:  baron, reallogger, Wopster
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
    { 0.6172, 0.0510, 0.0510, 1 },
    { 0.6400, 0.1710, 0.1710, 1 },
    { 0.6672, 0.3333, 0.3333, 1 },
}

scCompactionManager.overlayColor[true] = {
    { 1.0000, 0.8632, 0.0232, 1 },
    { 0.6400, 0.1710, 0.1710, 1 },
    { 0.6672, 0.3333, 0.3333, 1 },
}

local toInsert = {
    ["soilCompaction"] = {
        requires = {},
        needsOne = {},
        notWith = {}
    },
    ["atWorkshop"] = {
        requires = {},
        needsOne = {},
        notWith = {}
    },
    ["tirePressure"] = {
        requires = {},
        needsOne = { Motorized, Trailer, HookLiftTrailer, LivestockTrailer, ManureBarrel, FuelTrailer },
        notWith = { HookLiftContainer }
    }, -- Todo: Motorized vs Drivable?
    ["deepCultivator"] = {
        requires = { Cultivator },
        needsOne = {},
        notWith = {}
    },
}

local function allowInsert(specialization, specializations)
    return SpecializationUtil.hasSpecialization(specialization, specializations)
end

local function noopFunction() end

local function strategyInsert(specializations)
    for name, i in pairs(toInsert) do
        local doInsert = true

        -- All these specs are required.
        for _, specialization in pairs(i.requires) do
            doInsert = allowInsert(specialization, specializations)
            if not doInsert then break end
        end

        -- Needs atleast one of these specs.
        if doInsert then
            doInsert = not #i.needsOne ~= 0

            for _, specialization in pairs(i.needsOne) do
                doInsert = allowInsert(specialization, specializations)

                if doInsert then
                    for _, specialization in pairs(i.notWith) do
                        local hasInvalidCombination = allowInsert(specialization, specializations)

                        if hasInvalidCombination then
                            doInsert = not doInsert
                            break
                        end
                    end

                    break
                end
            end
        end

        if doInsert then
            local class = SpecializationUtil.getSpecialization(name)

            for _, method in pairs({ "load", "delete", "mouseEvent", "keyEvent", "update", "draw" }) do
                if class[method] == nil then
                    class[method] = noopFunction
                end
            end

            table.insert(specializations, SpecializationUtil.getSpecialization(name))
        end
    end
end

function scCompactionManager:preLoadSoilCompaction()
    if g_soilCompaction ~= nil then
        error("Soil compaction is loaded already!")
    end

    -- Load in superglobal scope, so other mods can talk with us
    getfenv(0)["g_soilCompaction"] = self

    self.modDir = scCompactionManager.modDir

    self.debug = false --<%=debug %>

    InGameMenu.generateFruitOverlay = Utils.overwrittenFunction(InGameMenu.generateFruitOverlay, scCompactionManager.inGameMenuGenerateFruitOverlay)

    scUtils.overwrittenStaticFunction(Utils, "cutFruitArea", scCompactionManager.cutFruitArea)
    scUtils.overwrittenStaticFunction(Utils, "updateCultivatorArea", scCompactionManager.updateCultivatorArea)
end

function scCompactionManager:installVehicleSpecializations()
    for _, vehicleType in pairs(VehicleTypeUtil.vehicleTypes) do
        if vehicleType ~= nil then
            strategyInsert(vehicleType.specializations)
        end
    end
end

function scCompactionManager:loadMap()
    self:installVehicleSpecializations()

    if g_addCheatCommands then
        addConsoleCommand("scToggleInCabTirePressureControl", "Toggles incab tire pressure control", "consoleCommandToggleInCapControl", scTirePressure)
    end
end

function scCompactionManager:deleteMap()
    getfenv(0)["g_soilCompaction"] = nil

    if g_addCheatCommands then
        removeConsoleCommand("scToggleInCabTirePressureControl")
    end
end

function scCompactionManager:update(dt)
end

function scCompactionManager:draw()
end

-- Cutting fruit no longer increases the ploughcounter: only driving over an area does.
function scCompactionManager.cutFruitArea(superFunc, fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)
    local tmpNumChannels = g_currentMission.ploughCounterNumChannels

    -- Setting to 0 makes the use of it affect nothing
    g_currentMission.ploughCounterNumChannels = 0

    local volume, area, sprayFactor, _, growthState, growthStateArea = superFunc(fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, ...)

    g_currentMission.ploughCounterNumChannels = tmpNumChannels

    -- Depending on compaction yield is determined
    local detailId = g_currentMission.terrainDetailId
    local x0, z0, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(detailId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    local densityC, areaC, _ = getDensityParallelogram(detailId, x0, z0, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels)
    local compactionLayers = densityC / areaC
    local ploughFactor = 2 * compactionLayers - 5

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
    local detailId = g_currentMission.terrainDetailId
    local compactFirstChannel = g_currentMission.ploughCounterFirstChannel
    local compactNumChannels = g_currentMission.ploughCounterNumChannels
    local x0, z0, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(detailId, x, z, x1, z1, x2, z2)

    -- Apply decompaction delta where ground is field but not yet cultivated
    setDensityMaskParams(detailId, "greater", g_currentMission.cultivatorValue)
    setDensityCompareParams(detailId, "greater", 0)

    addDensityMaskedParallelogram(detailId,
        x0, z0, widthX, widthZ, heightX, heightZ,
        compactFirstChannel, compactNumChannels,
        detailId,
        g_currentMission.terrainDetailTypeFirstChannel, g_currentMission.terrainDetailTypeNumChannels,
        Utils.getNoNil(delta, scCompactionManager.cultivatorDecompactionDelta))

    setDensityMaskParams(detailId, "greater", 0)
    setDensityCompareParams(detailId, "greater", -1)

    return superFunc(x, z, x1, z1, x2, z2, forced, commonForced, angle, delta)
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
                setFoliageStateOverlayGroundStateColor(self.foliageStateOverlay, g_currentMission.terrainDetailId, bitShiftLeft(bitShiftLeft(1, g_currentMission.terrainDetailTypeNumChannels) - 1, g_currentMission.terrainDetailTypeFirstChannel), g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels, level - 1, color[1], color[2], color[3])
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