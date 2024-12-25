Quantum.ClumpedPenny = {}
local CP = Quantum.ClumpedPenny
local game = Game()

---@class UTILS
local UTILS = Quantum.UTILS

BloodClotSubType = BloodClotSubType or {
    RED = 0,
    SOUL = 1,
    BLACK = 2,
    ETERNAL = 3,
    GOLD = 4,
    BONE = 5,
    ROTTEN = 6,
    RED_NO_SUMPTORIUM = 7,
}

-- ID of the item
CP.ID = Isaac.GetTrinketIdByName("Clumped Penny")
CP.SPAWN_SPEED = 2
CP.SPAWN_AMOUNT = 2

CP.SOUL_HEARTS_ONLY = {
    [PlayerType.PLAYER_BLUEBABY] = true,
    [PlayerType.PLAYER_THESOUL] = true,
    [PlayerType.PLAYER_THESOUL_B] = true,
    [PlayerType.PLAYER_THEFORGOTTEN_B] = true,
    [PlayerType.PLAYER_BETHANY_B] = true,
}

CP.BLACK_HEARTS_ONLY = {
    [PlayerType.PLAYER_BLACKJUDAS] = true,
    [PlayerType.PLAYER_JUDAS_B] = true,
}

CP.NO_HEATLH = {
    [PlayerType.PLAYER_THELOST] = true,
    [PlayerType.PLAYER_THELOST_B] = true,
}

CP.COIN_HEARTS_ONLY = {
    [PlayerType.PLAYER_KEEPER] = true,
    [PlayerType.PLAYER_KEEPER_B] = true,
}

CP.BONE_HEARTS_ONLY = {
    [PlayerType.PLAYER_THEFORGOTTEN] = true,
}

local coinCollideList = {}

---comment
---@param player EntityPlayer
function CP:HandleSpawningClots(player)
    if player:GetHearts() + player:GetSoulHearts() > 1 then
        local type = player:GetPlayerType()
        if type ~= PlayerType.PLAYER_THELOST and type ~= PlayerType.PLAYER_THELOST_B then
            local damageFlags = DamageFlag.DAMAGE_NO_MODIFIERS | DamageFlag.DAMAGE_INVINCIBLE | DamageFlag.DAMAGE_NO_PENALTIES
            player:ResetDamageCooldown()
            player:TakeDamage(1, damageFlags, EntityRef(player), 0)
        end
        local subtype = BloodClotSubType.RED
        if CP.SOUL_HEARTS_ONLY[type] then
            -- Soul hearts only
            subtype = BloodClotSubType.soul
        elseif CP.BLACK_HEARTS_ONLY[type] then
            -- Black hearts only
            subtype = BloodClotSubType.BLACK
        elseif CP.NO_HEATLH[type] then
            -- No health, eternal hearts
            subtype = BloodClotSubType.ETERNAL
        elseif CP.COIN_HEARTS_ONLY[type] then
            -- Coin health only
            subtype = BloodClotSubType.GOLD
        elseif CP.BONE_HEARTS_ONLY[type] then
            -- Bone hearts only
            subtype = BloodClotSubType.BONE
        end
        local function SpawnClot()
            local pos = player.Position
            local vel = Vector(1,0):Rotated(math.random(0, 359)) * CP.SPAWN_SPEED
            return Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLOOD_BABY, subtype, pos, vel, player)
        end
        for _ = 1, CP.SPAWN_AMOUNT do
            SpawnClot()
        end
    end
end

---Runs when anything collides with a pickup
---@param pickup EntityPickup
---@param entity Entity
function CP:OnPickupCollide(pickup, entity)
    local player = entity:ToPlayer()
    if player and pickup.Variant == PickupVariant.PICKUP_COIN then
        local itemCount = player:GetTrinketMultiplier(CP.ID)
        if itemCount > 0 then
            table.insert(coinCollideList, { pickup, itemCount, player })
        end
    end
end
Quantum:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, CP.OnPickupCollide)

---Run every update frame
function CP:OnUpdate()
    -- Loop through the coins that have been collided with
    for _, pickupData in ipairs(coinCollideList) do
        local coin = pickupData[1]
        local multiplier = pickupData[2]
        local player = pickupData[3]
        -- Check if the coin is playing it's collection animation
        local value = coin:GetCoinValue() / 5
        if coin:IsDead() and math.random(1, 6) <= multiplier + value then
            CP:HandleSpawningClots(player)
        end
    end
    coinCollideList = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, CP.OnUpdate)

if EID then
    EID:addTrinket(
        CP.ID,
        "{{Trinket" .. TrinketType.TRINKET_LIL_CLOT .. "}} Picking up a coin has a 16.7% chance to spawn 2 blood clots" ..
        "#Higher chance from nickels and dimes "
    )
    EID:addGoldenTrinketMetadata(
        CP.ID,
        "",
        16.7,
        3
    )
end