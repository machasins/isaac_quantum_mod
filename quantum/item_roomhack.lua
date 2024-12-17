Quantum.RoomHack = {}
local RH = Quantum.RoomHack
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

-- ID of the item
RH.ID = Isaac.GetItemIdByName("Room Hack")

-- Maximum amount of hitpoints to consider
RH.MAX_HITPOINTS = 10000

-- How long the enemy should stay frozen
RH.FREEZE_TIME = 90
-- How many wobbles back anf forth the enemy should do
RH.FREEZE_WOBBLES = 12
-- How far the wobbles should go
RH.FREEZE_WOBBLE_DISTANCE = 3
-- How long the enemy should be still for before wobbling
RH.FREEZE_START_TIME = 0.2
-- The color when the enemy is frozen
RH.FREEZE_COLOR = Color(1,1,1,1,0.25,0.5,4)

local particleSuppression = false

---Get a weighted random index for a pool
---@param pool table
---@param poolsize integer
---@return integer
local function weightedRandom(pool, poolsize)
    local selection = math.random(1, math.ceil(poolsize))
    for k, v in pairs(pool) do
        selection = selection - v[1]
        if (selection <= 0) then
            return k
        end
    end
    return 1
end

---When the item is used
---@param id CollectibleType
---@param RNG RNG
---@param player EntityPlayer
---@param Flags any
---@param Slot any
---@param CustomVarData any
function RH:OnUseItem(id, RNG, player, Flags, Slot, CustomVarData)
    particleSuppression = true
    
    local machines = Isaac.FindByType(6,2,-1)
    for _, m in pairs(machines) do
        local LastPlayerIndex = Game():GetNumPlayers() - 1
        Isaac.ExecuteCommand("addplayer " .. PlayerType.PLAYER_BLUEBABY .. " " .. player.ControllerIndex) --spawn the dude
        local Strawman = Isaac.GetPlayer(LastPlayerIndex + 1)
        Strawman.Parent = player --required for strawman hud
        Game():GetHUD():AssignPlayerHUDs()
        local sprite = Strawman:GetSprite()
        sprite:Load("gfx/characters/adjusted_death.anm2", true)
        Strawman:AddEntityFlags(EntityFlag.FLAG_NO_BLOOD_SPLASH)
        Strawman.Visible = false
        Strawman.Position = m.Position
        Strawman.ControlsEnabled = false
        Strawman:ToPlayer():SetActiveCharge(0)
        QUEUE:AddItem(1, 0, function ()
            Strawman.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
            Strawman.GridCollisionClass = GridCollisionClass.COLLISION_NONE
        end, QUEUE.UpdateType.Render)
    end
    
    QUEUE:AddItem(10, 0, function ()
        particleSuppression = false
        for _, e in pairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, 0, 0)) do
            e:Remove()
        end
    end, QUEUE.UpdateType.Render)

    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true,
    }
end

Quantum:AddCallback(ModCallbacks.MC_USE_ITEM, RH.OnUseItem, RH.ID)

---comment
---@param Type EntityType
---@param Variant integer
---@param SubType integer
---@param Position Vector
---@param Velocity Vector
---@param Spawner Entity
---@param Seed integer
function RH:ParticleSuppress(Type, Variant, SubType, Position, Velocity, Spawner, Seed)
    if particleSuppression and Type == EntityType.ENTITY_EFFECT and Variant == EffectVariant.BLOOD_PARTICLE and Spawner.Type == EntityType.ENTITY_PLAYER then
        return { EntityType.ENTITY_EFFECT, 0, 0, Seed }
    end
    if particleSuppression and Type == EntityType.ENTITY_EFFECT and Variant == EffectVariant.BLOOD_EXPLOSION then
        return { EntityType.ENTITY_EFFECT, 0, 0, Seed }
    end
end

Quantum:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, RH.ParticleSuppress)

if EID then
    EID:addCollectible(
        RH.ID,
        "#{{Freezing}} Freezes one non-boss enemy in the room for 3 seconds" ..
        "#{{Charm}} After unfreezing, the enemy is permanently charmed" ..
        "#{{DiceRoom}} Chooses enemies to freeze randomly, weighted based on health. The more health an enemy has, the less likely to be chosen"
    )
end