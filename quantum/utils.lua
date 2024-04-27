---@class UTILS
local utils = {}


---comment
---@param playerLuck number
---@param baseChance number
---@param luckMultiplier number
---@param minChance number
---@param maxChance number
---@return number
function utils.GetLuckChance(playerLuck, baseChance, luckMultiplier, minChance, maxChance)
    return math.min(math.max(baseChance + luckMultiplier * playerLuck, minChance), maxChance)
end

---comment
---@param a number Start
---@param b number End
---@param t number Time
---@return number
function utils.Lerp(a, b, t)
    return a + (b - a) * math.min(math.max(t, 0.0), 1.0)
end

---comment
---@param a number Start
---@param b number End
---@param t number Time
---@return number
function utils.LerpUnclamped(a, b, t)
    return a + (b - a) * t
end

---comment
---@param tearFlagsA TearFlags
---@param tearFlagsB TearFlags
---@param flagsToCheck TearFlags[]|nil
---@return boolean
function utils.DoTearFlagsMatch(tearFlagsA, tearFlagsB, flagsToCheck)
    flagsToCheck = flagsToCheck or TearFlags
    for _, flag in pairs(flagsToCheck) do
        if tearFlagsA & flag ~= tearFlagsB & flag then
            return false
        end
    end
    return true
end

---comment
---@param player EntityPlayer
---@param viableOptions WeaponType[]
---@param default WeaponType
---@return WeaponType
function utils.GetPlayerWeaponType(player, viableOptions, default)
    viableOptions = viableOptions or WeaponType
    for _, val in pairs(viableOptions) do
        if player:HasWeaponType(val) then
            return val
        end
    end

    return default
end

---comment
---@param entity Entity
---@return boolean
function utils.IsTargetableEnemy(entity)
    return entity:IsActiveEnemy(false) and entity:IsVulnerableEnemy()
end

---comment
---@param position Vector
---@param default Entity|nil
---@param condFunc (fun(e: Entity): boolean)|nil
---@param rankFunc (fun(e: Entity): number)|nil
---@return Entity|nil
function utils.GetNearestEntity(position, default, condFunc, rankFunc)
    condFunc = condFunc or utils.IsTargetableEnemy
    rankFunc = rankFunc or function(e) return 0 end

    local ent = Isaac.GetRoomEntities()
    local closest = default
    local closestDistance = math.maxinteger
    for _, e in pairs(ent) do
        if condFunc(e) then
            local distance = position:Distance(e.Position) + rankFunc(e)
            if distance < closestDistance then
                closest = e
                closestDistance = distance
            end
        end
    end
    return closest
end

---@return UTILS
return utils