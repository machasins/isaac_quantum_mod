---@class UTILS
local UTILS = Quantum.QW.UTILS
local LUCK = Quantum.QW.Luck

local TEAR = Quantum.QW.Tear
TEAR.normal = {}
TEAR.spawned = {}
TEAR.isSpawning = false

local game = Game()

---comment
---@param tear EntityTear
---@param hash number
---@param player EntityPlayer
local function RetrieveSpawnedTearData(tear, hash, player)
    TEAR.spawned[hash].originalScale = tear.BaseScale * TEAR.SCALE
    TEAR.spawned[hash].originalFallingAcceleration = tear.FallingAcceleration
    TEAR.spawned[hash].offsetPosition = tear.Position - tear.SpawnerEntity.Position
    TEAR.spawned[hash].originalHeight = tear.Height
    TEAR.spawned[hash].originalAlpha = tear:GetSprite().Color.A
    local flagsToRemove = BitSet128(0,0)
    for _, f in pairs(TEAR.FLAG_REMOVE_LIST) do
        if tear:HasTearFlags(f) then
            flagsToRemove = flagsToRemove | f
            print(f)
        end
    end
    local flagsToReAdd = BitSet128(0,0)
    for _, f in pairs(TEAR.FLAG_READD_LIST) do
        if tear:HasTearFlags(f) then
            flagsToReAdd = flagsToReAdd | f
            print(f)
        end
    end
    tear:ClearTearFlags(flagsToRemove | flagsToReAdd)
    TEAR.spawned[hash].originalTearFlags = flagsToReAdd
end

---Handles spawning a new tear
---@param tear EntityTear
---@param player EntityPlayer The player
---@param position Vector The position the tear should spawn in
local function SpawnTear(tear, player, position)
    local newTear = Isaac.Spawn(tear.Type, tear.Variant, tear.SubType, position, Vector(0,0), player):ToTear()
    if newTear then
        local hash = newTear.Index
        TEAR.spawned[hash] = {}
        local playerTearData = player:GetTearHitParams(tear.Variant == TearVariant.FETUS and WeaponType.WEAPON_FETUS or WeaponType.WEAPON_TEARS)
        newTear.Parent = player
        newTear.Height = playerTearData.TearHeight
        newTear.Scale = playerTearData.TearScale
        newTear.CollisionDamage = tear.CollisionDamage * TEAR.DAMAGE
        newTear.TearFlags = tear.TearFlags
        RetrieveSpawnedTearData(newTear, hash, player)
        newTear:AddTearFlags(TearFlags.TEAR_SPECTRAL)
        newTear.FallingAcceleration = 0
        newTear.Scale = 0
        newTear.Height = TEAR.INITIAL_HEIGHT
        newTear.Velocity = Vector(0,0.000001)
    end
end

local function HandleSpawnAnimation(tear, tearData)
    tear.Scale = UTILS.Lerp(0, tearData.originalScale, tear.FrameCount / TEAR.SPAWN_TIME)
    tear:GetSprite().Color.A = UTILS.Lerp(0, tearData.originalAlpha, tear.FrameCount / TEAR.SPAWN_TIME * 3)
    tear.FallingAcceleration = -0.1
    tear.FallingSpeed = (UTILS.Lerp(TEAR.INITIAL_HEIGHT, tearData.originalHeight, (tear.FrameCount + 1) / (TEAR.SPAWN_TIME - 1)) - tear.Height) / 2
end

local function HandleTearShot(tear, player)
    local enemy = UTILS.GetNearestEntity(tear.Position, nil)
    local velocity = Vector(0,0)
    if enemy ~= nil then
        velocity = ((enemy.Position + (enemy.Velocity * tear.Position:Distance(enemy.Position) * 0.1)) - tear.Position):Normalized()
    else
        velocity = player:GetAimDirection():Normalized()
    end
    if TEAR.FOLLOW_PLAYER and velocity:LengthSquared() < 0.01 then
        velocity = (tear.Position - player.Position):Normalized()
    end
    tear.Velocity = velocity * player.ShotSpeed * 10
end

local function HandleSpawnedTear(tear, hash, player)
    if tear.Variant == TearVariant.FETUS and TEAR.spawned[hash].child == nil then
        local knifes = Isaac.FindByType(EntityType.ENTITY_KNIFE)
        for _,k in pairs(knifes) do
            if GetPtrHash(k.Parent) == GetPtrHash(tear) then
                TEAR.spawned[hash].child = k:ToKnife()
            end
        end
        TEAR.spawned[hash].child = TEAR.spawned[hash].child or {}
    end

    local tearData = TEAR.spawned[hash]
    if tear.FrameCount <= TEAR.SPAWN_TIME then
        HandleSpawnAnimation(tear, tearData)
    end
    if tear.FrameCount > TEAR.SPAWN_TIME and tear.FrameCount < TEAR.FIRE_TIME then
        tear.FallingAcceleration = -0.1
        tear.FallingSpeed = 0
        tear.Height = tearData.originalHeight
    end
    if TEAR.FOLLOW_PLAYER and tear.FrameCount < TEAR.FIRE_TIME then
        local realPos = tear.SpawnerEntity.Position + tearData.offsetPosition
        tear.Velocity = (realPos - tear.Position) * TEAR.FOLLOW_SPEED
    end 
    if tear.FrameCount == TEAR.FIRE_TIME then
        tear.FallingAcceleration = tearData.originalFallingAcceleration
        tear:AddTearFlags(tearData.originalTearFlags)
        HandleTearShot(tear, player)
    end
end

---comment
---@param tear EntityTear
function Quantum.QW:OnTearCreate(tear)
    local hash = tear.Index
    if TEAR.normal[hash] == false then return end

    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer() or nil
    if not (player and player:HasCollectible(Quantum.QW.ID)) then return end

    if TEAR.isSpawning or TEAR.spawned[hash] ~= nil then
        HandleSpawnedTear(tear, hash, player)
        return
    end

    if TEAR.normal[hash] and (Quantum.QW.hasSpawned or not tear:IsFrame(Quantum.QW.CONT_SPAWNED_COOLDOWN, 1))then return end

    local isLudo = tear:HasTearFlags(TearFlags.TEAR_LUDOVICO)

    local playerTearFlags = player:GetTearHitParams(tear.Variant == TearVariant.FETUS and WeaponType.WEAPON_FETUS or WeaponType.WEAPON_TEARS).TearFlags
    if not UTILS.DoTearFlagsMatch(playerTearFlags, tear.TearFlags, TEAR.FLAG_MATCH_LIST) then
        TEAR.normal[hash] = false
        return
    end

    local spawnChance = UTILS.GetLuckChance(player,
        LUCK.BASE_CHANCE + LUCK.ADD_CHANCE * (player:GetCollectibleNum(Quantum.QW.ID) - 1),
        LUCK.MULTIPLIER,
        LUCK.MIN_CHANCE,
        LUCK.MAX_CHANCE
    ) * (Quantum.QW.ROOM_MULTIPLIER[game:GetLevel():GetCurrentRoom():GetRoomShape()] or 1)
    local rng = player:GetCollectibleRNG(Quantum.QW.ID)
    local chance = rng:RandomFloat()
    if chance > spawnChance then
        TEAR.normal[hash] = isLudo
        return
    end

    local randomPos = Vector(0,0)
    if TEAR.FOLLOW_PLAYER then
        randomPos = player.Position +
            rng:RandomVector() * (rng:RandomInt(2) * 2 - 1) * (TEAR.SPAWN_MIN_DISTANCE + rng:RandomFloat() * (TEAR.SPAWN_MAX_DISTANCE - TEAR.SPAWN_MIN_DISTANCE))
    else
        randomPos = game:GetLevel():GetCurrentRoom():GetRandomPosition(1)
    end
    SpawnTear(tear, player, randomPos)

    Quantum.QW.hasSpawned = Quantum.QW.hasSpawned or isLudo
    TEAR.normal[hash] = isLudo
end

function Quantum.QW:OnTearRemove(ent)
    local hash = ent.Index
    if TEAR.normal[hash] then
        TEAR.normal[hash] = nil
    end
    if TEAR.spawned[hash] ~= nil then
        TEAR.spawned[hash] = nil
    end
end

function Quantum.QW:ResetTear()
    TEAR.normal = {}
    TEAR.spawned = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, Quantum.QW.OnTearCreate)
Quantum:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, Quantum.QW.OnTearRemove)
Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Quantum.QW.ResetTear)