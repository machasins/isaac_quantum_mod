Quantum.UnseenSingularity = {}
local US = Quantum.UnseenSingularity
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

-- ID of the item
US.ID = Isaac.GetItemIdByName("Unstable Singularity")

US.HEART_VALUE = {
    [{ PickupVariant.PICKUP_HEART, HeartSubType.HEART_HALF }] = 1,
    [{ PickupVariant.PICKUP_HEART, HeartSubType.HEART_FULL }] = 2,
    [{ PickupVariant.PICKUP_HEART, HeartSubType.HEART_DOUBLEPACK }] = 4,
}
US.COIN_VALUE = {
    [{ PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY } ] = 1,
    [{ PickupVariant.PICKUP_COIN, CoinSubType.COIN_DOUBLEPACK } ] = 2,
    [{ PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL } ] = 5,
    [{ PickupVariant.PICKUP_COIN, CoinSubType.COIN_DIME } ] = 10,
    [{ PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_QUARTER }] = 25,
    [{ PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_DOLLAR }] = 99,
}
US.BOMB_VALUE = {
    [{ PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL }] = 1,
    [{ PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK }] = 2,
    [{ PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_BOOM }] = 10,
    [{ PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_PYRO }] = 99,
}
US.KEY_VALUE = {
    [{ PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL }] = 1,
    [{ PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK }] = 2,
    [{ PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_SKELETON_KEY }] = 99,
}

local sfx = SFXManager()

---Trims the pool of options based on how much is left
---@param amount integer
---@param pool table
---@return table, integer
local function cullPool(amount, pool)
    local ret = {}
    local poolsize = 0
    for k, v in pairs(pool) do
        if v <= amount then
            ret[k] = v
            poolsize = poolsize + v
        end
    end
    return ret, poolsize
end

---Inverse the weights of the pool
---@param pool table
---@return table, integer
local function inversePoolWeights(pool)
    local newPool = {}
    local poolsize = 0
    local maxDist = 0
    -- Calculate the pool size, and the maximum weight of the pool
    for k, v in pairs(pool) do
        poolsize = poolsize + v
        if v > maxDist then
            maxDist = v
        end
    end
    -- Inverse the weights of the pool
    for k, v in pairs(pool) do
        newPool[k] = (maxDist + 1) - v
    end
    return newPool, poolsize
end

---Get a weighted random index for a pool
---@param pool table
---@param poolsize integer
local function weightedRandom(pool, poolsize)
    local selection = poolsize <= 1 and 0 or math.random(1, poolsize)
    for k, v in pairs(pool) do
        selection = selection - v
        if (selection <= 0) then
            return k
        end
    end
end

---Revive when holding
---@param entity Entity
function US:OnPlayerDeath(entity)
    local player = entity:ToPlayer()
    local save = Quantum.save.GetFloorSave()
    if save and player and player:HasCollectible(US.ID) then
        -- Revive the player
        player:UseCard(Card.CARD_SOUL_LAZARUS)
        -- Stop the sound of the card from playing
        sfx:Play(SoundEffect.SOUND_SOUL_OF_LAZARUS, 0, 60)
        -- Queue the item's effects to take place after death
        QUEUE:AddCallback(5, function(t)
            return player:GetSprite():GetAnimation() ~= "Death"
        end, function (t)
            -- Trigger Mama Mega explosion
            local room = game:GetRoom()
            room:MamaMegaExplosion(player.Position)

            -- Get the total amount of pickups the player has
            local hearts = math.max(player:GetMaxHearts() - 1, 0)
            local coins = player:GetNumCoins()
            local bombs = player:GetNumBombs()
            local keys = player:GetNumKeys()

            -- Keeper's hearts are coins
            local type = player:GetPlayerType()
            if type == PlayerType.PLAYER_KEEPER or type == PlayerType.PLAYER_KEEPER_B then
                coins = coins + hearts
                hearts = 0
            end
            
            -- Remove pickups from player
            player:AddCoins(-999)
            player:AddBombs(-999)
            player:AddKeys(-999)

            -- Generate list of pickups to spawn
            local pickups = {}
            -- Correlate the amount of pickups with what it can spawn
            local types = {
                { hearts, US.HEART_VALUE },
                {  coins, US.COIN_VALUE  },
                {  bombs, US.BOMB_VALUE  },
                {   keys, US.KEY_VALUE   }
            }
            -- Loop through each pickup and randomly decide what will be spawned
            for _, pickup in pairs(types) do
                -- The amount of pickups the player had
                local amount = pickup[1]
                -- The types of items that can be spawned
                local data = pickup[2]
                -- Loop until it runs out of pickups available
                while amount > 0 do
                    -- Get the options available and the size of the pool
                    local options, size = cullPool(amount, data)
                    -- Get a random pickup from the list, bigger is more likely
                    local result = weightedRandom(options, size)
                    -- Add the pickup to the list that will be spawned
                    table.insert(pickups, result)
                    -- Reduce the amount of pickups by the value of the pickup
                    amount = amount - data[result]
                end
            end

            -- Generate how far each explored room is to the current room
            -- The current room's index
            local roomIndex = game:GetLevel():GetCurrentRoomDesc().SafeGridIndex
            -- The current room's coordinates in the grid
            local roomCoord = Vector(roomIndex % 13, math.floor(roomIndex / 13))
            -- All rooms in the level
            local rooms = game:GetLevel():GetRooms()
            -- The rooms that are cleared
            local roomList = {}
            -- Loop through every room
            for i = 0, rooms.Size - 1 do
                local r = rooms:Get(i)
                -- Check if the room is cleared
                if r.Clear then
                    -- Calculate the distance squared from the room the player is in
                    local dist = roomCoord:DistanceSquared(Vector(r.SafeGridIndex % 13, math.floor(r.SafeGridIndex / 13)))
                    -- Add the room and the distance to the list
                    roomList[r.SafeGridIndex] = dist
                end
            end

            -- Inverse the weights of the pool so that closer rooms are more likely
            local weightedRooms, roomSize = inversePoolWeights(roomList)
            -- A list of what pickups will spawn in each room
            save.RoomSpawns = save.RoomSpawns or {}
            -- Assign items to each explored room based on distance
            for _, p in pairs(pickups) do
                -- Get a random room
                local r = weightedRandom(weightedRooms, roomSize)
                -- Insert the room and the pickup to spawn in the list
                table.insert(save.RoomSpawns, { r, p })
            end
        end, QUEUE.UpdateType.Update)
        -- Remove the item from the player
        player:RemoveCollectible(US.ID)
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, US.OnPlayerDeath, EntityType.ENTITY_PLAYER)

---Spawn items in the room when available
function US:OnUpdate()
    -- The save data for the floor
    local save = Quantum.save.GetFloorSave()
    if save and save.RoomSpawns then
        -- Get the current room's index
        local roomIndex = game:GetLevel():GetCurrentRoomDesc().SafeGridIndex
        -- Loop through all pickups to spawn
        for k, v in pairs(save.RoomSpawns) do
            -- Check if that pickup should spawn in this room
            if v[1] == roomIndex then
                -- Get a random placement for the pickup somewhere within the room
                local placement = game:GetRoom():FindFreePickupSpawnPosition(Isaac.GetRandomPosition(), 5, true, false)
                -- Spawn the pickup
                Isaac.Spawn(EntityType.ENTITY_PICKUP, v[2][1], v[2][2], placement, Vector.Zero, nil)
                -- Spawn an effect for the pickup spawning
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, placement, Vector.Zero, nil)
                -- Remove the pickup from the list
                table.remove(save.RoomSpawns, k)
                -- Only spawn one pickup per frame
                -- Because removing from a list while looping through it is hard
                -- And because it looks cool
                return
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, US.OnUpdate)

if EID then
    EID:addCollectible(
        US.ID,
        "{{Collectible11}} On death: respawn with half a heart, trigger an explosion, and scatter Isaac's pickups throughout the explored floor" ..
        "#{{Card" .. Card.CARD_REVERSE_FOOL .. "}} Coins and bombs can be dropped as {{Collectible74}} The Quarter or {{Collectible19}} Boom! if possible"
    )
end

