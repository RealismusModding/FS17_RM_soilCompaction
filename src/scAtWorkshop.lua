----------------------------------------------------------------------------------------------------
-- AT WORKSHOP SPECIALIZATION
----------------------------------------------------------------------------------------------------
-- Purpose: Detect if a player is in walking range of a vehicle and vehicle is int he workshop
-- Authors: Rahkiin
--
-- Copyright (c) Realismus Modding, 2017
----------------------------------------------------------------------------------------------------

scAtWorkshop = {}

scAtWorkshop.RANGE = 6.0

function scAtWorkshop:prerequisitesPresent(specializations)
    return true
end

function scAtWorkshop:load(savegame)
end

function scAtWorkshop:delete()
end

function scAtWorkshop:mouseEvent(posX, posY, isDown, isUp, button)
end

function scAtWorkshop:keyEvent(unicode, sym, modifier, isDown)
end

function scAtWorkshop:loadFromAttributesAndNodes(xmlFile, key)
    return true
end

function scAtWorkshop:getSaveAttributesAndNodes(nodeIdent)
    return attributes, ""
end

function scAtWorkshop:readStream(streamId, connection)
end

function scAtWorkshop:writeStream(streamId, connection)
end

function scAtWorkshop:draw()
end

local function isInDistance(self, player, maxDistance, refNode)
    local vx, _, vz = getWorldTranslation(player.rootNode)
    local sx, _, sz = getWorldTranslation(refNode)

    local dist = Utils.vector2Length(vx - sx, vz - sz)

    return dist <= maxDistance
end

-- Jos: Don't ask me why, but putting them inside Repairable breaks all, even with
-- callSpecializationsFunction...
local function getIsPlayerInRange(self, distance, player)
    if self.rootNode ~= 0 then
        return isInDistance(self, player, distance, self.rootNode), player
    end

    return false, nil
end

function scAtWorkshop:update(dt)
end

function scAtWorkshop:updateTick(dt)
    -- Calculate if vehicle is in range for message about repairing

    if self.isClient and g_currentMission.player ~= nil then
        local isPlayerInRange, player = getIsPlayerInRange(self, scAtWorkshop.RANGE, g_currentMission.player)

        if isPlayerInRange and g_currentMission.controlPlayer then
            self.scPlayerInRange = player
        else
            self.scPlayerInRange = nil
        end
    end
end

function scAtWorkshop:isPlayerInRange(player)
    if player == nil then
        player = g_currentMission.player
    end

    return self.scPlayerInRange == player
end

function scAtWorkshop:isAtWorkshop()
    return self.scInRangeOfWorkshop ~= nil
end

function scAtWorkshop:getWorkshop()
    return self.scInRangeOfWorkshop
end

function scAtWorkshop:canPlayerInteractInWorkshop(player)
    return self:isAtWorkshop() and self:isPlayerInRange(player)
end

