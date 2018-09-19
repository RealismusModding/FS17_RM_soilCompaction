----------------------------------------------------------------------------------------------------
-- SOIL COMPACTION SPECIALIZATION
----------------------------------------------------------------------------------------------------
-- Author:  Rahkiin, reallogger, Wopster
--
-- Copyright (c) Realismus Modding, 2018
----------------------------------------------------------------------------------------------------

scSoilCompaction = {}

scSoilCompaction.HEAVY_COMPACTION_LEVEL = 0
scSoilCompaction.MEDIUM_COMPACTION_LEVEL = 1
scSoilCompaction.LIGHT_COMPACTION_LEVEL = 2
scSoilCompaction.NO_COMPACTION_LEVEL = 3

scSoilCompaction.LIGHT_COMPACTION = -0.15
scSoilCompaction.MEDIUM_COMPACTION = 0.05
scSoilCompaction.HEAVY_COMPACTION = 0.2

scSoilCompaction.WORST_COMPACTION_LEVEL = 4

local _compactionStates = {
    [scSoilCompaction.LIGHT_COMPACTION_LEVEL] = scSoilCompaction.LIGHT_COMPACTION,
    [scSoilCompaction.MEDIUM_COMPACTION_LEVEL] = scSoilCompaction.MEDIUM_COMPACTION,
    [scSoilCompaction.HEAVY_COMPACTION_LEVEL] = scSoilCompaction.HEAVY_COMPACTION,
}

-- Stijn: we have to make an assumption here.. no way to do this clean anyway with the current setup from Giants.
-- If rotationParts are lower than 5 we are dealing with a parallel track
scSoilCompaction.TRACK_PARALLEL = "parallel"
scSoilCompaction.TRACK_TRIANGULAR = "triangular"

local _trackTypesLenghtFactors = {
    [scSoilCompaction.TRACK_PARALLEL] = 0.3,
    [scSoilCompaction.TRACK_TRIANGULAR] = 0.5
}

---
-- @param numOfRotationParts
--
local function mapNumOfRotationPartsToTrackType(numOfRotationParts)
    if numOfRotationParts < 5 then
        return scSoilCompaction.TRACK_PARALLEL
    end

    return scSoilCompaction.TRACK_TRIANGULAR
end

function scSoilCompaction:prerequisitesPresent(specializations)
    return true
end

function scSoilCompaction:preLoad(savegame)
    self.applySoilCompaction = scSoilCompaction.applySoilCompaction
    self.calculateSoilCompaction = scSoilCompaction.calculateSoilCompaction
    self.getCompactionLayers = scSoilCompaction.getCompactionLayers
    self.getCrawlerContactLength = scSoilCompaction.getCrawlerContactLength
    self.getTireContactLength = scSoilCompaction.getTireContactLength
end

function scSoilCompaction:load(savegame)
    self.isAllowedToCompactSoil = not SpecializationUtil.hasSpecialization(Cultivator, self.specializations)

    self.scNumWheels = #self.wheels

    for _, wheel in pairs(self.wheels) do
        wheel.scOrgRadius = wheel.radius
        wheel.scWidth = wheel.width
        wheel.scAdditionalWheelOffset = 0

        if wheel.additionalWheels ~= nil then
            self.scNumWheels = self.scNumWheels + #wheel.additionalWheels

            for _, additionalWheel in pairs(wheel.additionalWheels) do
                wheel.scWidth = wheel.scWidth + additionalWheel.width
                wheel.scAdditionalWheelOffset = wheel.scAdditionalWheelOffset + additionalWheel.width
            end
        end

        local inflationPressure = scTirePressure.PRESSURE_NORMAL
        if self.getInflationPressure ~= nil then
            inflationPressure = self:getInflationPressure()
        end

        wheel.scMaxDeformation = Utils.getNoNil(wheel.maxDeformation, 0)
        wheel.scMaxLoad = scSoilCompaction.getTireMaxLoad(wheel, inflationPressure, self.mrIsMrVehicle)
    end
end

function scSoilCompaction:postLoad(savegame)
    if self.crawlers ~= nil then
        for _, crawler in pairs(self.crawlers) do
            crawler.trackType = mapNumOfRotationPartsToTrackType(#crawler.rotatingParts)
        end
    end
end

function scSoilCompaction:delete()
end

local function getTrackTypeContactAreaLength(crawler, radius)
    return crawler.scrollLength * _trackTypesLenghtFactors[crawler.trackType] - math.pi * radius * 0.4
end

local function getPossibleCompaction(soilBulkDensityRef)
    for state, compaction in pairs(_compactionStates) do
        if soilBulkDensityRef > compaction
                and (state == scSoilCompaction.HEAVY_COMPACTION_LEVEL or soilBulkDensityRef <= _compactionStates[math.max(state - 1, 0)]) then
            return state
        end
    end

    return scSoilCompaction.NO_COMPACTION_LEVEL
end

local function getWantedCompaction(soilBulkDensityRef, underTireCompaction, fwdTireCompaction)
    for state, compaction in pairs(_compactionStates) do
        if soilBulkDensityRef > compaction then
            local nextState = math.max(state + 1, scSoilCompaction.NO_COMPACTION_LEVEL)
            local hasValidDensityLayers = underTireCompaction == nextState
                    and (fwdTireCompaction == nextState or nextState == scSoilCompaction.LIGHT_COMPACTION)
            local hasValidSoilBulk = (state == scSoilCompaction.HEAVY_COMPACTION_LEVEL
                    or state == scSoilCompaction.LIGHT_COMPACTION
                    or soilBulkDensityRef <= _compactionStates[math.max(state - 1, 0)])

            if hasValidDensityLayers and hasValidSoilBulk then
                return state
            end
        end
    end

    return scSoilCompaction.NO_COMPACTION_LEVEL
end

local function calculateSoilBulkDensityRef(groundPressure)
    local soilWater = g_currentMission.environment.groundWetness
    -- soil saturation index 0.2
    -- c index Cp 0.7
    -- reference pressure 100 kPa
    -- reference saturation Sk 50%
    return 0.2 * (soilWater - 0.5) + 0.7 * math.log10(groundPressure / 100)
end

local function calculatePenetrationResistance()
    local soilWater = g_currentMission.environment.groundWetness
    return 4e5 / (20 + (soilWater * 100 + 5) ^ 2)
end

function scSoilCompaction:getTireContactLength(radius)
    return math.max(0.1, 0.35 * radius)
end

function scSoilCompaction:getCrawlerContactLength(wheel)
    local numOfCrawlers = #self.crawlers
    local radius = wheel.scOrgRadius

    for crawlerIndex = 0, numOfCrawlers - 1 do
        local crawler = self.crawlers[crawlerIndex + 1]
        local foundMatch = crawler.speedRefWheel ~= nil and crawler.speedRefWheel.node == wheel.node

        if not foundMatch and wheel.hasTireTracks then
            local wheelIndex = wheel.xmlIndex
            if wheelIndex >= numOfCrawlers then
                wheelIndex = math.min(crawlerIndex, wheel.xmlIndex)
            end

            foundMatch = crawlerIndex == wheelIndex
        end

        if foundMatch then
            return getTrackTypeContactAreaLength(crawler, radius)
        end
    end

    return self:getTireContactLength(radius)
end

function scSoilCompaction:calculateSoilCompaction(wheel)
    if not wheel.hasGroundContact then
        return
    end

    local width = wheel.scWidth
    local radius = wheel.scOrgRadius
    local length = self:getTireContactLength(radius)

    if self.isServer then
        wheel.load = getWheelShapeContactForce(wheel.node, wheel.wheelShape)
    end

    -- Todo: calculate on post load?
    if wheel.load == nil then
        wheel.load = (self:getTotalMass(false) / self.scNumWheels + wheel.mass) * 9.81
    end

    local inflationPressure = scTirePressure.PRESSURE_NORMAL
    if self.getInflationPressure ~= nil then
        inflationPressure = self:getInflationPressure()
    end

    wheel.contactArea = 0.38 * wheel.load ^ 0.7 * math.sqrt(width / (radius * 2)) / inflationPressure ^ 0.45

    local tireTypeCrawler = WheelsUtil.getTireType("crawler")
    if wheel.tireType == tireTypeCrawler and wheel.tireTrackAtlasIndex > 0 then
        length = self:getCrawlerContactLength(wheel)

        wheel.contactArea = length * width
    end

    local oldPressure = Utils.getNoNil(wheel.groundPressure, wheel.load / wheel.contactArea)
    wheel.groundPressure = oldPressure * 99 / 100 + wheel.load / wheel.contactArea / 100
    if wheel.contactArea == 0 then
        wheel.groundPressure = oldPressure
    end

    local soilBulkDensityRef = calculateSoilBulkDensityRef(wheel.groundPressure)
    wheel.possibleCompaction = getPossibleCompaction(soilBulkDensityRef)

    -- Below only for debug print.
    if g_soilCompaction.debug then
        wheel.soilBulkDensity = soilBulkDensityRef
    end
end

function scSoilCompaction:applySoilCompaction()
    local tireTypeCrawler = WheelsUtil.getTireType("crawler")
    for _, wheel in pairs(self.wheels) do
        if wheel.hasGroundContact
                and (wheel.isSynchronized or (wheel.tireType == tireTypeCrawler and wheel.tireTrackAtlasIndex > 0))
                and not wheel.mrNotAWheel then
            local width = wheel.scWidth
            local radius = wheel.scOrgRadius
            local length = math.max(0.1, 0.35 * radius)

            self:calculateSoilCompaction(wheel)

            local wheelRot = getWheelShapeAxleSpeed(wheel.node, wheel.wheelShape)
            local wheelRotDir = 1

            if wheelRot ~= 0 then
                wheelRotDir = wheelRot / math.abs(wheelRot)
            end

            local x0, z0, x1, z1, x2, z2, fwdLayers = self:getCompactionLayers(wheel, width, length, radius, radius * wheelRotDir * -1, 2 * radius * wheelRotDir)
            local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailHeightId, x0, z0, x1, z1, x2, z2)

            -- debug print
            if g_soilCompaction.debug then
                scDebugUtil.drawDensityParallelogram(x, z, widthX, widthZ, heightX, heightZ, 0.25, 255, 255, 0)
            end

            local x0, z0, x1, z1, x2, z2, underLayers = self:getCompactionLayers(wheel, width, length, radius, length, length)
            local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailHeightId, x0, z0, x1, z1, x2, z2)

            -- debug print
            if g_soilCompaction.debug then
                scDebugUtil.drawDensityParallelogram(x, z, widthX, widthZ, heightX, heightZ, 0.25, 255, 0, 0)
            end

            wheel.underTireCompaction = mathRound(underLayers, 0)
            wheel.fwdTireCompaction = mathRound(fwdLayers, 0)

            local soilBulkDensityRef = calculateSoilBulkDensityRef(wheel.groundPressure)
            local wantedCompaction = getWantedCompaction(soilBulkDensityRef, wheel.underTireCompaction, wheel.fwdTireCompaction)

            --planters do not compact soil if soil is already uncompacted 
            if SpecializationUtil.hasSpecialization(sowingMachine, self.specializations) 
                and wheel.fwdTireCompaction == scSoilCompaction.NO_COMPACTION_LEVEL 
                and wantedCompaction == scSoilCompaction.LIGHT_COMPACTION_LEVEL then
                    wantedCompaction = scSoilCompaction.NO_COMPACTION_LEVEL
            end

            if wantedCompaction ~= scSoilCompaction.NO_COMPACTION_LEVEL then
                setDensityParallelogram(g_currentMission.terrainDetailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels, wantedCompaction)
            end

            if wheel.groundPressure > calculatePenetrationResistance() and self:getLastSpeed() > 0 and self.isEntered then
                local dx, _, dz = localDirectionToWorld(self.rootNode, 0, 0, 1)
                local angle = Utils.convertToDensityMapAngle(Utils.getYRotationFromDirection(dx, dz), g_currentMission.terrainDetailAngleMaxValue)

                local x0, z0, x1, z1, x2, z2, underLayers = self:getCompactionLayers(wheel, math.max(0.1, width * 0.5 - 0.15), length, radius, length, length)
                local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailHeightId, x0, z0, x1, z1, x2, z2)

                local cm = g_currentMission
                setDensityMaskedParallelogram(cm.terrainDetailId, x, z, widthX, widthZ, heightX, heightZ, cm.terrainDetailTypeFirstChannel, cm.terrainDetailTypeNumChannels, cm.terrainDetailId, cm.terrainDetailTypeFirstChannel, cm.terrainDetailTypeNumChannels, cm.ploughValue)
                setDensityMaskedParallelogram(cm.terrainDetailId, x, z, widthX, widthZ, heightX, heightZ, cm.terrainDetailAngleFirstChannel, cm.terrainDetailAngleNumChannels, cm.terrainDetailId, cm.terrainDetailTypeFirstChannel, cm.terrainDetailTypeNumChannels, angle)
            end
        end
    end
end

function scSoilCompaction.getTireMaxLoad(wheel, inflationPressure, isMRVehicle)
    local tireLoadIndex = 981 * wheel.scMaxDeformation + 73
    local inflationFac = 0.03 * (30 * inflationPressure / 100 - 1)
    if isMRVehicle then
        inflationFac = 0.37 * (1 + 0.95 * inflationPressure / 100)
    end

    -- in kN
    return 44 * math.exp(0.0288 * tireLoadIndex) * inflationFac / 100
end

function scSoilCompaction:getCompactionLayers(wheel, width, length, radius, delta0, delta2)
    local x0, y0, z0
    local x1, y1, z1
    local x2, y2, z2

    local isLeft = wheel.isLeft and 1 or -1

    if wheel.repr == wheel.driveNode then
        x0, y0, z0 = localToWorld(wheel.node, wheel.positionX + width / 2 + wheel.scAdditionalWheelOffset * isLeft / 2, wheel.positionY, wheel.positionZ - delta0)
        x1, y1, z1 = localToWorld(wheel.node, wheel.positionX - width / 2 + wheel.scAdditionalWheelOffset * isLeft / 2, wheel.positionY, wheel.positionZ - delta0)
        x2, y2, z2 = localToWorld(wheel.node, wheel.positionX + width / 2 + wheel.scAdditionalWheelOffset * isLeft / 2, wheel.positionY, wheel.positionZ + delta2)
    else
        local x, _, z = localToLocal(wheel.driveNode, wheel.repr, 0, 0, 0)
        x0, y0, z0 = localToWorld(wheel.repr, x + width / 2 + wheel.scAdditionalWheelOffset * isLeft / 2, 0, z - delta0)
        x1, y1, z1 = localToWorld(wheel.repr, x - width / 2 + wheel.scAdditionalWheelOffset * isLeft / 2, 0, z - delta0)
        x2, y2, z2 = localToWorld(wheel.repr, x + width / 2 + wheel.scAdditionalWheelOffset * isLeft / 2, 0, z + delta2)
    end

    local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailId, x0, z0, x1, z1, x2, z2)

    local density, area, _ = getDensityParallelogram(g_currentMission.terrainDetailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels)
    local compactionLayers = density / area

    return x0, z0, x1, z1, x2, z2, compactionLayers
end

function scSoilCompaction:update(dt)
    if g_currentMission:getIsServer()
            and self.lastSpeedReal ~= 0
            and self.isAllowedToCompactSoil then

        local applySoilCompaction = true
        if g_seasons ~= nil then
            applySoilCompaction = not g_seasons.weather:isGroundFrozen()
        end

        if applySoilCompaction then
            self:applySoilCompaction()
        end
    end

    if g_currentMission:getIsClient()
            and self.wheels ~= nil
            and self:isPlayerInRange() then
        local worstCompaction = scSoilCompaction.WORST_COMPACTION_LEVEL

        for _, wheel in pairs(self.wheels) do
            -- fallback to 'no compaction'
            if wheel.possibleCompaction == nil and wheel.load == nil then
                self:calculateSoilCompaction(wheel)
            end

            worstCompaction = math.min(worstCompaction, Utils.getNoNil(wheel.possibleCompaction, scSoilCompaction.WORST_COMPACTION_LEVEL))
        end

        if worstCompaction < scSoilCompaction.WORST_COMPACTION_LEVEL then
            local storeItem = StoreItemsUtil.storeItemsByXMLFilename[self.configFileName:lower()]
            local compactionText = g_i18n:getText(("COMPACTION_%d"):format(worstCompaction)):format(storeItem.name)

            g_currentMission:addExtraPrintText(compactionText)
        end
    end
end

function scSoilCompaction:draw()
end
