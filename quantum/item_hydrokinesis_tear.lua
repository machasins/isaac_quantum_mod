local HK = Quantum.Hydrokinesis

---@class UTILS
local UTILS = HK.UTILS
local LUCK = HK.Luck

local TEAR = HK.Tear
TEAR.normal = {}
TEAR.spawned = {}

local game = Game()

---Retrieve data from the intial tear to apply to the spawned tear
---@param tear EntityTear The inital tear
---@param hash number The hash of the spawned tear
---@param player EntityPlayer 
local function RetrieveSpawnedTearData(tear, hash, player)
    -- Initalize data
    TEAR.spawned[hash] = {}
    -- Set the target tear scale
    TEAR.spawned[hash].originalScale = tear.BaseScale * TEAR.SCALE
    -- Keep track of the original falling acceleration
    TEAR.spawned[hash].originalFallingAcceleration = tear.FallingAcceleration
    -- Keep track of the position offset from the player
    TEAR.spawned[hash].offsetPosition = tear.Position - tear.SpawnerEntity.Position
    -- Keep track of the original tear height
    TEAR.spawned[hash].originalHeight = tear.Height
    -- Keep track of the original tear alpha
    TEAR.spawned[hash].originalAlpha = tear:GetSprite().Color.A
    local flagsToRemove = BitSet128(0,0)
    -- Get all flags that should be removed from the tear
    for _, f in pairs(TEAR.FLAG_REMOVE_LIST) do
        if tear:HasTearFlags(f) then
            flagsToRemove = flagsToRemove | f
        end
    end
    local flagsToReAdd = BitSet128(0,0)
    -- Get all the flags that should be removed from the tear, but should be readded when fired
    for _, f in pairs(TEAR.FLAG_READD_LIST) do
        if tear:HasTearFlags(f) then
            flagsToReAdd = flagsToReAdd | f
        end
    end
    -- Clear the flags that the tear should not have
    tear:ClearTearFlags(flagsToRemove | flagsToReAdd)
    -- Keep track of the flags that should be readded
    TEAR.spawned[hash].originalTearFlags = flagsToReAdd
end

---Handles spawning a new tear
---@param tear EntityTear
---@param player EntityPlayer The player
---@param position Vector The position the tear should spawn in
local function SpawnTear(tear, player, position)
    -- Create the tear
    local newTear = Isaac.Spawn(tear.Type, tear.Variant, tear.SubType, position, Vector.Zero, player):ToTear()
    if newTear then
        -- The hash of the new tear
        local hash = newTear.Index
        -- The player's tear data
        local playerTearData = player:GetTearHitParams(tear.Variant == TearVariant.FETUS and WeaponType.WEAPON_FETUS or WeaponType.WEAPON_TEARS)
        -- Set relevant data on new tear
        newTear:ChangeVariant(tear.Variant)
        newTear.Parent = player
        newTear.Height = playerTearData.TearHeight
        newTear.Scale = playerTearData.TearScale
        newTear.CollisionDamage = tear.CollisionDamage * TEAR.DAMAGE
        newTear.TearFlags = playerTearData.TearFlags | tear.TearFlags
        newTear.Friction = tear.Friction
        newTear.HomingFriction = tear.HomingFriction
        newTear.Color = playerTearData.TearColor
        -- Save relevant data
        RetrieveSpawnedTearData(newTear, hash, player)
        -- Make sure tear can go through obstacles
        newTear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
        -- Initalize the tear's spawning animation
        newTear.FallingAcceleration = 0
        newTear.Scale = 0
        UTILS.ChangeSpriteAlpha(newTear:GetSprite(), 0)
        newTear.Height = TEAR.INITIAL_HEIGHT
        newTear.Velocity = Vector(0,0.000001)
    end
end

---Update for the spawning animation
---@param tear EntityTear
---@param tearData table
local function HandleSpawnAnimation(tear, tearData)
    -- Lerp the scale of the tear
    tear.Scale = UTILS.Lerp(0, tearData.originalScale, tear.FrameCount / TEAR.SPAWN_TIME)
    -- Lerp the alpha of the tear
    UTILS.ChangeSpriteAlpha(tear:GetSprite(), UTILS.Lerp(0, tearData.originalAlpha, tear.FrameCount / TEAR.SPAWN_TIME * 1.5))
    -- Make sure the tear doesn't fall
    tear.FallingAcceleration = -0.1
    tear.FallingSpeed = 0
    -- Lerp the movement of the tear, going upwards
    tear.Height = UTILS.Lerp(TEAR.INITIAL_HEIGHT, tearData.originalHeight, (tear.FrameCount + 1) / (TEAR.SPAWN_TIME - 1))
end

---Fire the tear at the nearest enemy
---@param tear any
---@param player any
local function HandleTearShot(tear, player)
    -- The nearest enemy to the tear
    local enemy = UTILS.GetNearestEntity(tear.Position, nil)
    -- The velocity of the tear
    local velocity = Vector.Zero
    -- Check if there is an enemy
    if enemy ~= nil then
        -- Shoot the tear towards the enemy
        velocity = (enemy.Position - tear.Position):Normalized()
    else
        -- Shoot the tear in the direction the player is shooting
        velocity = player:GetAimDirection():Normalized()
    end
    -- Handle the tear following the player and the tear has no enemy to shoot
    if TEAR.FOLLOW_PLAYER and velocity:LengthSquared() < 0.01 then
        -- Fire the tear in the opposite direction of the player
        velocity = (tear.Position - player.Position):Normalized()
    end
    -- Fire the tear with the correct shot speed
    tear.Velocity = velocity * player.ShotSpeed * 10
end

---Update any spawned tears
---@param tear any
---@param hash any
---@param player any
local function HandleSpawnedTear(tear, hash, player)
    -- The tear data that is being tracked
    local tearData = TEAR.spawned[hash]
    -- Handle spawning animation
    if tear.FrameCount <= TEAR.SPAWN_TIME then
        HandleSpawnAnimation(tear, tearData)
    end
    -- Handle time between spawning animation and firing the tear
    if tear.FrameCount > TEAR.SPAWN_TIME and tear.FrameCount < TEAR.FIRE_TIME then
        -- Make the tear hover in the air
        tear.FallingAcceleration = -0.1
        tear.FallingSpeed = 0
        tear.Height = tearData.originalHeight
    end
    -- Handle following the player before firing the tear, if set
    if TEAR.FOLLOW_PLAYER and tear.FrameCount < TEAR.FIRE_TIME then
        -- The position the tear should be in
        local realPos = tear.SpawnerEntity.Position + tearData.offsetPosition
        -- Move the tear towrds where it should be
        tear.Velocity = (realPos - tear.Position) * TEAR.FOLLOW_SPEED
    end
    -- Handle firing the tear
    if tear.FrameCount == TEAR.FIRE_TIME then
        -- Reset falling acceleration
        tear.FallingAcceleration = tearData.originalFallingAcceleration
        -- Readd any tear flags that need to be readded
        tear:AddTearFlags(tearData.originalTearFlags)
        -- Fire the tear
        HandleTearShot(tear, player)
    end
end

---Runs every update frame for each tear
---@param tear EntityTear
function HK:OnTearCreate(tear)
    -- The hash of the tear
    local hash = tear.Index
    -- If the tear has been marked to not spawn more tears
    if TEAR.normal[hash] == false then return end

    -- The player the tear was fired from
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer() or nil
    -- Check if the player exists and if the player has the item
    if not (player and player:HasCollectible(HK.ID)) then return end

    -- Check if the tear was spawned by another tear
    if TEAR.spawned[hash] ~= nil then
        -- Handle the spawned tear (animations, firing)
        HandleSpawnedTear(tear, hash, player)
        -- Do not run further code
        return
    end

    -- Check if the tear is continuously spawning tears and should try to spawn one this frame
    if TEAR.normal[hash] and (HK.hasSpawned or not tear:IsFrame(HK.CONT_SPAWNED_COOLDOWN, 1)) then return end

    -- If the tear is a Ludovico tear
    local isLudo = tear:HasTearFlags(TearFlags.TEAR_LUDOVICO)

    -- The player's tear flags
    local playerTearFlags = player:GetTearHitParams(tear.Variant == TearVariant.FETUS and WeaponType.WEAPON_FETUS or WeaponType.WEAPON_TEARS).TearFlags
    -- Make sure tears match the flags that should match (stops tears that spawn more tears from repeating infinitely)
    if not UTILS.DoTearFlagsMatch(playerTearFlags, tear.TearFlags, TEAR.FLAG_MATCH_LIST) then
        -- Mark this tear as a tear that should not be updated
        TEAR.normal[hash] = false
        -- Do not run further code
        return
    end

    -- The spawn chance for tears for the player (Luck and room size based)
    local spawnChance = UTILS.GetLuckChance(player.Luck,
        LUCK.BASE_CHANCE + LUCK.ADD_CHANCE * (player:GetCollectibleNum(HK.ID) - 1),
        LUCK.MULTIPLIER,
        LUCK.MIN_CHANCE,
        LUCK.MAX_CHANCE
    ) * (HK.ROOM_MULTIPLIER[game:GetLevel():GetCurrentRoom():GetRoomShape()] or 1)
    -- The RNG object for the item
    local rng = player:GetCollectibleRNG(HK.ID)
    -- Roll to see if tear can be spawned
    local chance = rng:RandomFloat()
    if chance > spawnChance then
        -- Tear did not pass roll, mark tear appropriately (Ludo tears should be able to spawn multiple, otherwise do not run again for this tear)
        TEAR.normal[hash] = isLudo
        -- Do not run further code
        return
    end

    -- The random position the tear should spawn at
    local randomPos = Vector.Zero
    -- Handle if the tear should follow the player
    if TEAR.FOLLOW_PLAYER then
        -- Generate a random position around the player
        randomPos = player.Position +
            rng:RandomVector() * (rng:RandomInt(2) * 2 - 1) * (TEAR.SPAWN_MIN_DISTANCE + rng:RandomFloat() * (TEAR.SPAWN_MAX_DISTANCE - TEAR.SPAWN_MIN_DISTANCE))
    else
        -- Get a random position in the room
        randomPos = game:GetLevel():GetCurrentRoom():GetRandomPosition(1)
    end
    -- Spawn the tear
    SpawnTear(tear, player, randomPos)

    -- If the tear is a Ludo tear, set hasSpawned
    HK.hasSpawned = HK.hasSpawned or isLudo
    -- Mark the tear appropriately
    TEAR.normal[hash] = isLudo
end

---Runs when any entity is removed from the room
---@param ent Entity
function HK:OnTearRemove(ent)
    -- The hash of the entity
    local hash = ent.Index
    -- Remove from the normal list, if available
    if TEAR.normal[hash] then
        TEAR.normal[hash] = nil
    end
    -- Remove from the spawned list, if available
    if TEAR.spawned[hash] ~= nil then
        TEAR.spawned[hash] = nil
    end
end

---Runs when entering a new room
function HK:ResetTear()
    TEAR.normal = {}
    TEAR.spawned = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, HK.OnTearCreate)
Quantum:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, HK.OnTearRemove)
Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, HK.ResetTear)