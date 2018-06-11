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
-- @param numOfRationParts
--
local function mapNumOfRotationPartsToTrackType(numOfRationParts)
    if numOfRationParts < 5 then
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
    self.getTireMaxLoad = scSoilCompaction.getTireMaxLoad
end

function scSoilCompaction:load(savegame)
    self.isAllowedToCompactSoil = not SpecializationUtil.hasSpecialization(Cultivator, self.specializations)

    self.scNumWheels = #self.wheels

    for _, wheel in pairs(self.wheels) do
        wheel.scOrgRadius = wheel.radius
        wheel.scWidth = wheel.width

        if wheel.additionalWheels ~= nil then
            self.scNumWheels = self.scNumWheels + #wheel.additionalWheels

            for _, additionalWheel in pairs(wheel.additionalWheels) do
                wheel.scWidth = wheel.scWidth + additionalWheel.width
            end
        end
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

function scSoilCompaction:mouseEvent(...)
end

function scSoilCompaction:keyEvent(...)
end

local function getTrackTypeContactAreaLength(crawler, radius)
    return crawler.scrollLength * _trackTypesLenghtFactors[crawler.trackType] - math.pi * radius
end

local function getPossibleCompaction(soilBulkDensityRef)
    for state, compaction in pairs(_compactionStates) do
        if soilBulkDensityRef > compaction
                and (state == scSoilCompaction.HEAVY_COMPACTION_LEVEL or soilBulkDensityRef <= compactionStates[math.max(state - 1, 0)]) then
            return state
        end
    end

    return scSoilCompaction.NO_COMPACTION_LEVEL
end

function scSoilCompaction:calculateSoilCompaction(wheel)
    local soilWater = g_currentMission.environment.groundWetness
    local width = wheel.scWidth
    local radius = wheel.scOrgRadius
    local length = math.max(0.1, 0.35 * radius)

    wheel.load = getWheelShapeContactForce(wheel.node, wheel.wheelShape)
    -- TODO: Increase load when MR is not loaded as vanilla tractors are too light

    -- Todo: calculate on post load?
    if wheel.load == nil then
        wheel.load = (self:getTotalMass(false) / self.scNumWheels + wheel.mass) * 9.81
    end

    local inflationPressure = 180
    if self.getInflationPressure then
        inflationPressure = self:getInflationPressure()
    end

    if wheel.scMaxLoad == nil then
        wheel.scMaxDeformation = Utils.getNoNil(wheel.maxDeformation, 0)
        wheel.scMaxLoad = self:getTireMaxLoad(wheel, inflationPressure)
    end

    wheel.contactArea = 0.38 * wheel.load ^ 0.7 * math.sqrt(width / (radius * 2)) / inflationPressure ^ 0.45

    local tireTypeCrawler = WheelsUtil.getTireType("crawler")

    if wheel.tireType == tireTypeCrawler then
        local numOfCrawlers = #self.crawlers

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
                length = getTrackTypeContactAreaLength(crawler, radius)
                break
            end
        end

        wheel.contactArea = length * width
    end

    -- TODO: No need to store groundPressure, but for display
    local oldPressure = Utils.getNoNil(wheel.groundPressure, wheel.load / wheel.contactArea)
    wheel.groundPressure = oldPressure * 99 / 100 + wheel.load / wheel.contactArea / 100
    if wheel.contactArea == 0 then
        wheel.groundPressure = oldPressure
    end

    -- soil saturation index 0.2
    -- c index Cp 0.7
    -- reference pressure 100 kPa
    -- reference saturation Sk 50%
    local soilBulkDensityRef = 0.2 * (soilWater - 0.5) + 0.7 * math.log10(wheel.groundPressure / 100)

    wheel.possibleCompaction = getPossibleCompaction(soilBulkDensityRef)

    --below only for debug print. TODO: remove when done
    wheel.soilBulkDensity = soilBulkDensityRef
end


function scSoilCompaction:applySoilCompaction()
    for _, wheel in pairs(self.wheels) do
        if wheel.hasGroundContact and not wheel.mrNotAWheel and wheel.isSynchronized then
            local x0, y0, z0
            local x1, y1, z1
            local x2, y2, z2

            local width = wheel.width
            wheel.scAdditionalWheelOffset = 0
            if wheel.additionalWheels ~= nil then
                for _, additionalWheel in pairs(wheel.additionalWheels) do
                    width = width + additionalWheel.width
                    wheel.scAdditionalWheelOffset = wheel.scAdditionalWheelOffset + additionalWheel.width
                end
            end

            local radius = wheel.scOrgRadius

            local length = math.max(0.1, 0.35 * radius)
            --local contactArea = length * width
            local penetrationResistance = 4e5 / (20 + (g_currentMission.environment.groundWetness * 100 + 5) ^ 2)

            self:calculateSoilCompaction(wheel)

            local wheelRot = getWheelShapeAxleSpeed(wheel.node, wheel.wheelShape)
            local wheelRotDir

            if wheelRot ~= 0 then
                wheelRotDir = wheelRot / math.abs(wheelRot)
            else
                wheelRotDir = 1
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

            -- Todo: lookup usage of this
            local soilWater = g_currentMission.environment.groundWetness
            local soilBulkDensityRef = 0.2 * (soilWater - 0.5) + 0.7 * math.log10(wheel.groundPressure / 100)

            local wantedC = 3
            if wheel.underTireCompaction == 3 and soilBulkDensityRef > scSoilCompaction.LIGHT_COMPACTION then
                wantedC = 2

            elseif wheel.underTireCompaction == 2 and wheel.fwdTireCompaction == 2
                    and soilBulkDensityRef > scSoilCompaction.MEDIUM_COMPACTION and soilBulkDensityRef <= scSoilCompaction.HEAVY_COMPACTION then
                wantedC = 1

            elseif wheel.underTireCompaction == 1 and wheel.fwdTireCompaction == 1 and soilBulkDensityRef > scSoilCompaction.HEAVY_COMPACTION then
                wantedC = 0
            end

            if wantedC ~= 3 then
                setDensityParallelogram(g_currentMission.terrainDetailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels, wantedC)
            end

            -- for debug
            -- penetrationResistance = 0

            if wheel.groundPressure > penetrationResistance and self:getLastSpeed() > 0 and self.isEntered then
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

function scSoilCompaction:getTireMaxLoad(wheel, inflationPressure)
    local tireLoadIndex = 981 * wheel.scMaxDeformation + 73
    local inflationFac = 0.56 + 0.002 * inflationPressure

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
