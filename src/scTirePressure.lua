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

scTirePressure.INCREASE = 0.25
scTirePressure.FLATE_MULTIPLIER = 0.01

local PARAM_MORPH = "morphPosition"

function scTirePressure:prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and
            SpecializationUtil.hasSpecialization(ssAtWorkshop, specializations) and
            SpecializationUtil.hasSpecialization(scSoilCompaction, specializations)
end

function scTirePressure:preLoad()
end

function scTirePressure:load(savegame)
    self.scInflationPressure = scTirePressure.PRESSURE_NORMAL

    self.updateInflationPressure = scTirePressure.updateInflationPressure
    self.getInflationPressure = scTirePressure.getInflationPressure
    self.setInflationPressure = scTirePressure.setInflationPressure
    self.doCheckSpeedLimit = Utils.overwrittenFunction(self.doCheckSpeedLimit, scTirePressure.doCheckSpeedLimit)
    self.toggleTirePressure = scTirePressure.toggleTirePressure
    WheelsUtil.updateWheelGraphics = Utils.appendedFunction(WheelsUtil.updateWheelGraphics, scTirePressure.updatePressureWheelGraphics)

    if savegame ~= nil then
        if savegame.xmlFile ~= nil then
            self.scInflationPressure = Utils.getNoNil(getXMLInt(savegame.xmlFile, savegame.key .. "#scInflationPressure"), self.scInflationPressure)
        end
    end

    self.scInCabTirePressureControl = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.scInCabTirePressureControl"), false)
    self.scAllWheelsCrawlers = true

    local tireTypeCrawler = WheelsUtil.getTireType("crawler")
    for _, wheel in pairs(self.wheels) do
        if wheel.tireType ~= tireTypeCrawler then
            self.scAllWheelsCrawlers = false
        end
    end

    self:updateInflationPressure()
end

function scTirePressure:delete()
end

function scTirePressure:mouseEvent(...)
end

function scTirePressure:keyEvent(...)
end

function scTirePressure:loadFromAttributesAndNodes(xmlFile, key)
    return true
end

function scTirePressure:getSaveAttributesAndNodes(nodeIdent)
    local attributes = ""

    attributes = attributes .. "scInflationPressure=\"" .. self.scInflationPressure .. "\" "

    return attributes, ""
end

function scTirePressure:readStream(streamId, connection)
    self.scInflationPressure = streamReadInt(streamId)
end

function scTirePressure:writeStream(streamId, connection)
    streamWriteInt(streamId, self.scInflationPressure)
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
    -- self.scInCabTirePressureControl = true

    if self.isClient and self:getIsActiveForInput(false) and self.scInCabTirePressureControl and not self.scAllWheelsCrawlers then
        --g_currentMission:addHelpButtonText(string.format(g_i18n:getText("input_SOILCOMPACTION_TIRE_PRESSURE"), self.scInflationPressure), InputBinding.SOILCOMPACTION_TIRE_PRESSURE)
        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("input_SOILCOMPACTION_TIRE_INFLATE"), InputBinding.SOILCOMPACTION_TIRE_INFLATE))
        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("input_SOILCOMPACTION_TIRE_DEFLATE"), InputBinding.SOILCOMPACTION_TIRE_DEFLATE))
        g_currentMission:addExtraPrintText(string.format(g_i18n:getText("info_TIRE_PRESSURE"), compressor.foundVehicle:getInflationPressure()))

        local change = dt * scTirePressure.FLATE_MULTIPLIER
        if InputBinding.hasEvent(InputBinding.SOILCOMPACTION_TIRE_INFLATE) then
            --self:toggleTirePressure()
            self:setInflationPressure(self:getInflationPressure() + change)
        elseif InputBinding.hasEvent(InputBinding.SOILCOMPACTION_TIRE_DEFLATE) then
            self:setInflationPressure(self:getInflationPressure() - change)
        end
    end
end

function scTirePressure:toggleTirePressure()
    self:setInflationPressure(self.scInflationPressure < scTirePressure.PRESSURE_NORMAL and scTirePressure.PRESSURE_NORMAL or scTirePressure.PRESSURE_LOW)
end

function scTirePressure:draw()
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
                local deformation = Utils.clamp((wheel.deltaY + 0.04 - suspensionLength) * (scTirePressure.INCREASE + (self.scInflationPressure - 80) / 100), 0, wheel.maxDeformation)
                deformation = wheel.maxDeformation
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

        local dirX, dirY, dirZ = 0, -1, 0

        if wheel.repr ~= wheel.driveNode then
            dirX, dirY, dirZ = localDirectionToLocal(wheel.repr, getParent(wheel.repr), 0, -1, 0)
        end
        setTranslation(wheel.repr, wheel.startPositionX + dirX * suspensionLength, wheel.startPositionY + dirY * suspensionLength, wheel.startPositionZ + dirZ * suspensionLength)
    end
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
