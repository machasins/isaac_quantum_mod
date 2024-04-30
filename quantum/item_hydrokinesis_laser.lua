local HK = Quantum.Hydrokinesis

---@class UTILS
local UTILS = HK.UTILS
local LUCK = HK.Luck

local LASER = HK.Laser
LASER.normal = {}
LASER.effect = {}
LASER.spawned = {}

local game = Game()

---Save data needed for spawning the laser
---@param effect EntityEffect The current effect
---@param hash number The hash value for the effect
---@param laser EntityLaser The laser that triggered the effect
---@param colorLaser EntityLaser The laser that generates color information
---@param laserType TYPE The type of the laser
---@param player EntityPlayer The player that spawned the effect
local function RetrieveSpawnedEffectData(effect, hash, laser, colorLaser, laserType, player)
    -- Initialize data
    LASER.effect[hash] = {}
    LASER.effect[hash].player = player         -- Keep track of the player that spawned the laser
    LASER.effect[hash].laser = laser           -- Keep track of the inital laser
    LASER.effect[hash].colorLaser = colorLaser -- Keep track of the colored laser
    LASER.effect[hash].laserType = laserType   -- Keep track of the type of the laser
    -- Keep track of the inital color of the laser
    LASER.effect[hash].laserColor = colorLaser:GetSprite().Color
    -- Remove any spawner entity to stop any AntiGrav callbacks
    effect.SpawnerEntity = nil
    -- Set the length of the effect
    effect:SetTimeout(LASER.TIME[laserType].FIRE + LASER.WEAPON_EFFECT_ADD_LENGTH[laserType])
    -- Retrieve the flags from the laser that spawned this effect
    local playerTearEffects = LASER.effect[hash].laser.TearFlags
    -- Compile all the flags that should be removed
    local flagsToRemove = BitSet128(0,0)
    for _, f in pairs(LASER.FLAG_REMOVE_LIST) do
        flagsToRemove = flagsToRemove | f
    end
    -- Remove the flags from the inital laser, for use when spawning the laser
    LASER.effect[hash].removeFlags = playerTearEffects & flagsToRemove
    -- For use if laser follows the player, sets original offset
    LASER.effect[hash].offsetPosition = effect.Position - player.Position
end

---Sets all data that needs to for the Colored laser
---@param colorLaser EntityLaser The laser spawned for color data
---@param hash number The hash of the laser
---@param laser EntityLaser The inital laser
---@param laserType TYPE The type of the laser
---@param player EntityPlayer The player
local function RetrieveSpawnedLaserData(colorLaser, hash, laser, laserType, player)
    -- Initalize data
    LASER.spawned[hash] = {}
    -- Keep track of the player that spawned this laser
    LASER.spawned[hash].player = player
    -- Set the timeout for the laser [Function definition is incorrect]
---@diagnostic disable-next-line: param-type-mismatch
    colorLaser:SetTimeout(LASER.TIME[laserType].FIRE + 60)
    -- Adjust the tear flags of the laser
    colorLaser:AddTearFlags(laser.TearFlags)
    for _, f in pairs(LASER.FLAG_MATCH_LIST) do
        colorLaser:ClearTearFlags(f)
    end
    -- Set the inital color of the laser
    colorLaser:GetSprite().Color = laser:GetSprite().Color
    colorLaser:GetSprite().Color.A = 1.0
    -- Disable the laser from being viewed
    colorLaser.Visible = false
end

---Sets the color of the effects so it matches the laser
---@param effect EntityEffect The effect to colorize
local function SetEffectColor(effect)
    -- Get the effect's data
    local effectData = LASER.effect[effect.Index]
    -- Set the effect's color to the color of the colorLaser
    effect:GetSprite().Color = effectData.colorLaser:GetSprite().Color
    -- Control intial spawn alpha
    if effect.FrameCount <= LASER.TIME[effectData.laserType].SPAWN then
        effect:GetSprite().Color.A = UTILS.Lerp(0, 1, effect.FrameCount / LASER.TIME[effectData.laserType].SPAWN * 2)
    end
end

---In charge of spawning the effect before the laser
---@param laser EntityLaser The inital laser
---@param player EntityPlayer The player
---@param laserType TYPE The type of the laser
---@param position Vector The position to spawn the effect
local function SpawnLaserEffect(laser, player, laserType, position)
    -- Spawn a laser that keeps track of the color the laser should be
    local colorLaser = Isaac.Spawn(EntityType.ENTITY_LASER, laser.Variant, 0, Vector(50000,50000), Vector.Zero, nil):ToLaser()
    if colorLaser then
        -- Get associated data for the color laser
        local laserHash = colorLaser.Index
        RetrieveSpawnedLaserData(colorLaser, laserHash, laser, laserType, player)
        
        -- Spawn the effect that goes before the laser
        local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, LASER.TO_EFFECT[laserType], 0, position, Vector.Zero, nil):ToEffect()
        if effect then
            -- Get associated data for the effect
            local effectHash = effect.Index
            -- Set the scale of the effect
            effect.SpriteScale = effect.SpriteScale * LASER.WEAPON_EFFECT_SCALE[laserType]
            RetrieveSpawnedEffectData(effect, effectHash, laser, colorLaser, laserType, player)
            -- Initalize the effect to have the correct color
            SetEffectColor(effect)
        end
    end
end

---Handle firing the laser after the effect has played
---@param effect EntityEffect The effect spawning the laser
---@param player EntityPlayer The player
local function HandleLaserFire(effect, player)
    -- Get the nearest enemy the laser should target
    local enemy = UTILS.GetNearestEntity(effect.Position, nil)
    -- Get the direction towards the enemy or aim in the direction of the player
    local direction = Vector(0,1)
    if enemy ~= nil then
        direction = (enemy.Position - effect.Position):Normalized()
    else
        direction = player:GetAimDirection():Normalized()
    end

    -- If the laser is following the player and the player is not holding a direction, shoot away from the player
    if LASER.FOLLOW_PLAYER and direction:LengthSquared() < 0.01  then
        direction = (effect.Position - player.Position):Normalized()
    end

    -- Create the laser
    local effectData = LASER.effect[effect.Index]
    local laser = nil
    -- Handle special case of TECH X, cannot be made with Isaac.Spawn
    if effectData.laserType == LASER.TYPE.TECHX then
        -- Create TECH X
        laser = player:FireTechXLaser(effect.Position, direction, 20, player, LASER.DAMAGE)
        -- Adjust velocity to correct margins
        laser.Velocity = direction:LengthSquared() >= 0.01 and direction or (player.Position - effect.Position):Normalized()
        laser.Velocity = laser.Velocity * player.ShotSpeed * 10
        laser.Radius = effectData.laser.Radius * LASER.WEAPON_SCALE[LASER.TYPE.TECHX]
    elseif effectData.laserType == LASER.TYPE.BRIMSTONE then
        -- Spawn Brimstones
        laser = player:FireBrimstone(direction, nil, LASER.DAMAGE)
        laser.DisableFollowParent = true
    else
        -- Spawn Techology
        laser = Isaac.Spawn(EntityType.ENTITY_LASER, effectData.laser.Variant, effectData.laser.SubType, effect.Position, Vector.Zero, player):ToLaser() or effectData.colorLaser
        -- Set the scale of the laser
        laser.Size = laser.Size * 0.5
    end
    if laser then
        -- Set position to the effect's position
        laser.Position = effect.Position
        -- Reset the offset
        laser.PositionOffset = Vector.Zero
        -- Adjust the laser so that it is above the effect
        --laser.DepthOffset = effect.DepthOffset + 1
        -- Angle the laser to aim at the correct position
        laser.AngleDegrees = direction:LengthSquared() >= 0.01 and direction:GetAngleDegrees() or (player.Position - effect.Position):GetAngleDegrees()
        -- Apply all of the tear flags that the player has
        laser:AddTearFlags(player:GetTearHitParams(LASER.TYPE_TO_WEAPON[effectData.laserType]).TearFlags)
        -- Remove all disallowed tear flags
        laser:ClearTearFlags(effectData.removeFlags)
        -- Make the lasers spectral
        laser:AddTearFlags(TearFlags.TEAR_SPECTRAL)
        -- Set the duration of the laser [Function definition is incorrect]
        ---@diagnostic disable-next-line: param-type-mismatch
        laser:SetTimeout(LASER.WEAPON_DURATION[effectData.laserType])
        -- Correctly set damage [Tech 2]
        laser.CollisionDamage = effectData.laser.CollisionDamage * LASER.DAMAGE
        -- Set the color to the color saved when the effect was created
        laser:GetSprite().Color = effectData.laserColor
        -- Mark the laser so that it can't spawn more lasers
        LASER.spawned[laser.Index] = true
    end
end

---Handles the animations of the effect and eventually firing the laser
---@param effect EntityEffect The effect to modify
---@param hash number The hash of the effect
local function HandleSpawnedEffect(effect, hash)
    -- Get data for the effect
    local effectData = LASER.effect[hash]
    -- If the laser is set to follow the player, adjust the effect's velocity accordingly
    if LASER.FOLLOW_PLAYER and effect.FrameCount < LASER.TIME[effectData.laserType].FIRE then
        local realPos = effectData.player.Position + effectData.offsetPosition
        effect.Velocity = (realPos - effect.Position) * LASER.FOLLOW_SPEED
    end
    -- If it is time for the laser to fire, call the handler
    if effect.FrameCount == LASER.TIME[effectData.laserType].FIRE then
        HandleLaserFire(effect, effectData.player)
    end
end

---Runs when an effect updates
---@param effect EntityEffect
function HK:OnLaserEffectCreate(effect)
    -- Check if the effect should be handled
    if not LASER.EFFECT_LIST[effect.Variant] then return end

    -- Check if the effect is in the database
    local hash = effect.Index
    if LASER.effect[hash] == nil then return end
    -- Handle animations and spawning of laser
    HandleSpawnedEffect(effect, hash)
end

---Runs then an effect is rendered
---@param effect EntityEffect
function HK:OnLaserEffectRender(effect)
    -- Check if the effect should be handled
    if not LASER.EFFECT_LIST[effect.Variant] then return end

    -- Check if effect is in database
    local hash = effect.Index
    if LASER.effect[hash] then
        -- Adjust the color of the effect to match the tear
        SetEffectColor(effect)
    end
end

---Runs when lasers are updated
---@param laser EntityLaser 
function HK:OnLaserCreate(laser)
    -- Check if laser should be handled
    if not LASER.HANDLE_LIST[laser.Variant] then return end

    -- Check if laser has already been deemed done
    local hash = laser.Index
    if LASER.normal[hash] == false or LASER.spawned[hash] == false then return end

    -- Make sure the player spawned this laser and that they have the item
    local player = laser.SpawnerEntity and laser.SpawnerEntity:ToPlayer() or nil
    if not (player and player:HasCollectible(HK.ID)) then return end

    -- Code that runs for spawned lasers, initialization
    if LASER.spawned[hash] then
        laser.Size = laser.Size * 0.5
        LASER.spawned[hash] = false
        return
    end

    -- Limit the amount of spawned lasers
    if HK.hasSpawned or not laser:IsFrame(HK.CONT_SPAWNED_COOLDOWN, 1) then return end

    -- Get the type of the laser based on Variant and SubType
    local laserType = LASER.SUB_TO_TYPE[laser.SubType] or LASER.VAR_TO_TYPE[laser.Variant]

    -- Make sure the laser matches with all relevant player flags
    local playerTearFlags = player:GetTearHitParams(LASER.TYPE_TO_WEAPON[laserType]).TearFlags
    if not UTILS.DoTearFlagsMatch(playerTearFlags, laser.TearFlags, LASER.FLAG_MATCH_LIST) then
        -- Laser does not match, probably a biproduct of a regular laser
        LASER.normal[hash] = false
        return
    end

    -- Get the chance that the player will spawn a laser
    local spawnChance = UTILS.GetLuckChance(player.Luck,
        LUCK.BASE_CHANCE + LUCK.ADD_CHANCE * (player:GetCollectibleNum(HK.ID) - 1),
        LUCK.MULTIPLIER,
        LUCK.MIN_CHANCE,
        LUCK.MAX_CHANCE
    ) * (HK.ROOM_MULTIPLIER[game:GetLevel():GetCurrentRoom():GetRoomShape()] or 1)
    -- Get the RNG object for the item
    local rng = player:GetCollectibleRNG(HK.ID)
    -- Randomly determine if another laser should be spawned
    local chance = rng:RandomFloat()
    if chance > spawnChance then
        -- Laser did not pass the RNG check
        LASER.normal[hash] = true
        return
    end

    -- Laser passed the RNG check, generate a position in the room
    local randomPos = Vector.Zero
    if LASER.FOLLOW_PLAYER then
        -- The laser is following the player, it should spawn near the player
        randomPos = player.Position +
            rng:RandomVector() * (rng:RandomInt(2) * 2 - 1) * (LASER.SPAWN_MIN_DISTANCE + rng:RandomFloat() * (LASER.SPAWN_MAX_DISTANCE - LASER.SPAWN_MIN_DISTANCE))
    else
        -- The laser should spawn somewhere randomly in the room
        randomPos = game:GetLevel():GetCurrentRoom():GetRandomPosition(1)
    end
    -- Handle spawning the effect before the laser spawns
    SpawnLaserEffect(laser, player, laserType, randomPos)

    -- Mark that something has been spawned
    HK.hasSpawned = true
    LASER.normal[hash] = true
end

---Runs when any entity is removed
---@param ent Entity
function HK:OnLaserRemove(ent)
    -- Get the hash of the entity
    local hash = ent.Index
    -- Remove any stored data for that hash
    if LASER.normal[hash] ~= nil then
        LASER.normal[hash] = nil
    end
    if LASER.spawned[hash] ~= nil then
        LASER.spawned[hash] = nil
    end
    if LASER.effect[hash] ~= nil then
        LASER.effect[hash] = nil
    end
end

---Runs when the room changes
function HK:ResetLaser()
    -- Reset all databanks
    LASER.normal = {}
    LASER.spawned = {}
    LASER.effect = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE, HK.OnLaserCreate)
Quantum:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, HK.OnLaserEffectCreate)
Quantum:AddCallback(ModCallbacks.MC_POST_EFFECT_RENDER, HK.OnLaserEffectRender)
Quantum:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, HK.OnLaserRemove)
Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, HK.ResetLaser)