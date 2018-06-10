----------------------------------------------------------------------------------------------------
-- Debug
----------------------------------------------------------------------------------------------------
-- Purpose:  Includes debug tools
-- Authors:  Wopster, reallogger
--
-- Copyright (c) Realismus Modding, 2018
----------------------------------------------------------------------------------------------------

scDebugUtil = {}

function scDebugUtil.drawDensityParallelogram(x, z, wX, wZ, hX, hZ, offsetY, r, g, b)
    local node = g_currentMission.terrainRootNode

    drawDebugLine(x,
        getTerrainHeightAtWorldPos(node, x, 0, z) + offsetY,
        z,
        r, g, b,
        x + wX,
        getTerrainHeightAtWorldPos(node, x + wX, 0, z + wZ) + offsetY,
        z + wZ,
        r, g, b)

    drawDebugLine(x,
        getTerrainHeightAtWorldPos(node, x, 0, z) + offsetY,
        z,
        r, g, b,
        x + hX,
        getTerrainHeightAtWorldPos(node, x + hX, 0, z + hZ) + offsetY,
        z + hZ,
        r, g, b)

    drawDebugLine(x + wX + hX,
        getTerrainHeightAtWorldPos(node, x + wX + hX, 0, z + wZ + hZ) + offsetY,
        z + wZ + hZ,
        r, g, b,
        x + wX,
        getTerrainHeightAtWorldPos(node, x + wX, 0, z + wZ) + offsetY,
        z + wZ,
        r, g, b)

    drawDebugLine(x + wX + hX,
        getTerrainHeightAtWorldPos(node, x + wX + hX, 0, z + wZ + hZ) + offsetY,
        z + wZ + hZ,
        r, g, b,
        x + hX,
        getTerrainHeightAtWorldPos(node, x + hX, 0, z + hZ) + offsetY,
        z + hZ,
        r, g, b)
end