----------------------------------------------------------------------------------------------------
-- TIRE PRESSURE SPECIALIZATION
----------------------------------------------------------------------------------------------------
-- Authors:  Rahkiin, reallogger, Wopster
--
-- Copyright (c) Realismus Modding, 2017
----------------------------------------------------------------------------------------------------

scTirePressure = {}

scTirePressure.MAX_CHARS_TO_DISPLAY = 20

scTirePressure.PRESSURE_MIN = 80
scTirePressure.PRESSURE_LOW = 80
scTirePressure.PRESSURE_NORMAL = 180
scTirePressure.PRESSURE_MAX = 180

scTirePressure.INCREASE = 1.15
scTirePressure.FLATE_MULTIPLIER = 0.01

local PARAM_MORPH = "morphPosition"

function scTirePressure:prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and
            SpecializationUtil.hasSpecialization(ssAtWorkshop, specializations) and
            SpecializationUtil.hasSpecialization(scSoilCompaction, specializations)
end

function scTirePressure:preLoad()
    self.updateInflation = scTirePressure.updateInflation
end

function scTirePressure:load(savegame)
    self.updateInflationPressure = scTirePressure.updateInflationPressure
    self.getInflationPressure = scTirePressure.getInflationPressure
    self.setInflationPressure = scTirePressure.setInflationPressure
    self.doCheckSpeedLimit = Utils.overwrittenFunction(self.doCheckSpeedLimit, scTirePressure.doCheckSpeedLimit)
    self.toggleTirePressure = scTirePressure.toggleTirePressure

    WheelsUtil.updateWheelGraphics = Utils.appendedFunction(WheelsUtil.updateWheelGraphics, scTirePressure.updatePressureWheelGraphics)

    self.scInflationPressure = scTirePressure.PRESSURE_NORMAL

    self.scInCabTirePressureControl = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.scInCabTirePressureControl"), false)
    self.scAllWheelsCrawlers = true

    local tireTypeCrawler = WheelsUtil.getTireType("crawler")
    for _, wheel in pairs(self.wheels) do
        if wheel.tireType ~= tireTypeCrawler then
            self.scAllWheelsCrawlers = false
        end

        wheel.scPhysicsSuspensionLenght = wheel.netInfo.suspensionLength
        wheel.scOrgDeltaY = wheel.deltaY
    end

    self.scInflactionDirtyFlag = self:getNextDirtyFlag()

    if self.isClient then
        local sampleNode = Utils.indexToObject(self.components, Utils.getNoNil(getXMLString(self.xmlFile, "vehicle.tirePressure.airSound#linkNode"), "0>"))

        self.sampleAirSound = SoundUtil.loadSample(self.xmlFile, {}, "vehicle.tirePressure.airSound", "$data/maps/sounds/siloFillSound.wav", self.baseDirectory, sampleNode)
    end
end

function scTirePressure:postLoad(savegame)
    if savegame ~= nil and not savegame.resetVehicles then
        local tirePressure = Utils.getNoNil(getXMLInt(savegame.xmlFile, savegame.key .. "#scInflationPressure"), self.scInflationPressure)

        if tirePressure ~= nil then
            self.scDoFirstLoadRun = tirePressure ~= self.scInflationPressure
            self:setInflationPressure(tirePressure, true)
        end
    end
end

function scTirePressure:delete()
    if self.isClient then
        SoundUtil.deleteSample(self.sampleAirSound)
    end
end

function scTirePressure:mouseEvent(...)
end

function scTirePressure:keyEvent(...)
end

function scTirePressure:getSaveAttributesAndNodes(nodeIdent)
    local attributes = ('scInflationPressure="%s"'):format(self.scInflationPressure)
    return attributes, nil
end

function scTirePressure:readStream(streamId, connection)
    self.scInflationPressure = streamReadInt(streamId)
    self.scDoDeflate = streamReadBool(streamId)
    self.scDoInflate = streamReadBool(streamId)
end

function scTirePressure:writeStream(streamId, connection)
    streamWriteInt(streamId, self.scInflationPressure)
    streamWriteBool(streamId, self.scDoDeflate)
    streamWriteBool(streamId, self.scDoInflate)
end

function scTirePressure:readUpdateStream(streamId, timestamp, connection)
    if streamReadBool(streamId) then
        self.scDoDeflate = streamReadBool(streamId)
        self.scDoInflate = streamReadBool(streamId)
    end
end

function scTirePressure:writeUpdateStream(streamId, connection, dirtyMask)
    local allowConnection = connection:getIsServer() or connection ~= self:getOwner()

    if streamWriteBool(streamId, allowConnection and bitAND(dirtyMask, self.scInflactionDirtyFlag) ~= 0) then
        streamWriteBool(streamId, self.scDoDeflate)
        streamWriteBool(streamId, self.scDoInflate)
    end
end

function scTirePressure:updateInflationPressure()
    local tireTypeCrawler = WheelsUtil.getTireType("crawler")

    for _, wheel in pairs(self.wheels) do
        if wheel.tireType ~= tireTypeCrawler then
            if wheel.scMaxDeformation == nil then
                wheel.scMaxDeformation = Utils.getNoNil(wheel.maxDeformation, 0)
            end

            wheel.scMaxLoad = self:getTireMaxLoad(wheel, self.scInflationPressure)

            wheel.maxDeformation = wheel.scMaxDeformation * scTirePressure.PRESSURE_NORMAL / self.scInflationPressure
        end
    end
end

function scTirePressure:update(dt)
    local oldPressure = self:getInflationPressure()

    if self.isClient
            and self:getIsActiveForInput()
            and not self:hasInputConflictWithSelection()
            and self.scInCabTirePressureControl
            and not self.scAllWheelsCrawlers then
        local doInflate = InputBinding.isPressed(InputBinding.SOILCOMPACTION_TIRE_INFLATE)
        local doDeflate = InputBinding.isPressed(InputBinding.SOILCOMPACTION_TIRE_DEFLATE)

        if doInflate or doDeflate then
            local pressureChange = dt * scTirePressure.FLATE_MULTIPLIER

            if doDeflate then
                pressureChange = -pressureChange
            end

            self:setInflationPressure(oldPressure + pressureChange)
        end

        self:updateInflation(doDeflate, doInflate)
    end

    if self.firstTimeRun and self.scDoFirstLoadRun then
        -- Todo: handle first time run deformation.
        self.scDoFirstLoadRun = false
    end

    -- Force stop for compressor
    if oldPressure == self:getInflationPressure() and (self.scDoInflate or self.scDoDeflate) then
        self:updateInflation(false)
    end
end

function scTirePressure:updateTick(dt)
    if self.isClient then
        local pressure = self:getInflationPressure()
        local isCapped = pressure == scTirePressure.PRESSURE_MIN or pressure == scTirePressure.PRESSURE_MAX

        if (self.scDoInflate or self.scDoDeflate) and not isCapped then
            local pitch = self.scDoDeflate and 1.5 or 1

            SoundUtil.setSamplePitch(self.sampleAirSound, pitch)
            SoundUtil.play3DSample(self.sampleAirSound)
        else
            SoundUtil.stop3DSample(self.sampleAirSound)
        end
    end
end

function scTirePressure:updateInflation(doDeflate, doInflate)
    if not self.isClient then
        return
    end

    if doDeflate ~= self.scDoDeflate or doInflate ~= self.scDoInflate then
        self.scDoDeflate = doDeflate
        self.scDoInflate = doInflate
        self:raiseDirtyFlags(self.scInflactionDirtyFlag)
    end
end

function scTirePressure:toggleTirePressure()
    self:setInflationPressure(self.scInflationPressure < scTirePressure.PRESSURE_NORMAL and scTirePressure.PRESSURE_NORMAL or scTirePressure.PRESSURE_LOW)
end

function scTirePressure:draw()
    if self.isClient then
        if self.scInCabTirePressureControl and not self.scAllWheelsCrawlers then
            local pressure = self:getInflationPressure()
            g_currentMission:addHelpButtonText(g_i18n:getText("input_SOILCOMPACTION_TIRE_INFLATE"), InputBinding.SOILCOMPACTION_TIRE_INFLATE)
            g_currentMission:addHelpButtonText(g_i18n:getText("input_SOILCOMPACTION_TIRE_DEFLATE"), InputBinding.SOILCOMPACTION_TIRE_DEFLATE)
            g_currentMission:addExtraPrintText(g_i18n:getText("info_TIRE_PRESSURE"):format(pressure / 100))
        end
    end

    --if self.isEntered then
    --    renderText(0.44, 0.78, 0.01, "limit = " .. tostring(self.motor.maxForwardSpeed))
    --end
end

function scTirePressure:getInflationPressure()
    return self.scInflationPressure
end

function scTirePressure:setInflationPressure(pressure, noEventSend)
    SetInflationPressureEvent.sendEvent(self, pressure, noEventSend)

    local old = self.scInflationPressure

    self.scInflationPressure = Utils.clamp(pressure, scTirePressure.PRESSURE_MIN, scTirePressure.PRESSURE_MAX)

    if self.scInflationPressure ~= old then
        self:updateInflationPressure()
    end
end

function scTirePressure:doCheckSpeedLimit(superFunc)
    local parent = false
    if superFunc ~= nil then
        parent = superFunc(self)
    end

    return parent or self.scInflationPressure < scTirePressure.PRESSURE_NORMAL
end

function scTirePressure:getPressureSpeedLimit()
    local maxSpeed = self.motor.maxForwardSpeed
    local limit = maxSpeed - 10
    self.speedLimit = (self.scInflationPressure - scTirePressure.PRESSURE_MIN) / (scTirePressure.PRESSURE_MAX - scTirePressure.PRESSURE_MIN) + 10
    self.motor.speedLimit = self.speedLimit
end

function scTirePressure.updatePressureWheelGraphics(self, wheel, x, y, z, xDrive, suspensionLength)
    if self.scInflationPressure ~= nil and not self.mrIsMrVehicle then
        if wheel.wheelTire ~= nil then
            local tireTypeCrawler = WheelsUtil.getTireType("crawler")

            if wheel.tireType ~= tireTypeCrawler then
                local x, y, z, _ = getShaderParameter(wheel.wheelTire, PARAM_MORPH)
                local deformation = Utils.clamp((wheel.deltaY + 0.04 - suspensionLength) * (scTirePressure.INCREASE - (self.scInflationPressure - 80) / 100), 0, wheel.maxDeformation)

                -- Redo the shader morph for better graphical display.. could have just clamped the maxDeformation value but that doesn't really give the correct visual feeling.
                setShaderParameter(wheel.wheelTire, PARAM_MORPH, x, y, z, deformation, false)

                if wheel.additionalWheels ~= nil then
                    for _, additionalWheel in pairs(wheel.additionalWheels) do
                        local x, y, z, _ = getShaderParameter(additionalWheel.wheelTire, PARAM_MORPH)
                        setShaderParameter(additionalWheel.wheelTire, PARAM_MORPH, x, y, z, deformation, false)
                    end
                end

                suspensionLength = suspensionLength + deformation
            end
        end

        suspensionLength = suspensionLength - wheel.deltaY

        local isInflating = self.scDoDeflate or self.scDoInflate
        local isCapped = self.scInflationPressure == scTirePressure.PRESSURE_MIN or self.scInflationPressure == scTirePressure.PRESSURE_MAX

        if isInflating and not isCapped and math.abs(wheel.scPhysicsSuspensionLenght - suspensionLength) > 0.01 then
            wheel.scPhysicsSuspensionLenght = suspensionLength
            wheel.deltaY = wheel.scOrgDeltaY + suspensionLength

            local targetRadius = wheel.scOrgRadius - suspensionLength
            local currentRadius = wheel.radius

            if not (self.scDoDeflate and targetRadius > currentRadius) and not (self.scDoInflate and targetRadius < currentRadius) then
                wheel.radius = targetRadius

                if self.isServer then
                    self:updateWheelBase(wheel)
                end
            end
        end

        local dirX, dirY, dirZ = 0, -1, 0

        if wheel.repr ~= wheel.driveNode then
            dirX, dirY, dirZ = localDirectionToLocal(wheel.repr, getParent(wheel.repr), 0, -1, 0)
        end

        setTranslation(wheel.repr, wheel.startPositionX + dirX * suspensionLength, wheel.startPositionY + dirY * suspensionLength, wheel.startPositionZ + dirZ * suspensionLength)
    end
end

function scTirePressure:consoleCommandToggleInCapControl()
    local vehicle = g_currentMission.controlledVehicle

    if vehicle == nil then
        return "You are not in a vehicle"
    end

    vehicle.scInCabTirePressureControl = not vehicle.scInCabTirePressureControl
end

SetInflationPressureEvent = {}
SetInflationPressureEvent_mt = Class(SetInflationPressureEvent, Event)

InitEventClass(SetInflationPressureEvent, "SetInflationPressureEvent")

function SetInflationPressureEvent:emptyNew()
    local event = Event:new(SetInflationPressureEvent_mt)
    return event
end

function SetInflationPressureEvent:new(object, pressure)
    local event = SetInflationPressureEvent:emptyNew()

    event.object = object
    event.pressure = pressure

    return event
end

function SetInflationPressureEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.pressure = streamReadInt(streamId)

    self:run(connection)
end

function SetInflationPressureEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt(streamId, self.pressure)
end

function SetInflationPressureEvent:run(connection)
    self.object:setInflationPressure(self.pressure, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function SetInflationPressureEvent.sendEvent(object, pressure, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SetInflationPressureEvent:new(object, pressure), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(SetInflationPressureEvent:new(object, pressure))
        end
    end
end
