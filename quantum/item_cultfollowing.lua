Quantum.CultFollowing = {}
local CF = Quantum.CultFollowing
local game = Game()

---@type UTILS
local UTILS = include("quantum.utils")
---@type QUEUE
local QUEUE = include("quantum.sys_queue")

CF.ID = Isaac.GetItemIdByName("Cult Following")

-- Random number to signify that this is a unique cultist
CF.SUBTYPE = 90210
-- The color of the cultist
CF.NORMAL_COLOR = Color(1,1,1,1)
-- The color of the cultist when they can't revive enemies
CF.EXHAUST_COLOR = Color(1,0.5,0.5,1)
-- The scale of the cultist
CF.SCALE = 0.5
-- The speed multiplier for the cultist when following the player
CF.PLAYER_FOLLOW_MULT = 0.8
-- The speed multiplier for the cultist when following an enemy
CF.ENEMY_FOLLOW_MULT = 0.95

-- How many revives the cultist gets per room
CF.MAX_REVIVE_ROOM = 1
-- How many charmed enemies need to exist for the cultist to stop reviving (per cultist)
CF.MAX_CHARMED_TOTAL = 10
-- How long the revive takes to recharge in one room
CF.REVIVE_RECHARGE_TIME = 20 * 30
-- The time it takes for a revive to cancel
CF.REVIVE_TIMEOUT = 5 * 30
-- How long a charmed enemy can exist before dying
CF.CHARMED_MAX_LIFESPAN = 10 * 60 * 30
-- How long an invincible charmed enemy can exist before dying
CF.CHARMED_MAX_LIFESPAN_INVINCIBLE = 1 * 60 * 30

local charmedEnemies = 0

---Set the cultist's flags and variables
---@param cultist Entity
local function SetCultistFlags(cultist)
    -- No charm overlay, no attacking enemies
    cultist:ClearEntityFlags(EntityFlag.FLAG_CHARM)
    -- Don't show the HP bar with spider mod
    cultist:AddEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
    -- Don't collide with anything
    cultist.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    cultist.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
    -- Set the color of the cultist
    cultist:GetSprite().Color = CF.NORMAL_COLOR

    -- Set the scale of the cultist
    cultist:ToNPC().Scale = CF.SCALE
    -- Initialize the revive room cap to the maximum
    cultist:ToNPC().I2 = CF.MAX_REVIVE_ROOM
    -- Set targeting data
    local data = cultist:GetData()
    data.q_target = UTILS.GetPlayerHasCollectible(CF.ID) or Isaac.GetPlayer()
    data.q_hasTarget = false
    data.q_startRevive = false
    data.q_isReviving = false
    data.q_rechargeTime = math.maxinteger
    data.q_reviveTimeout = math.maxinteger
end

---Handle spawning the cultist initially
---@param player EntityPlayer The player that spawned the cultist
local function SpawnCultist(player)
    -- Mod save data
    local save = Quantum.save.GetRunSave()
    if save then
        -- A free position to spawn the cultist
        local position = game:GetLevel():GetCurrentRoom():FindFreePickupSpawnPosition(player.Position, 0, true)
        -- The cultist that the player spawned
        local cultist = Isaac.Spawn(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE, position, Vector.Zero, player)
        -- Charm the cultist
        cultist:AddCharmed(EntityRef(player), -1)
        -- Intialize save data
        save.cultistToPlayer = save.cultistToPlayer or {}
        save.playerToCultist = save.playerToCultist or {}
        save.playerToCultist[player.Index .. ""] = save.playerToCultist[player.Index .. ""] or {}
        -- Mark the cultist as belonging to the player
        save.cultistToPlayer[cultist.Index .. ""] = player.Index
        -- Mark the player as owning the cultist
        table.insert(save.playerToCultist[player.Index .. ""], cultist.Index)
        -- Set the cultists flags
        SetCultistFlags(cultist)
    end
end

---Handle any charmed enemies in the room, and return how many charmed enemies exist
---@return number charmedCount The amount of charmed enemies in the room
local function HandleCharmedEnemies()
    -- All entities in the room
    local entities = Isaac.GetRoomEntities()
    -- The total amount of charmed enemies in the room
    local charmedCount = 0
    -- Loop through the entities
    for _, e in pairs(entities) do
        -- Check if the entity is a charmed enemy
        if e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and e:IsEnemy() then
            -- Check if the enemy has lived too long
            if e.SubType ~= CF.SUBTYPE and e.FrameCount > CF.CHARMED_MAX_LIFESPAN or (e:IsInvincible() and e.FrameCount > CF.CHARMED_MAX_LIFESPAN_INVINCIBLE) then
                -- Handle death animation
                QUEUE:AddItem(0, function (t)
                    local lerp = t / 30
                    e:GetSprite().Color = Color.Lerp(e:GetSprite().Color, Color(1,1,1,1,0.75,0.75,0.75), lerp)
                    e.Velocity = e.Velocity * (1.0 - lerp)
                end, 30)
                QUEUE:AddItem(30, function (t)
                    e:Kill()
                    Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 2, e.Position, Vector.Zero, e)
                end)
            else
                -- Increment the charmed count
                charmedCount = charmedCount + 1
            end
        end
    end
    return charmedCount
end

---comment
---@param entity EntityNPC
local function HandleCultistBehavior(entity)
    local save = Quantum.save.GetRunSave()
    if save then
        local color = CF.NORMAL_COLOR
        local data = entity:GetData()
        local currentRoom = game:GetLevel():GetCurrentRoom()
        local player = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_PLAYER), save.cultistToPlayer[entity.Index])
        local collectibleNum = player:ToPlayer():GetCollectibleNum(CF.ID) * (player:ToPlayer():HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)
        
        if charmedEnemies >= CF.MAX_CHARMED_TOTAL * collectibleNum or entity.I2 >= CF.MAX_REVIVE_ROOM then
            entity.I1 = 0
            color = CF.EXHAUST_COLOR
        else
            if not currentRoom:IsClear() and entity.I2 < CF.MAX_REVIVE_ROOM and not (data.q_hasTarget or data.q_startRevive or data.q_isReviving) then
                print("getting target")
                data.q_target = UTILS.GetNearestEntity(currentRoom:GetRandomPosition(1), nil, function (e)
                    return UTILS.IsTargetableEnemy(e) and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
                end)
                data.q_hasTarget = data.q_target ~= nil
            end
            if data.q_hasTarget and not data.q_target:IsDead() then
                print("following target...")
                entity.TargetPosition = data.q_target.Position + Vector(1,0):Rotated((entity.FrameCount * 1.5) % 360) * 50
                entity.I1 = 0
            elseif data.q_hasTarget and data.q_target:IsDead() then
                print("starting revive")
                data.q_hasTarget = false
                data.q_startRevive = true
                data.q_reviveTimeout = Isaac.GetFrameCount() + CF.REVIVE_TIMEOUT
            end
            if data.q_startRevive then
                print("reviving...")
                entity.TargetPosition = data.q_target.Position
                entity.I1 = 2
                entity.V1.X = 0
                if entity.State == NpcState.STATE_SUMMON then
                    print("reviving!")
                    data.q_startRevive = false
                    data.q_isReviving = true
                end
                if Isaac.GetFrameCount() > data.q_reviveTimeout then
                    print("timeout reached")
                    data.q_target = nil
                    data.q_startRevive = false
                    data.q_reviveTimeout = math.maxinteger
                    entity.I1 = 1
                end
            end
            if entity:GetSprite():IsEventTriggered("Shoot") then
                print("revive triggered")
                local prevCharmedCount = charmedEnemies
                charmedEnemies = HandleCharmedEnemies()
                if charmedEnemies > prevCharmedCount then
                    print("entities revived")
                    entity.I2 = entity.I2 + 1
                    data.q_rechargeTime = Isaac.GetFrameCount() + CF.REVIVE_RECHARGE_TIME
                end
            end
            if data.q_isReviving and entity.State ~= NpcState.STATE_SUMMON then
                print("done reviving")
                data.q_isReviving = false
            end
        end
        if entity.I2 >= CF.MAX_REVIVE_ROOM and Isaac.GetFrameCount() > data.q_rechargeTime then
            print("recharged")
            entity.I2 = 0
            data.q_rechargeTime = math.maxinteger
        end
        if (entity.I2 >= CF.MAX_REVIVE_ROOM or data.q_target == nil) and not (data.q_hasTarget or data.q_startRevive or data.q_isReviving) then
            print("following player...")
            entity.TargetPosition = player.Position + Vector(1,0):Rotated((entity.FrameCount * 1.5) % 360) * 50
        end


        entity.Velocity = entity.Velocity * ((data.q_hasTarget or data.q_startRevive) and CF.ENEMY_FOLLOW_MULT or CF.PLAYER_FOLLOW_MULT)
        entity.FlipX = ((entity.TargetPosition - entity.Position):GetAngleDegrees() % 360) > 180
        entity:GetSprite().Color = Color.Lerp(entity:GetSprite().Color, color, 0.1)
    end
end

---Run every update frame, for each player
---@param player EntityPlayer
function CF:OnPlayerUpdate(player)
    -- Initialize whether the cultist has been spawned
    local cultistCount = Isaac.CountEntities(nil, EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE)
    local itemCount = player:GetCollectibleNum(CF.ID) * (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)
    if itemCount > cultistCount then
        SpawnCultist(player)
    elseif itemCount < cultistCount then
        local save = Quantum.save.GetRunSave()
        if save and save.playerToCultist and save.playerToCultist[player.Index .. ""] then
            local cultist = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE), save.playerToCultist[player.Index .. ""][1])
            if cultist then
                cultist:Remove()
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, CF.OnPlayerUpdate)

function CF:OnUpdate()
    charmedEnemies = HandleCharmedEnemies()
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, CF.OnUpdate)

---comment
---@param entity EntityNPC
function CF:OnNPCUpdate(entity)
    if entity.Type == EntityType.ENTITY_CULTIST and entity.SubType == CF.SUBTYPE then       
        HandleCultistBehavior(entity)
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, CF.OnNPCUpdate)

function CF:OnNewRoom()
    local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE)
    for _, e in pairs(entities) do
        e:ToNPC().I2 = 0
        local data = e:GetData()
        data.q_target = nil
        data.q_hasTarget = false
        data.q_isReviving = false
        data.q_rechargeTime = math.maxinteger
        data.q_reviveTimeout = math.maxinteger
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, CF.OnNewRoom)

function CF:OnContinue(isCont)
    if isCont then
        local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE)
        for _, e in pairs(entities) do
            SetCultistFlags(e)
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, CF.OnContinue)

if EID then
    EID:addCollectible(
        CF.ID,
        "Spawns a cultist familiar that can revive enemies to fight for you" ..
        "#Can only revive enemies once per room" ..
        "#Stops reviving enemies when a cap is reached"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(CF.ID, "The cultist's revive cap is increased")
    end
end