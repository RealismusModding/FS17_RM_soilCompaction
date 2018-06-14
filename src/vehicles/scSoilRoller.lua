scSoilRoller = {}

function scSoilRoller:prerequisitesPresent(specializations)
    return true
end

function scSoilRoller:preLoad()
end

function scSoilRoller:load(savegame)
    self.processRollerAreas = Utils.overwrittenFunction(self.processRollerAreas, scSoilRoller.processRollerAreas)
end

function scSoilRoller:processRollerAreas(superfunc, workAreas)
    local areaSum = 0
    local hasWetSoil = g_currentMission.environment.groundWetness > 0.2

    if not hasWetSoil then
        return areaSum
    end

    for _, area in pairs(workAreas) do
        local x, z, x1, z1, x2, z2 = unpack(area)

        -- add compaction
        setDensityParallelogram(g_currentMission.terrainDetailId, x, z, x1, z1, x2, z2, g_currentMission.ploughCounterFirstChannel, g_currentMission.ploughCounterNumChannels, scSoilCompaction.HEAVY_COMPACTION_LEVEL)

        -- Todo: vanilla roller are function makes no sense atm.
        -- Do something with grass.. !? There must a be profit somewhere for using rollers.
        --        areaSum = areaSum + Utils.updateRollerArea(x, z, x1, z1, x2, z2)
    end

    return areaSum
end
