----------------------------------------------------------------------------------------------------
-- AIR COMPRESSOR
----------------------------------------------------------------------------------------------------
-- Purpose:
-- Authors:  Rahkiin, reallogger, Wopster
--
-- Note: bulk of the code is from the high pressure washer, which has similar features.
--
-- Copyright (c) Realismus Modding, 2018
----------------------------------------------------------------------------------------------------

scAirCompressorPlaceable = {}

local scAirCompressorPlaceable_mt = Class(scAirCompressorPlaceable, Placeable)

InitObjectClass(scAirCompressorPlaceable, "scAirCompressorPlaceable")

function scAirCompressorPlaceable:new(isServer, isClient, customMt)
    local mt = customMt
    if mt == nil then
        mt = scAirCompressorPlaceable_mt
    end

    local self = Placeable:new(isServer, isClient, mt)
    registerObjectClassName(self, "scAirCompressorPlaceable")

    self.messageShown = false

    return self
end

function scAirCompressorPlaceable:load(xmlFilename, x, y, z, rx, ry, rz, initRandom)
    if not scAirCompressorPlaceable:superClass().load(self, xmlFilename, x, y, z, rx, ry, rz, initRandom) then
        return false
    end

    local xmlFile = loadXMLFile("TempXML", xmlFilename)

    self.playerInRangeDistance = Utils.getNoNil(getXMLFloat(xmlFile, "placeable.airCompressor.playerInRangeDistance"), 3)
    self.actionRadius = Utils.getNoNil(getXMLFloat(xmlFile, "placeable.airCompressor.actionRadius#distance"), 5)
    self.airDistance = Utils.getNoNil(getXMLFloat(xmlFile, "placeable.airCompressor.airDistance"), 10)
    self.pricePerSecond = Utils.getNoNil(getXMLFloat(xmlFile, "placeable.airCompressor.pricePerSecond"), 10)
    self.inflationMultiplier = Utils.getNoNil(getXMLFloat(xmlFile, "placeable.airCompressor.inflationMultiplier"), 0.005)
    self.deflationMultiplier = Utils.getNoNil(getXMLFloat(xmlFile, "placeable.airCompressor.deflationMultiplier"), 0.015)

    self.nozzleNode = Utils.indexToObject(self.nodeId, getXMLString(xmlFile, "placeable.airCompressor.nozzle#index"))
    self.linkPosition = Utils.getVectorNFromString(Utils.getNoNil(getXMLString(xmlFile, "placeable.airCompressor.nozzle#position"), "0 0 0"), 3)
    self.linkRotation = Utils.getRadiansFromString(Utils.getNoNil(getXMLString(xmlFile, "placeable.airCompressor.nozzle#rotation"), "0 0 0"), 3)
    self.nozzleNodeParent = getParent(self.nozzleNode)
    self.nozzleRaycastNode = Utils.indexToObject(self.nodeId, getXMLString(xmlFile, "placeable.airCompressor.nozzle#raycastNode"))

    if self.isClient then
        --self.sampleCompressorSound = SoundUtil.loadSample(xmlFile, {}, "placeable.airCompressor.compressorSound", "$data/placeables/woodCrusher/jenz/jenzHE700motor_idle.wav", self.baseDirectory, self.nodeId)
        self.sampleCompressorSound = SoundUtil.loadSample(xmlFile, {}, "placeable.airCompressor.compressorSound", "$data/sounds/engine/runHP120.wav", self.baseDirectory, self.nodeId)
        self.sampleCompressorStop = SoundUtil.loadSample(xmlFile, {}, "placeable.airCompressor.compressorStop", "$data/sounds/technicalAccessories/pressure_regulator.wav", self.baseDirectory, self.nodeId)
        self.sampleAirSound = SoundUtil.loadSample(xmlFile, {}, "vehicle.tirePressure.airSound", "$data/maps/sounds/siloFillSound.wav", self.baseDirectory, self.nozzleNode)
        self.sampleStopAirSound = SoundUtil.loadSample(xmlFile, {}, "vehicle.tirePressure.stopSound", "$data/sounds/technicalAccessories/brakeBig.wav", self.baseDirectory, self.nodeId)
    end

    delete(xmlFile)

    self.isPlayerInRange = false
    self.isTurnedOn = false -- making sound, holding nozzle gun
    self.isTurningOff = false -- making no sound, not holding nozzle gun

    -- The nozzle gun that can be activated
    self.activatable = scAirCompressorPlaceableActivatable:new(self)

    -- To check distance between compressor and player
    self.lastInRangePosition = { 0, 0, 0 }

    -- Sound animation for turning off
    self.turnOffTime = 0
    self.turnOffDuration = 1000

    return true
end

function scAirCompressorPlaceable:delete()
    self:setIsTurnedOn(false, nil, false)

    if self.isClient then
        -- Delete effects, samples
        SoundUtil.deleteSample(self.sampleCompressorSound)
        SoundUtil.deleteSample(self.sampleCompressorStop)
        SoundUtil.deleteSample(self.sampleAirSound)
        SoundUtil.deleteSample(self.sampleStopAirSound)
    end

    unregisterObjectClassName(self)
    g_currentMission:removeActivatableObject(self.activatable)

    scAirCompressorPlaceable:superClass().delete(self)
end

function scAirCompressorPlaceable:readStream(streamId, connection)
    scAirCompressorPlaceable:superClass().readStream(self, streamId, connection)

    if connection:getIsServer() then
        local isTurnedOn = streamReadBool(streamId)
        if isTurnedOn then
            local player = readNetworkNodeObject(streamId)

            if player ~= nil then
                self:setIsTurnedOn(isTurnedOn, player, true)
            end
        end
    end
end

function scAirCompressorPlaceable:writeStream(streamId, connection)
    scAirCompressorPlaceable:superClass().writeStream(self, streamId, connection)

    if not connection:getIsServer() then
        streamWriteBool(streamId, self.isTurnedOn)
        if self.isTurnedOn then
            writeNetworkNodeObject(streamId, self.currentPlayer)
        end
    end
end

function scAirCompressorPlaceable:activateHandtool(player)
    self:setIsTurnedOn(true, player, true)
end

function scAirCompressorPlaceable:update(dt)
    scAirCompressorPlaceable:superClass().update(self, dt)

    if self.currentPlayer ~= nil then
        local isPlayerInRange = self:getIsPlayerInRange(self.actionRadius, self.currentPlayer)

        if isPlayerInRange then
            self.lastInRangePosition = { getTranslation(self.currentPlayer.rootNode) }
        else
            -- Limit player movement
            local kx, _, kz = getWorldTranslation(self.nodeId)
            local px, py, pz = getWorldTranslation(self.currentPlayer.rootNode)
            local len = Utils.vector2Length(px - kx, pz - kz)

            local x, y, z = unpack(self.lastInRangePosition)
            x = kx + ((px - kx) / len) * (self.actionRadius - 0.00001 * dt)
            z = kz + ((pz - kz) / len) * (self.actionRadius - 0.00001 * dt)
            self.currentPlayer:moveToAbsoluteInternal(x, py, z)
            self.lastInRangePosition = { x, y, z }

            if not self.messageShown and self.currentPlayer == g_currentMission.player then
                g_currentMission:showBlinkingWarning(g_i18n:getText("warning_compressorRangeRestriction"), 6000)
                self.messageShown = true
            end
        end
    end

    if self.isServer then
        if self.isTurnedOn and self.doFlating then
            self.foundVehicle = nil

            if self.nozzleRaycastNode ~= nil then
                self:flateVehicle(self.nozzleRaycastNode, dt)
            else
                self:flateVehicle(self.currentPlayer.cameraNode, dt)
            end

            local price = self.pricePerSecond * (dt / 1000)
            g_currentMission.missionStats:updateStats("expenses", price)
            g_currentMission:addSharedMoney(-price, "vehicleRunningCost")
        end
    end

    if self.isClient and self.isTurningOff then
        if g_currentMission.time < self.turnOffTime then
            if self.sampleCompressorSound ~= nil then
                local pitch = Utils.lerp(0.5, 2, Utils.clamp((self.turnOffTime - g_currentMission.time) / self.turnOffDuration, 0, 1))
                local volume = Utils.lerp(0, 1, Utils.clamp((self.turnOffTime - g_currentMission.time) / self.turnOffDuration, 0, 1))
                SoundUtil.setSamplePitch(self.sampleCompressorSound, pitch)
                SoundUtil.setSampleVolume(self.sampleCompressorSound, volume)
                SoundUtil.play3DSample(self.sampleCompressorStop)
            end
        else
            self.isTurningOff = false
            if self.sampleCompressorSound ~= nil then
                SoundUtil.stop3DSample(self.sampleCompressorSound)
                SoundUtil.stop3DSample(self.sampleCompressorStop)
            end
        end
    end
end

function scAirCompressorPlaceable:flateVehicle(node, dt)
    local x, y, z = getWorldTranslation(node)
    local dx, dy, dz = localDirectionToWorld(node, 0, 0, -1)

    raycastAll(x, y, z, dx, dy, dz, "airRaycastCallback", self.airDistance, self, 32 + 64 + 128 + 256 + 4096 + 8194)

    if self.foundVehicle ~= nil then
        local vehicle = self.foundVehicle

        if not vehicle.scAllWheelsCrawlers then
            local doDeflate = self.flateDirection == -1
            local pressureChange = dt * self.inflationMultiplier

            if doDeflate then
                pressureChange = -pressureChange
            end

            vehicle:setInflationPressure(vehicle:getInflationPressure() + pressureChange)
            vehicle:updateInflaction(doDeflate, not doDeflate)

            for _, wheel in pairs(vehicle.wheels) do
                vehicle:calculateSoilCompaction(wheel)
            end

            WheelsUtil.updateWheelsGraphics(vehicle, dt)
        end
    end
end

function scAirCompressorPlaceable:updateTick(dt)
    scAirCompressorPlaceable:superClass().updateTick(self, dt)

    local isPlayerInRange, player = self:getIsPlayerInRange(self.playerInRangeDistance)

    if isPlayerInRange then
        self.playerInRange = player
        self.isPlayerInRange = true
        g_currentMission:addActivatableObject(self.activatable)
    else
        self.playerInRange = nil
        self.isPlayerInRange = false
        g_currentMission:removeActivatableObject(self.activatable)
    end
end

function scAirCompressorPlaceable:setIsInflating(doInflating, doDeflating, force, noEventSend)
    local doFlating = doInflating or doDeflating
    self.flateDirection = doInflating and 1 or -1

    --     HPWPlaceableStateEvent.sendEvent(self, doWashing, noEventSend)

    if self.doFlating ~= doFlating then
        if self.isClient then
            -- if self.washerParticleSystems ~= nil then
            --     for _,ps in pairs(self.washerParticleSystems) do
            --         ParticleUtil.setEmittingState(ps, doWashing and self:getIsActiveForInput())
            --     end
            -- end

            if doFlating then
                local pitch = doFlating == doDeflating and 1.5 or 1
                if doInflating or self.foundVehicle ~= nil then
                    SoundUtil.play3DSample(self.sampleAirSound)
                end
                SoundUtil.setSamplePitch(self.sampleAirSound, pitch)

                -- EffectManager:setFillType(self.waterEffects, FillUtil.FILLTYPE_WATER)
                -- EffectManager:startEffects(self.waterEffects)

                -- if self.sampleWashing ~= nil and self.currentPlayer == g_currentMission.player  then
                --     if self:getIsActiveForSound() then
                --         SoundUtil.playSample(self.sampleWashing, 0, 0, 1)
                --     end
                -- end
            else
                SoundUtil.stop3DSample(self.sampleAirSound)
                -- if force then
                --     EffectManager:resetEffects(self.waterEffects)
                -- else
                --     EffectManager:stopEffects(self.waterEffects)
                -- end

                -- if self.sampleWashing ~= nil then
                --     SoundUtil.stopSample(self.sampleWashing, true)
                -- end
            end
        end

        self.doFlating = doFlating
    end
end

function scAirCompressorPlaceable:setIsTurnedOn(isTurnedOn, player, noEventSend)
    -- HPWPlaceableTurnOnEvent.sendEvent(self, isTurnedOn, player, noEventSend)

    if self.isTurnedOn ~= isTurnedOn then
        if isTurnedOn then
            self.isTurnedOn = isTurnedOn
            self.currentPlayer = player

            -- player stuff
            local tool = {}
            tool.node = self.nozzleNode
            link(player.toolsRootNode, tool.node)
            setVisibility(tool.node, false)
            setTranslation(tool.node, unpack(self.linkPosition))
            setRotation(tool.node, unpack(self.linkRotation))
            tool.update = scAirCompressorPlaceable.updateNozzle
            tool.updateTick = scAirCompressorPlaceable.updateTickNozzle
            tool.delete = scAirCompressorPlaceable.deleteNozzle
            tool.draw = scAirCompressorPlaceable.drawNozzle
            tool.onActivate = scAirCompressorPlaceable.activateNozzle
            tool.onDeactivate = scAirCompressorPlaceable.deactivateNozzle
            tool.targets = self.targets
            tool.owner = self
            tool.static = false
            self.tool = tool
            self.currentPlayer:setTool(tool)
            self.currentPlayer.hasNozzleGun = true

            if self.isClient then
                -- if self.sampleSwitch ~= nil and self:getIsActiveForSound() then
                --     SoundUtil.playSample(self.sampleSwitch, 1, 0, nil)
                -- end
                if self.sampleCompressorSound ~= nil then
                    SoundUtil.play3DSample(self.sampleCompressorSound)
                    SoundUtil.setSamplePitch(self.sampleCompressorSound, 2)
                end
                if self.isTurningOff then
                    self.isTurningOff = false
                end
                setVisibility(self.nozzleNode, g_currentMission.player == player)
            end
        else
            self:onDeactivate()
        end
        if self.exhaustNode ~= nil then
            setVisibility(self.exhaustNode, isTurnedOn)
        end
    end
end

function scAirCompressorPlaceable:onDeactivate()
    if self.isClient then
        if self.sampleSwitch ~= nil and self:getIsActiveForSound() then
            -- SoundUtil.playSample(self.sampleSwitch, 1, 0, nil)
        end
    end

    self.isTurnedOn = false
    setVisibility(self.nozzleNode, true)
    self:setIsInflating(false, false, true, true)

    -- Remove tool from player
    if self.currentPlayer ~= nil then
        self.currentPlayer:setToolById(0, true)
        self.currentPlayer.hasNozzleGun = false
    end

    if self.isClient then
        if self.sampleWashing ~= nil then
            -- SoundUtil.stopSample(self.sampleWashing, true)
        end

        self.isTurningOff = true
        self.turnOffTime = g_currentMission.time + self.turnOffDuration

        -- Reset nozzle node
        link(self.nozzleNodeParent, self.nozzleNode)
        setTranslation(self.nozzleNode, 0, 0, 0)
        setRotation(self.nozzleNode, 0, 0, 0)
    end

    self.currentPlayer = nil
end

function scAirCompressorPlaceable:getIsActiveForInput()
    if self.isTurnedOn and self.currentPlayer == g_currentMission.player and not g_gui:getIsGuiVisible() then
        return true
    end

    return false
end

function scAirCompressorPlaceable:getIsActiveForSound()
    return self:getIsActiveForInput()
end

function scAirCompressorPlaceable:canBeSold()
    local warning = g_i18n:getText("shop_messageReturnVehicleInUse")

    if self.currentPlayer ~= nil then
        return false, warning
    end

    return true, nil
end

-- Simple raycast to find the vehicle pointed at by the player
function scAirCompressorPlaceable:airRaycastCallback(hitActorId, x, y, z, distance, nx, ny, nz, subShapeIndex, hitShapeId)
    local vehicle = g_currentMission.nodeToVehicle[hitActorId]

    if hitActorId ~= hitShapeId then
        -- object is a compoundChild. Try to find the compound
        local parentId = hitShapeId
        while parentId ~= 0 do
            if g_currentMission.nodeToVehicle[parentId] ~= nil then
                -- found valid compound
                vehicle = g_currentMission.nodeToVehicle[parentId]
                break
            end
            parentId = getParent(parentId)
        end
    end

    if vehicle ~= nil and vehicle.getInflationPressure ~= nil and vehicle.setInflationPressure ~= nil then
        self.foundCoords = { x, y, z }
        self.foundVehicle = vehicle

        return false
    end

    return true
end

registerPlaceableType("scAirCompressor", scAirCompressorPlaceable)

----------------------
-- Nozzle Gun player tool
----------------------
function scAirCompressorPlaceable.activateNozzle(tool)
    setVisibility(tool.node, true)
end

function scAirCompressorPlaceable.deactivateNozzle(tool)
    tool.owner:setIsTurnedOn(false, nil)
end

function scAirCompressorPlaceable.deleteNozzle(tool)
    tool.owner:setIsTurnedOn(false, nil)
end

function scAirCompressorPlaceable.drawNozzle(tool)
    local compressor = tool.owner

    if compressor.currentPlayer == g_currentMission.player then
        g_currentMission:addHelpButtonText(g_i18n:getText("input_COMPRESSOR_INFLATE"), InputBinding.ACTIVATE_HANDTOOL)
        g_currentMission:addHelpButtonText(g_i18n:getText("input_COMPRESSOR_DEFLATE"), InputBinding.ACTIVATE_HANDTOOL2)

        if compressor.doFlating and compressor.foundVehicle ~= nil and compressor.foundVehicle.getInflationPressure ~= nil then
            g_currentMission:addExtraPrintText(string.format(g_i18n:getText("info_TIRE_PRESSURE"), compressor.foundVehicle:getInflationPressure()))
        end
    end
end

function scAirCompressorPlaceable.updateNozzle(tool, dt, allowInput)
    if allowInput then
        tool.owner:setIsInflating(InputBinding.isPressed(InputBinding.ACTIVATE_HANDTOOL),
            InputBinding.isPressed(InputBinding.ACTIVATE_HANDTOOL2),
            false, false)
    end
end

function scAirCompressorPlaceable.updateTickNozzle(tool, dt, allowInput)
end

----------------------
-- Activatable object
----------------------

scAirCompressorPlaceableActivatable = {}
local scAirCompressorPlaceableActivatable_mt = Class(scAirCompressorPlaceableActivatable)

function scAirCompressorPlaceableActivatable:new(airCompressor)
    local self = {}
    setmetatable(self, scAirCompressorPlaceableActivatable_mt)

    self.airCompressor = airCompressor
    self.activateText = "unknown"

    return self
end

function scAirCompressorPlaceableActivatable:getIsActivatable()
    if not self.airCompressor.isPlayerInRange then
        return false
    end

    if self.airCompressor.playerInRange ~= g_currentMission.player then
        return false
    end

    if not self.airCompressor.playerInRange.isControlled then
        return false
    end

    if self.airCompressor.isTurnedOn and self.airCompressor.currentPlayer ~= g_currentMission.player then
        return false
    end

    if not self.airCompressor.isTurnedOn and g_currentMission.player.hasNozzleGun == true then
        return false
    end

    if self.airCompressor.isDeleted then
        return false
    end

    self:updateActivateText()
    return true
end

function scAirCompressorPlaceableActivatable:onActivateObject()
    self.airCompressor:setIsTurnedOn(not self.airCompressor.isTurnedOn, g_currentMission.player)
    self:updateActivateText()
    g_currentMission:addActivatableObject(self)
end

function scAirCompressorPlaceableActivatable:drawActivate()
end

function scAirCompressorPlaceableActivatable:updateActivateText()
    if self.airCompressor.isTurnedOn then
        self.activateText = string.format(g_i18n:getText("action_turnOffOBJECT"), g_i18n:getText("typeDesc_airCompressor"))
    else
        self.activateText = string.format(g_i18n:getText("action_turnOnOBJECT"), g_i18n:getText("typeDesc_airCompressor"))
    end
end
