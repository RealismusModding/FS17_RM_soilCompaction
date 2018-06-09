----------------------------------------------------------------------------------------------------
-- Utils Script
----------------------------------------------------------------------------------------------------
-- Purpose:  Includes utilities for the soil compaction mod
-- Authors:  Wopster
--
-- Copyright (c) Realismus Modding, 2018
----------------------------------------------------------------------------------------------------

scUtils = {}

function scUtils.overwrittenStaticFunction(target, name, newFunc)
    local oldFunc = target[name]

    target[name] = function(...)
        return newFunc(oldFunc, ...)
    end
end

function logInfo(...)
    local str = "[Soil Compaction]"
    for i = 1, select("#", ...) do
        str = str .. " " .. tostring(select(i, ...))
    end
    print(str)
end

function print_r(t)
    local print_r_cache = {}
    local function sub_print_r(t, indent)
        if (print_r_cache[tostring(t)]) then
            print(indent .. "*" .. tostring(t))
        else
            print_r_cache[tostring(t)] = true
            if (type(t) == "table") then
                for pos, val in pairs(t) do
                    pos = tostring(pos)
                    if (type(val) == "table") then
                        print(indent .. "[" .. pos .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(pos) + 8))
                        print(indent .. string.rep(" ", string.len(pos) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. pos .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. pos .. "] => " .. tostring(val))
                    end
                end
            else
                print(indent .. tostring(t))
            end
        end
    end

    if (type(t) == "table") then
        print(tostring(t) .. " {")
        sub_print_r(t, "  ")
        print("}")
    else
        sub_print_r(t, "  ")
    end
    print()
end

function mathRound(value, idp)
    local mult = 10 ^ (idp or 0)
    return math.floor(value * mult + 0.5) / mult
end