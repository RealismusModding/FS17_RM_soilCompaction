----------------------------------------------------------------------------------------------------
-- SOIL COMPACTION SPECIALIZATION
----------------------------------------------------------------------------------------------------
-- Author:  Rahkiin, reallogger
--
-- Copyright (c) Realismus Modding, 2018
----------------------------------------------------------------------------------------------------

scSoilCompaction = {}

scSoilCompaction.LIGHT_COMPACTION = -0.15
scSoilCompaction.MEDIUM_COMPACTION = 0.05
scSoilCompaction.HEAVY_COMPACTION = 0.2

function scSoilCompaction:prerequisitesPresent(specializations)
    return true
end

function scSoilCompaction:preLoad(savegame)
end

function scSoilCompaction:load(savegame)
    self.applySoilCompaction = scSoilCompaction.applySoilCompaction
    self.calculateSoilCompaction = scSoilCompaction.calculateSoilCompaction
    self.getCompactionLayers = scSoilCompaction.getCompactionLayers
    self.getTireMaxLoad = scSoilCompaction.getTireMaxLoad
end

function scSoilCompaction:delete()
end

function scSoilCompaction:mouseEvent(posX, posY, isDown, isUp, button)
end

function scSoilCompaction:keyEvent(unicode, sym, modifier, isDown)
end

function scSoilCompaction:calculateSoilCompaction(wheel)
    local soilWater = g_currentMission.environment.groundWetness

    local width = wheel.width
    local radius = wheel.radius

    if wheel.radiusOriginal ~= nil then
        radius = wheel.radiusOriginal
    end

    local length = math.max(0.1, 0.35 * radius)

    wheel.load = getWheelShapeContactForce(wheel.node, wheel.wheelShape)
    -- TODO: Increase load when MR is not loaded as vanilla tractors are too light

    if wheel.load == nil then
        wheel.load = (self:getTotalMass(false) / table.getn(self.wheels) + wheel.mass) * 9.81
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
        length = radius
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

    wheel.possibleCompaction = 3
    if soilBulkDensityRef > scSoilCompaction.LIGHT_COMPACTION and soilBulkDensityRef <= scSoilCompaction.MEDIUM_COMPACTION then
        wheel.possibleCompaction = 2

    elseif soilBulkDensityRef > scSoilCompaction.MEDIUM_COMPACTION and soilBulkDensityRef <= scSoilCompaction.HEAVY_COMPACTION then
        wheel.possibleCompaction = 1

    elseif soilBulkDensityRef > scSoilCompaction.HEAVY_COMPACTION then
        wheel.possibleCompaction = 0
    end

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
            local radius = wheel.radius

            -- 4Real Ground Response changes radius of the wheel, but keeps also the original
            if wheel.radiusOriginal ~= nil then
                radius = wheel.radiusOriginal
            end

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
            --ssDebug:drawDensityParallelogram(x, z, widthX, widthZ, heightX, heightZ, 0.25, 255, 255, 0)

            local x0, z0, x1, z1, x2, z2, underLayers = self:getCompactionLayers(wheel, width, length, radius, length, length)
            local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailHeightId, x0, z0, x1, z1, x2, z2)

            -- debug print
            --ssDebug:drawDensityParallelogram(x, z, widthX, widthZ, heightX, heightZ, 0.25, 255, 0, 0)

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

    if wheel.repr == wheel.driveNode then
        x0, y0, z0 = localToWorld(wheel.node, wheel.positionX + width / 2, wheel.positionY, wheel.positionZ - delta0)
        x1, y1, z1 = localToWorld(wheel.node, wheel.positionX - width / 2, wheel.positionY, wheel.positionZ - delta0)
        x2, y2, z2 = localToWorld(wheel.node, wheel.positionX + width / 2, wheel.positionY, wheel.positionZ + delta2)
    else
        local x, _, z = localToLocal(wheel.driveNode, wheel.repr, 0, 0, 0)
        x0, y0, z0 = localToWorld(wheel.repr, x + width / 2, 0, z - delta0)
        x1, y1, z1 = localToWorld(wheel.repr, x - width / 2, 0, z - delta0)
        x2, y2, z2 = localToWorld(wheel.repr, x + width / 2, 0, z + delta2)
    end

    local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(g_currentMission.terrainDetailId, x0, z0, x1, z1, x2, z2)

    local density, area, _ = getDensityParallelogram(g_currentMission.terrainDetailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels)
    local compactionLayers = density / area

    return x0, z0, x1, z1, x2, z2, compactionLayers
end

function scSoilCompaction:update(dt)

    if self.lastSpeedReal ~= 0
            and g_currentMission:getIsServer()
            and not SpecializationUtil.hasSpecialization(Cultivator, self.specializations) then

        if g_seasons ~= nil then
            if not g_seasons.weather:isGroundFrozen() then
                self:applySoilCompaction()
            end
        else
            self:applySoilCompaction()
        end
    end

    if self:isPlayerInRange() then
        local worstCompaction = 4
        for _, wheel in pairs(self.wheels) do
            -- fallback to 'no compaction'
            if wheel.possibleCompaction == nil and wheel.load == nil then
                self:calculateSoilCompaction(wheel)
            end
            worstCompaction = math.min(worstCompaction, Utils.getNoNil(wheel.possibleCompaction, 4))
        end

        if worstCompaction < 4 then
            local storeItem = StoreItemsUtil.storeItemsByXMLFilename[self.configFileName:lower()]
            local compactionText = string.format(g_i18n:getText("COMPACTION_" .. tostring(worstCompaction)), storeItem.name)
            g_currentMission:addExtraPrintText(compactionText)
        end
    end
end

function scSoilCompaction:draw()
end
