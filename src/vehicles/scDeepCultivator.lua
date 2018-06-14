----------------------------------------------------------------------------------------------------
-- DEEP CULTIVATOR SPECIALIZATION
----------------------------------------------------------------------------------------------------
-- Authors:  baron, Rahkiin, reallogger
--
-- Copyright (c) Realismus Modding, 2017
----------------------------------------------------------------------------------------------------

scDeepCultivator = {}

scDeepCultivator.SHALLOW_FORCE_FACTOR = 0.7

scDeepCultivator.DEPTH_SHALLOW = 1
scDeepCultivator.DEPTH_DEEP = 2
scDeepCultivator.DEPTH_MAX = scDeepCultivator.DEPTH_DEEP

function scDeepCultivator:prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Cultivator, specializations) and
            SpecializationUtil.hasSpecialization(PowerConsumer, specializations)
end

function scDeepCultivator:preLoad()
    self.updateCultivationDepth = scDeepCultivator.updateCultivationDepth
    self.processCultivatorAreas = Utils.overwrittenFunction(self.processCultivatorAreas, scDeepCultivator.processCultivatorAreas)
end

function scDeepCultivator:load(savegame)
    self.scCultivationDepth = scDeepCultivator.DEPTH_SHALLOW
    self.scOrigMaxForce = self.powerConsumer.maxForce
    self.scDeepCultivatorMod = getXMLBool(self.xmlFile, "vehicle.scCultivation#deep")
    self.scSubsoilerMod = getXMLBool(self.xmlFile, "vehicle.scCultivation#subsoiler")

    local isValid, depth = scDeepCultivator.isStoreItemDeepCultivator(StoreItemsUtil.storeItemsByXMLFilename[self.configFileName:lower()])
    self.scValidDeepCultivator = isValid
    if depth ~= nil then
        self.scCultivationDepth = depth
    end

    if self.scCultivationDepth == scDeepCultivator.DEPTH_SHALLOW then
        self.powerConsumer.maxForce = self.scOrigMaxForce * scDeepCultivator.SHALLOW_FORCE_FACTOR
    end

    if savegame ~= nil then
        if savegame.xmlFile ~= nil then
            local depth = Utils.getNoNil(getXMLInt(savegame.xmlFile, savegame.key .. "#scCultivationDepth"), self.scCultivationDepth)
            self:updateCultivationDepth(depth, true)
        end
    end
end

function scDeepCultivator.isStoreItemDeepCultivator(storeItem)
    local xmlFile = loadXMLFile("TempConfig", storeItem.xmlFilename)
    if not xmlFile then return false end

    local typeName = getXMLString(xmlFile, "vehicle#type")
    local deepCultivatorMod = Utils.getNoNil(getXMLBool(xmlFile, "vehicle.scCultivation#deep"), false)
    local subsoilerMod = Utils.getNoNil(getXMLBool(xmlFile, "vehicle.scCultivation#subsoiler"), false)
    local workingWidth = storeItem.specs.workingWidth
    local maxForce = Utils.getNoNil(getXMLFloat(xmlFile, "vehicle.powerConsumer#maxForce"), 0)

    delete(xmlFile)

    if deepCultivatorMod and subsoilerMod then
        logInfo("scDeepCultivator:", storeItem.name .. " cannot be both a subsoiler and a deep cultivator. Subsoiler applied.")
        return false
    end

    if storeItem.name == "CULTIMER L 300" -- Fails to listen to the algo
            or deepCultivatorMod -- special designation
            or maxForce / workingWidth > 6 then -- a lot of force on a small area: assume deep
        return true
    end

    -- Subsoilers act always deep (as a plough)
    if typeName == "subsoiler" -- Platinum DLC
            or subsoilerMod then
        return false, 3
    end

    return false
end

function scDeepCultivator:delete()
end

function scDeepCultivator:getSaveAttributesAndNodes(nodeIdent)
    local attributes = ('scCultivationDepth="%s"'):format(self.scCultivationDepth)
    return attributes, nil
end

function scDeepCultivator:readStream(streamId, connection)
    self:updateCultivationDepth(streamReadInt8(streamId), true)
end

function scDeepCultivator:writeStream(streamId, connection)
    streamWriteInt8(streamId, self.scCultivationDepth)
end

function scDeepCultivator:updateCultivationDepth(newDepth, noEventSend)
    CultivationDepthEvent.sendEvent(self, newDepth, noEventSend)

    local maxForce = self.scOrigMaxForce

    if newDepth > scDeepCultivator.DEPTH_MAX then
        maxForce = maxForce * scDeepCultivator.SHALLOW_FORCE_FACTOR
        newDepth = scDeepCultivator.DEPTH_SHALLOW
    end

    self.scCultivationDepth = newDepth
    self.powerConsumer.maxForce = maxForce
end

function scDeepCultivator:update(dt)
    if not self.isClient or
            not self.scValidDeepCultivator then
        return
    end

    if self:getIsActive() and self:getIsActiveForInput(true) and not self:hasInputConflictWithSelection() then
        if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA4) then
            self:updateCultivationDepth(self.scCultivationDepth + 1)
        end
    end
end

function scDeepCultivator:draw()
    if self.isClient then
        local cultivationDepthText = g_i18n:getText(("CULTIVATION_DEPTH_%d"):format(tostring(self.scCultivationDepth)))
        -- Todo: need to set a new inputBinding?
        g_currentMission:addHelpButtonText(g_i18n:getText("input_SOILCOMPACTION_CULTIVATION_DEPTH"):format(cultivationDepthText), InputBinding.IMPLEMENT_EXTRA4, nil, GS_PRIO_HIGH)
    end
end

function scDeepCultivator:processCultivatorAreas(superFunc, ...)
    local depth = self.scCultivationDepth

    local oldAreaUpdater = Utils.updateCultivatorArea

    Utils.updateCultivatorArea = function(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, forced, commonForced, angle)
        -- checking what crop is cultivated and what stage it is
        local crop
        for index, fruit in pairs(g_currentMission.fruits) do
            local fruitDesc = FruitUtil.fruitIndexToDesc[index]
            local a, b, _ = getDensityParallelogram(fruit.id, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, 0, g_currentMission.numFruitDensityMapChannels)

            if a ~= nil then
                if a > 0 then
                    crop = {
                        desc = fruitDesc,
                        stage = a / b
                    }
                    break
                end
            end
        end

        -- increasing cultivation depth if cultivating radish that is ready
        if crop ~= nil then
            if crop.desc.index == FruitUtil.FRUITTYPE_OILSEEDRADISH and crop.stage == crop.desc.maxHarvestingGrowthState then
                depth = math.min(depth + 1, 3)
            end
        end

        -- Add depth parameter
        return oldAreaUpdater(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, forced, commonForced, angle, depth)
    end

    local sumArea = superFunc(self, ...)

    Utils.updateCultivatorArea = oldAreaUpdater

    return sumArea
end

CultivationDepthEvent = {}
CultivationDepthEvent_mt = Class(CultivationDepthEvent, Event)

InitEventClass(CultivationDepthEvent, "CultivationDepthEvent")

function CultivationDepthEvent:emptyNew()
    local event = Event:new(CultivationDepthEvent_mt)
    return event
end

function CultivationDepthEvent:new(object, newDepth)
    local event = CultivationDepthEvent:emptyNew()

    event.object = object
    event.newDepth = newDepth

    return event
end

function CultivationDepthEvent:readStream(streamId, connection)
    self.object = readNetworkNodeObject(streamId)
    self.newDepth = streamReadInt8(streamId)

    self:run(connection)
end

function CultivationDepthEvent:writeStream(streamId, connection)
    writeNetworkNodeObject(streamId, self.object)
    streamWriteInt8(streamId, self.newDepth)
end

function CultivationDepthEvent:run(connection)
    self.object:updateCultivationDepth(self.newDepth, true)

    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.object)
    end
end

function CultivationDepthEvent.sendEvent(object, newDepth, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(CultivationDepthEvent:new(object, newDepth), nil, nil, object)
        else
            g_client:getServerConnection():sendEvent(CultivationDepthEvent:new(object, newDepth))
        end
    end
end
