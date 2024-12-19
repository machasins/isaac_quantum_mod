local HK = Quantum.Hydrokinesis

---@class UTILS
local UTILS = HK.UTILS
local LUCK = HK.Luck

local KNIFE = HK.Knife
KNIFE.normal = {}
KNIFE.spawned = {}

local GetData = UTILS.FuncGetData("q_hk_knife")
local game = Game()

---Chooses a target for the knife to aim at
---@param prevTarget Entity
---@param position Vector
---@return Entity|nil
local function ChooseTarget(prevTarget, position)
    if prevTarget and UTILS.IsTargetableEnemy(prevTarget) then
        return prevTarget
    else
        return UTILS.GetNearestEntity(position)
    end
end

---Aims the knife at a target
---@param knife EntityKnife
---@param knifeData table
---@param player EntityPlayer
---@param spinTime number
---@param aimSpeed number
local function AimKnife(knife, knifeData, player, spinTime, aimSpeed)
    -- Get a target to aim at
    local target = ChooseTarget(knifeData.aimTarget, knife.Position)
    -- Remember the last taget that was chosen
    knifeData.aimTarget = target
    -- If no target was chosen, aim at the player
    target = target or player
    -- Make the knife spin when it first spawns
    local additionalDegrees = UTILS.Lerp(360, 0, spinTime)
    -- The degrees needed to aim at the target
    local degrees = ((target.Position + target.Velocity) - knife.Position):GetAngleDegrees() - 90
    -- Add all degrees together and clamp it to [0, 360)
    degrees = (degrees + additionalDegrees) % 360
    -- Lerp the angle towards the correct degrees (SpriteRotation is set to -90 every frame, can't use that for lerping)
    knifeData.prevRotation = UTILS.AngleLerp(knifeData.prevRotation, degrees, aimSpeed)
    -- Set the rotation for the knife
    knife.SpriteRotation = knifeData.prevRotation
end

---Handles the knife's spawning animation
---@param knife EntityKnife
---@param player EntityPlayer
---@param knifeType KNIFE_TYPE
local function HandleKnifeSpawnAnimation(knife, player, knifeType)
    -- The knife's data
    local knifeData = GetData(knife)
    -- The effect that controls the knife's position
    local effectControl = knifeData.effectControl.Entity
    -- The data for the effect
    local effectControlData = GetData(effectControl)

    -- The frame amount that the spawning animation lasts
    local spawnTime = KNIFE.SPAWN_TIME[knifeType]
    -- The frame amount before the knife fires
    local aimTime = KNIFE.SPAWN_TIME[knifeType] + KNIFE.AIM_TIME[knifeType]

    -- If the knife is set to follow the player, adjust the effect's velocity accordingly
    if KNIFE.FOLLOW_PLAYER and effectControl.FrameCount < aimTime then
        local realPos = player.Position + effectControlData.effectOffset
        effectControl.Velocity = (realPos - effectControl.Position) * KNIFE.FOLLOW_SPEED
    end
    -- Spawning animation, increase alpha and spin the knife
    if effectControl.FrameCount <= spawnTime then
        UTILS.ChangeSpriteAlpha(knife:GetSprite(), UTILS.Lerp(0, 1, effectControl.FrameCount / spawnTime))
        knife.SpriteScale = UTILS.LerpV(Vector.Zero, knifeData.targetScale, effectControl.FrameCount / spawnTime)
    end
    -- Aim the knife at a target
    if effectControl.FrameCount < aimTime then
        AimKnife(knife, knifeData, player, effectControl.FrameCount / spawnTime, 1.0 / 10.0)
    end
    -- Fire the knife at the target
    if effectControl.FrameCount >= aimTime then
        -- If the knife is homing, constantly adjust the angle
        if knife:HasTearFlags(TearFlags.TEAR_HOMING) then
            AimKnife(knife, knifeData, player, 1, 1.0 / 60.0)
        end
        -- Move the effect controller towards the knife's aiming direction
        effectControl.Velocity = Vector.FromAngle(knifeData.prevRotation + 90) * KNIFE.LAUNCH_SPEED
        if knifeType == KNIFE.TYPE.MOM then
            -- Lock the knife's rotation
            knife.SpriteRotation = knifeData.prevRotation
        else
            -- Make clubs and scythes actually do damage
            knife:Shoot(0, 50)
            -- Handle the spinning animations for the club and scythe
            knife:GetSprite():SetFrame("Spin", (knife.FrameCount) % 8)
        end
    end
end

---In charge of spawning new knives
---@param knife EntityKnife The inital knife
---@param player EntityPlayer The player
---@param knifeType KNIFE_TYPE The type of the knife
---@param position Vector The position to spawn the knife
local function SpawnKnife(knife, player, knifeType, position)
    -- Spawn controlling effect
    local effectControl = Isaac.Spawn(1000, 10, 0, position, Vector.Zero, nil)
    -- Set the controlling effects alpha to 0
    UTILS.ChangeSpriteAlpha(effectControl:GetSprite(), 0)
    -- Set the timeout of the effect
    effectControl:ToEffect():SetTimeout(KNIFE.WEAPON_DURATION[knifeType])
    -- Change the collision classes of the effect controller
    effectControl.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    effectControl.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
    -- For use if knife follows the player, sets original offset
    local effectControlData = GetData(effectControl)
    effectControlData.effectOffset = effectControl.Position - player.Position
    -- Spawn a knife
    local spawned = Isaac.Spawn(knife.Type, knife.Variant, 0, position, Vector.Zero, player)
    -- Set the parent of the knife to the effect
    spawned.Parent = effectControl
    spawned:ToKnife():AddTearFlags(knife.TearFlags)
    spawned.Color = knife.Color
    -- Set the knife to be invisible
    UTILS.ChangeSpriteAlpha(spawned:GetSprite(), 0)
    -- Play the spin animation if the knife is a bone club
    if knifeType == KNIFE.TYPE.MOM then
        spawned.CollisionDamage = knife.CollisionDamage * KNIFE.DAMAGE
    end
    if knifeType == KNIFE.TYPE.CLUB or knifeType == KNIFE.TYPE.SCYTHE then
        spawned:GetSprite():SetFrame("Spin", 6)
        spawned.CollisionDamage = knife.CollisionDamage * KNIFE.DAMAGE
    end
    -- Remember the effect controller
    local spawnedData = GetData(spawned)
    spawnedData.effectControl = EntityRef(effectControl)
    spawnedData.prevRotation = 270
    spawnedData.targetScale = knife.SpriteScale * KNIFE.WEAPON_SCALE[knifeType]
    -- Set the scale of the knife
    spawned.SpriteScale = Vector.Zero
    local hash = spawned.Index
    KNIFE.spawned[hash] = true
end

---Runs when knifes are updated
---@param knife EntityKnife 
function HK:OnKnifeCreate(knife)
    -- Check if knife should be handled
    if KNIFE.VAR_TO_TYPE[knife.Variant] == KNIFE.TYPE.NOT_SUPPORTED then return end
    
    -- Check if knife has already been deemed done
    local hash = knife.Index
    if KNIFE.normal[hash] == false or KNIFE.spawned[hash] == false then return end
    
    -- Make sure the player spawned this knife and that they have the item
    local player = knife.SpawnerEntity and knife.SpawnerEntity:ToPlayer() or nil
    if not (player and player:HasCollectible(HK.ID)) then return end
    
    -- Get the type of the knife based on Variant and SubType
    local knifeType = KNIFE.SUB_TO_TYPE[knife.SubType] or KNIFE.VAR_TO_TYPE[knife.Variant]

    -- Code that runs for spawned knifes, initialization
    if KNIFE.spawned[hash] then
        HandleKnifeSpawnAnimation(knife, player, knifeType)
        return
    end

    -- Limit the amount of spawned knifes
    if HK.hasSpawned or not knife:IsFrame(HK.CONT_SPAWNED_COOLDOWN, 1) then return end

    -- Check whether the knife meets conditions to spawn more knives
    if not (knife.SubType == KnifeSubType.CLUB_HITBOX or knife:IsFlying()) then
        return
    end

    -- Make sure the knife matches with all relevant player flags
    local playerTearFlags = player:GetTearHitParams(KNIFE.TYPE_TO_WEAPON[knifeType]).TearFlags
    if not UTILS.DoTearFlagsMatch(playerTearFlags, knife.TearFlags, KNIFE.FLAG_MATCH_LIST) then
        -- Knife does not match, probably a biproduct of a regular knife
        KNIFE.normal[hash] = false
        return
    end

    -- Get the chance that the player will spawn a knife
    local spawnChance = UTILS.GetLuckChance(player.Luck,
        LUCK.BASE_CHANCE + LUCK.ADD_CHANCE * (player:GetCollectibleNum(HK.ID) - 1),
        LUCK.MULTIPLIER,
        LUCK.MIN_CHANCE,
        LUCK.MAX_CHANCE
    ) * (HK.ROOM_MULTIPLIER[game:GetLevel():GetCurrentRoom():GetRoomShape()] or 1)
    -- Get the RNG object for the item
    local rng = player:GetCollectibleRNG(HK.ID)
    -- Randomly determine if another knife should be spawned
    local chance = rng:RandomFloat()
    if chance > spawnChance then
        -- Knife did not pass the RNG check
        KNIFE.normal[hash] = true
        return
    end

    -- Knife passed the RNG check, generate a position in the room
    local randomPos = Vector.Zero
    if KNIFE.FOLLOW_PLAYER then
        -- The knife is following the player, it should spawn near the player
        randomPos = player.Position +
            rng:RandomVector() * (rng:RandomInt(2) * 2 - 1) * (KNIFE.SPAWN_MIN_DISTANCE + rng:RandomFloat() * (KNIFE.SPAWN_MAX_DISTANCE - KNIFE.SPAWN_MIN_DISTANCE))
    else
        -- The knife should spawn somewhere randomly in the room
        randomPos = game:GetLevel():GetCurrentRoom():GetRandomPosition(1)
    end
    -- Handle spawning a knife
    SpawnKnife(knife, player, knifeType, randomPos)

    -- Mark that something has been spawned
    HK.hasSpawned = true
    KNIFE.normal[hash] = true
end

Quantum:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, HK.OnKnifeCreate)

---Runs when any entity is removed
---@param ent Entity
function HK:OnKnifeRemove(ent)
    -- Get the hash of the entity
    local hash = ent.Index
    -- Remove any stored data for that hash
    if KNIFE.normal[hash] ~= nil then
        KNIFE.normal[hash] = nil
    end
    if KNIFE.spawned[hash] ~= nil then
        KNIFE.spawned[hash] = nil
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, HK.OnKnifeRemove)

---Runs when the room changes
function HK:ResetKnife()
    -- Reset all databanks
    KNIFE.normal = {}
    KNIFE.spawned = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, HK.ResetKnife)