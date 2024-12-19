---@class UTILS
local utils = {}


---Get the chance something should happen, based on the player's luck
---@param playerLuck number The player's luck
---@param baseChance number The base chance for something to happen
---@param luckMultiplier number How much addition chance per luck point the player has
---@param minChance number The minimum chance of something happening
---@param maxChance number The maximum chance of something happening
---@return number
function utils.GetLuckChance(playerLuck, baseChance, luckMultiplier, minChance, maxChance)
    return math.min(math.max(baseChance + luckMultiplier * playerLuck, minChance), maxChance)
end

---Interpolate between two values based on time (Clamped between 0 and 1)
---@param a number Start
---@param b number End
---@param t number Time
---@return number
function utils.Lerp(a, b, t)
    return a + (b - a) * math.min(math.max(t, 0.0), 1.0)
end

---Interpolate between two angles based on time (Clamped between 0 and 1)
---@param a number Start
---@param b number End
---@param t number Time
---@return number
function utils.AngleLerp(a, b, t)
    local diff = (((b - a) + 180) % 360) - 180
    return (a + diff * math.min(math.max(t, 0.0), 1.0)) % 360
end

---Interpolate between two vectors based on time
---@param a Vector Start
---@param b Vector End
---@param t number Time
---@return Vector
function utils.LerpV(a, b, t)
    return a + (b - a) * t
end

---Interpolate between two values based on time (Unclamped, t can be any value)
---@param a number Start
---@param b number End
---@param t number Time
---@return number
function utils.LerpUnclamped(a, b, t)
    return a + (b - a) * t
end

---Check if two tear flags match
---@param tearFlagsA TearFlags
---@param tearFlagsB TearFlags
---@param flagsToCheck TearFlags[]|nil Which flags should be checked for equality
---@return boolean result Whether the tear flags match
function utils.DoTearFlagsMatch(tearFlagsA, tearFlagsB, flagsToCheck)
    -- The flags that should be checked
    flagsToCheck = flagsToCheck or TearFlags
    -- Loop through all flags
    for _, flag in pairs(flagsToCheck) do
        -- Check to see if both have the flag
        if tearFlagsA & flag ~= tearFlagsB & flag then
            -- Flag mismatch, return false
            return false
        end
    end
    -- All flags matched, return true
    return true
end

---Get the player's weapon type
---@param player EntityPlayer
---@param viableOptions WeaponType[] Which weapon types the function should ber able to return (ORDERED)
---@param default WeaponType The default value that sould be returned if none matched
---@return WeaponType
function utils.GetPlayerWeaponType(player, viableOptions, default)
    -- The weapon types that should be checked
    viableOptions = viableOptions or WeaponType
    -- Loop through all weapon types
    for _, val in pairs(viableOptions) do
        -- Check if the player has the weapon type
        if player:HasWeaponType(val) then
            -- Return the weapon type
            return val
        end
    end

    -- None matched, return default
    return default
end

---Check if any player has the collectible
---@param id CollectibleType The collectible to check for
function utils.AnyPlayerHasCollectible(id)
    -- The amount of players in the game
    local playerNum = Game():GetNumPlayers()
    -- Loop through every player
    for i = 0, playerNum - 1 do
        -- The player to check
        local player = Isaac.GetPlayer(i)
        -- Check if the player has the collectible
        if player:HasCollectible(id) then
            -- Someone has the collectible, return true
            return true
        end
    end

    -- No one had the collectible, return false
    return false
end

---Run a callback for every player that has a collectible
---@param id CollectibleType The collectible to check for
---@param func function(EntityPlayer) The function to run
function utils.ForEveryPlayerHasCollectible(id, func)
    -- The amount of players in the game
    local playerNum = Game():GetNumPlayers()
    -- Loop through every player
    for i = 0, playerNum - 1 do
        -- The player to check
        local player = Isaac.GetPlayer(i)
        -- Check if the player has the collectible
        if player:HasCollectible(id) then
            -- Run the function
            func(player)
        end
    end
end

---Get the first player that has the collectible
---@param id CollectibleType
---@return EntityPlayer? player The player that has the collectible or nil if no players have the collectible
function utils.GetPlayerHasCollectible(id)
    -- The amount of players in the game
    local playerNum = Game():GetNumPlayers()
    -- Loop through every player
    for i = 0, playerNum - 1 do
        -- The player to check
        local player = Isaac.GetPlayer(i)
        -- Check if the player has the collectible
        if player:HasCollectible(id) then
            -- Return the player that has the collectible
            return player
        end
    end

    -- No player had the collectible, return nil
    return nil
end

---Get how many collectibles all players have collectively
---@param id CollectibleType
---@return number num The amount of copies of the collecible
function utils.GetPlayerCollectibleNum(id)
    -- The amount of collectibles
    local ret = 0
    -- The number of players in the game
    local playerNum = Game():GetNumPlayers()
    -- Loop through every player
    for i = 0, playerNum - 1 do
        -- The player to check
        local player = Isaac.GetPlayer(i)
        -- Add the player's amount of the collectible to the total
        ret = ret + player:GetCollectibleNum(id)
    end

    -- Return the amount of collectibles
    return ret
end

---Get the player with the highest specified stat
---@param stat string The stat to return (Should be in the form of a EntityPlayer variable)
---@param id? CollectibleType Only include players that have this collectible
---@return number highestStat The highest stat of any player
function utils.GetHighestPlayerStat(stat, id)
    -- The highest stat
    local ret = math.mininteger
    -- The total number of players in the game
    local playerNum = Game():GetNumPlayers()
    -- Loop trhough every player
    for i = 0, playerNum - 1 do
        -- The player to check
        local player = Isaac.GetPlayer(i)
        -- The player's stat
        local playerStat = player[stat]
        -- Check if the collectible id was specified and if the player has the collectible
        if (id and player:HasCollectible(id)) or id == nil then
            -- Set the highest stat if the player's stat is higher
            ret = ret < playerStat and playerStat or ret
        end
    end

    -- Return the highest stat
    return ret
end

---Get the collectible RNG object of the first player that has the collectible
---@param id CollectibleType
---@return RNG
function utils.GetCollectibleRNG(id)
    -- The amount of players int he game
    local playerNum = Game():GetNumPlayers()
    -- Loop through every player
    for i = 0, playerNum - 1 do
        -- The player to check
        local player = Isaac.GetPlayer(i)
        -- Check if the player has the collectible
        if player:HasCollectible(id) then
            -- Return the RNG object
            return player:GetCollectibleRNG(id)
        end
    end

    -- No one had the collectible
    -- Return the RNG object of the collectible using the first player
    return Isaac.GetPlayer():GetCollectibleRNG(id)
end

---Check if the entity given is a targetable enemy
---@param entity Entity
---@return boolean
function utils.IsTargetableEnemy(entity)
    -- Returns true if the enemy is active, not dead, and vulnerable
    return entity:IsActiveEnemy(false) and entity:IsVulnerableEnemy()
end

---Get the nearest entity to a position
---@param position Vector 
---@param default Entity|nil The entity to default to if no valid entity was found
---@param condFunc (fun(e: Entity): boolean)|nil The condition function, determines whether an entity is valid
---@param rankFunc (fun(e: Entity): number)|nil The rank funciton, adds onto the distance to make undesirable entites less likely to be returned
---@return Entity|nil
function utils.GetNearestEntity(position, default, condFunc, rankFunc)
    -- The condition funciton, initalized to targetable enemies
    condFunc = condFunc or utils.IsTargetableEnemy
    -- The ranking function, intialiazed to return 0
    rankFunc = rankFunc or function(e) return 0 end

    -- All entities in the room
    local ent = Isaac.GetRoomEntities()
    -- The closest entity, defaulted to the given default
    local closest = default
    -- The distance to the closest entity
    local closestDistance = math.maxinteger
    -- Loop through all entites in the room
    for _, e in pairs(ent) do
        -- Check if the entity passes the condition funciton
        if condFunc(e) then
            -- Compute the distance from the position, with additional ranking funciton
            local distance = position:Distance(e.Position) + rankFunc(e)
            -- Check if the distance is shorter
            if distance < closestDistance then
                -- Set the new closest entity and distance
                closest = e
                closestDistance = distance
            end
        end
    end
    -- Return the closest entity to the position
    return closest
end

---Get the entity in the room with the given index
---@param index integer The index to find
---@param entities Entity[]|nil The entities to check
---@return Entity|nil
function utils.GetEntityWithIndex(entities, index)
    entities = entities or Isaac.GetRoomEntities()
    -- Loop through all the entities
    for _, e in pairs(entities) do
        -- Check if the index matched
        if e.Index == index then
            -- Found the entity
            return e
        end
    end
    -- Entity not found
    return nil
end

---Change the sprite's alpha
---@param sprite Sprite
---@param alpha number
function utils.ChangeSpriteAlpha(sprite, alpha)
    sprite.Color = Color(sprite.Color.R, sprite.Color.G, sprite.Color.B, alpha, sprite.Color.RO, sprite.Color.GO, sprite.Color.BO)
end

---@return UTILS
return utils