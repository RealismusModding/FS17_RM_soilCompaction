----------------------------------------------------------------------------------------------------
-- TIRE PRESSURE SPECIALIZATION
----------------------------------------------------------------------------------------------------
-- Authors:  Rahkiin, reallogger
--
-- Copyright (c) Realismus Modding, 2017
----------------------------------------------------------------------------------------------------

scTirePressure = {}

scTirePressure.MAX_CHARS_TO_DISPLAY = 20

scTirePressure.PRESSURE_MIN = 80
scTirePressure.PRESSURE_LOW = 80
scTirePressure.PRESSURE_NORMAL = 180
scTirePressure.PRESSURE_MAX = 180

function scTirePressure:prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations) and
           --SpecializationUtil.hasSpecialization(ssAtWorkshop, specializations) and
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

    if savegame ~= nil then
        self.scInflationPressure = ssXMLUtil.getInt(savegame.xmlFile, savegame.key .. "#scInflationPressure", self.scInflationPressure)
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

function scTirePressure:mouseEvent(posX, posY, isDown, isUp, button)
end

function scTirePressure:keyEvent(unicode, sym, modifier, isDown)
end

function scTirePressure:loadFromAttributesAndNodes(xmlFile, key)
    return true
end

function scTirePressure:getSaveAttributesAndNodes(nodeIdent)
    local attributes = ""

    attributes = attributes .. "scInflationPressure=\"" .. self.scInflationPressure ..  "\" "

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
            if wheel.ssMaxDeformation == nil then
                wheel.ssMaxDeformation = Utils.getNoNil(wheel.maxDeformation,0)
            end

            wheel.ssMaxLoad = self:getTireMaxLoad(wheel, self.scInflationPressure)
            wheel.maxDeformation = wheel.ssMaxDeformation * scTirePressure.PRESSURE_NORMAL / self.scInflationPressure
        end
    end

    -- Update compaction indicator
    self.ssCompactionIndicatorIsCorrect = false
end

function scTirePressure:update(dt)
    -- self.scInCabTirePressureControl = true

    if self.isClient and self:getIsActiveForInput(false) and self.scInCabTirePressureControl and not self.scAllWheelsCrawlers then
        g_currentMission:addHelpButtonText(string.format(g_i18n:getText("input_SOILCOMPACTION_TIRE_PRESSURE"), self.scInflationPressure), InputBinding.SOILCOMPACTION_TIRE_PRESSURE)

        if InputBinding.hasEvent(InputBinding.SEASONS_TIRE_PRESSURE) then
            self:toggleTirePressure()
        end
    end
end

function scTirePressure:toggleTirePressure()
    self:setInflationPressure(self.scInflationPressure < scTirePressure.PRESSURE_NORMAL and scTirePressure.PRESSURE_NORMAL or scTirePressure.PRESSURE_LOW)
end

function scTirePressure:draw()
end

function scTirePressure:getInflationPressure()
    return self.scInflationPressure
end

function scTirePressure:setInflationPressure(pressure, noEventSend)
    local old = self.scInflationPressure

    self.scInflationPressure = Utils.clamp(pressure, scTirePressure.PRESSURE_MIN, scTirePressure.PRESSURE_MAX)

    if self.scInflationPressure ~= old then
        self:updateInflationPressure()

        -- TODO: Send event
    end
end

function scTirePressure:doCheckSpeedLimit(superFunc)
    local parent = false
    if superFunc ~= nil then
        parent = superFunc(self)
    end

    return parent or self.scInflationPressure < scTirePressure.PRESSURE_NORMAL
end

function scTirePressure:getSpeedLimit()
    local limit = 1000

    -- TODO: linear from normal speed (what is 'normal speed'?)
    if self.scInflationPressure == scTirePressure.PRESSURE_LOW then
        return 10
    end

    return limit
end
