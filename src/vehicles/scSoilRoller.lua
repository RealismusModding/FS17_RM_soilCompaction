scSoilRoller = {}

scSoilRoller.TYPE_DEFAULT = 0
scSoilRoller.TYPE_CAMBRIDGE = 1

function scSoilRoller:prerequisitesPresent(specializations)
    return true
end

function scSoilRoller:preLoad()
end

function scSoilRoller:load(savegame)
    self.processRollerAreas = Utils.overwrittenFunction(self.processRollerAreas, scSoilRoller.processRollerAreas)

    self.scRollerType = scSoilRoller.TYPE_DEFAULT

    local isCambridgeRoller = Utils.getNoNil(getXMLBool(self.xmlFile, "vehicle.scSoilRoller#cambridge"), false)
    if isCambridgeRoller then
        self.scRollerType = scSoilRoller.TYPE_CAMBRIDGE
    end
end

local function updateRollerArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, rollerType)
    local detailId = g_currentMission.terrainDetailId

    local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(nil, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

    -- Clear any leftovers from heightmap to make it act like a roller.
    TipUtil.clearArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

    local hasWetSoil = g_currentMission.environment.groundWetness > 0.2

    if hasWetSoil then
        -- Add compaction based on type
        local impact = scSoilCompaction.HEAVY_COMPACTION_LEVEL

        if rollerType == scSoilRoller.TYPE_CAMBRIDGE then
            impact = scSoilCompaction.MEDIUM_COMPACTION_LEVEL
        end

        setDensityParallelogram(detailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels, impact)
    end

    -- Todo: do something with grass.. !? There must a be profit somewhere for using rollers.
    -- Todo: add compaction to top soil? Only some fruits should profit from it.. so use it wisely.

    -- Todo: calculate area sum
    local areaSum = 0
    return areaSum
end

---
-- @param _
-- @param workAreas
--
function scSoilRoller:processRollerAreas(_, workAreas)
    local areaSum = 0

    for _, area in pairs(workAreas) do
        local x, z, x1, z1, x2, z2 = unpack(area)

        areaSum = areaSum + updateRollerArea(x, z, x1, z1, x2, z2)
    end

    return areaSum
end
