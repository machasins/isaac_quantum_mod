Quantum.ArtificalBloom = {}
local WB = Quantum.ArtificalBloom
local game = Game()

-- ID of the item
WB.ID = Isaac.GetItemIdByName("Worm Bucket")

WB.WORM_POOL = {
    {10, TrinketType.TRINKET_FLAT_WORM},
    {10, TrinketType.TRINKET_HOOK_WORM},
    {10, TrinketType.TRINKET_WHIP_WORM},
    {10, TrinketType.TRINKET_RING_WORM},
    {10, TrinketType.TRINKET_TAPE_WORM},
    {10, TrinketType.TRINKET_PULSE_WORM},
    {10, TrinketType.TRINKET_WIGGLE_WORM},
    { 5, TrinketType.TRINKET_OUROBOROS_WORM},
    { 2, TrinketType.TRINKET_LAZY_WORM},
    { 1, TrinketType.TRINKET_BRAIN_WORM},
    { 1, TrinketType.TRINKET_RAINBOW_WORM},
}

---Get the size of the trinket pool
---@param pool table
---@return integer
local function getPoolSize(pool)
    local poolsize = 0
    for _, v in pairs(pool) do
        poolsize = poolsize + v[1]
    end
    return poolsize
end

---Get a weighted random index for a pool
---@param pool table
---@param poolsize integer
---@return integer
local function weightedRandom(pool, poolsize)
    local selection = math.random(1, poolsize)
    for k, v in pairs(pool) do
        selection = selection - v[1]
        if (selection <= 0) then
            return k
        end
    end
    return 1
end

---Get the pool of trinkets that should be used
---@return table
function WB:RemoveLockedTrinkets()
    local pennyList = {}
    for _, t in pairs(WB.WORM_POOL) do
        if Isaac.GetItemConfig():GetTrinket(t[2]):IsAvailable() then
            table.insert(pennyList, t)
        end
    end
    return pennyList
end

---When the item is used
---@param id CollectibleType
---@param RNG RNG
---@param player EntityPlayer
---@param Flags any
---@param Slot any
---@param CustomVarData any
function WB:OnUseItem(id, RNG, player, Flags, Slot, CustomVarData)
    -- Get a spawn position for the trinkets
    local location = game:GetRoom():FindFreePickupSpawnPosition(player.Position, 0, true, false)
    -- Get offset positions for multiple trinkets
    local locationList = {
        [1] = location + Vector( 0, 0),
        [2] = location + Vector(40, 0),
        [3] = location - Vector(40, 0),
    }
    -- The amount of trinkets that will spawn
    local amount = math.random(1, 3)
    -- The options index for each trinket
    local options = RNG:Next()
    -- The list of possible trinkets based on what is unlocked
    local possibleTrinkets = WB:RemoveLockedTrinkets()
    -- The total pool size of the weighted pool
    local poolsize = getPoolSize(possibleTrinkets)
    -- For each trinket that should be summoned
    for i = 1, amount do
        -- Get a random trinket type
        local randomIndex = weightedRandom(possibleTrinkets, poolsize)
        -- The type that should be spawned
        local type = possibleTrinkets[randomIndex][2]
        -- Reduce the size of the pool
        poolsize = poolsize - possibleTrinkets[randomIndex][1]
        -- Remove the trinket from the pool to stop duplicates in the same spawn
        table.remove(possibleTrinkets, randomIndex)
        -- Spawn the trinket
        local t = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, type, locationList[i], Vector.Zero, player)
        -- Set the options index to the random number
        t:ToPickup().OptionsPickupIndex = options
        -- Remove this trinket from the normal pool of trinkets
        game:GetItemPool():RemoveTrinket(type)
    end
    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true,
    }
end

Quantum:AddCallback(ModCallbacks.MC_USE_ITEM, WB.OnUseItem, WB.ID)

if EID then
    EID:addCollectible(
        WB.ID,
        "#{{Coin}} Spawns 1-3 coin trinkets on use#{{Warning}} Can only pick up one"
    )
end