Quantum.Sacrificer = {}
local SC = Quantum.Sacrificer
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

SC.ID = Isaac.GetItemIdByName("Sacrificer")

-- Random number to signify that this is a unique cultist
SC.SUBTYPE = 666666
-- The color of the cultist
SC.NORMAL_COLOR = Color(1,1,1,1)
-- The color of the cultist when they can't revive enemies
SC.EXHAUST_COLOR = Color(1,0.5,0.5,1)
-- The scale of the cultist
SC.SCALE = 0.5
-- The speed multiplier for the cultist when following the player
SC.PLAYER_FOLLOW_MULT = 0.8
-- The speed multiplier for the cultist when following an enemy
SC.ENEMY_FOLLOW_MULT = 0.95

-- How many revives the cultist gets per room
SC.MAX_REVIVE_ROOM = 1
-- How many charmed enemies need to exist for the cultist to stop reviving (per cultist)
SC.MAX_CHARMED_TOTAL = 10
-- How long the revive takes to recharge in one room
SC.REVIVE_RECHARGE_TIME = 20 * 30
-- The time it takes for a revive to cancel
SC.REVIVE_TIMEOUT = 5 * 30
-- How long a charmed enemy can exist before dying
SC.CHARMED_MAX_LIFESPAN = 10 * 60 * 30
-- How long an invincible charmed enemy can exist before dying
SC.CHARMED_MAX_LIFESPAN_INVINCIBLE = 1 * 60 * 30

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
    cultist:GetSprite().Color = SC.NORMAL_COLOR

    -- Set the scale of the cultist
    cultist:ToNPC().Scale = SC.SCALE
    -- Initialize the revive room cap to the maximum
    cultist:ToNPC().I2 = SC.MAX_REVIVE_ROOM
    -- Initialize targeting data
    local data = cultist:GetData()
    data.q_target = nil
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
        local cultist = Isaac.Spawn(EntityType.ENTITY_CULTIST, 1, SC.SUBTYPE, position, Vector.Zero, player)
        -- Charm the cultist
        cultist:AddCharmed(EntityRef(player), -1)
        -- Intialize save data
        -- Table to convert cultist index to owner index
        save.cultistToPlayer = save.cultistToPlayer or {}
        -- Table to list all the cultists that a player owns
        save.playerToCultist = save.playerToCultist or {}
        -- Initalize the player specific table
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
            if e.SubType ~= SC.SUBTYPE and e.FrameCount > SC.CHARMED_MAX_LIFESPAN or (e:IsInvincible() and e.FrameCount > SC.CHARMED_MAX_LIFESPAN_INVINCIBLE) then
                -- Handle death animation
                -- Lerp the color and velocity of the enemy
                QUEUE:AddItem(0, 30, function (t)
                    local lerp = t / 30
                    e:GetSprite().Color = Color.Lerp(e:GetSprite().Color, Color(1,1,1,1,0.75,0.75,0.75), lerp)
                    e.Velocity = e.Velocity * (1.0 - lerp)
                end, QUEUE.UpdateType.Update)
                -- Trigger death and effect
                QUEUE:AddItem(30, 0, function (t)
                    e:Kill()
                    Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 2, e.Position, Vector.Zero, e)
                end, QUEUE.UpdateType.Update)
            else
                -- Increment the charmed count
                charmedCount = charmedCount + 1
            end
        end
    end
    return charmedCount
end

---Handle cultist's tracking behavior as well as reviving
---@param entity EntityNPC
local function HandleCultistBehavior(entity)
    -- Mod save data
    local save = Quantum.save.GetRunSave()
    if save then
        -- The color of the cultist
        local color = SC.NORMAL_COLOR
        -- The cultist's tracking data
        local data = entity:GetData()
        -- The current room of the floor
        local currentRoom = game:GetLevel():GetCurrentRoom()
        -- The cultist's owner
        local player = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_PLAYER), save.cultistToPlayer[entity.Index]) or Isaac.GetPlayer()
        -- The amount of collectibles the player has (BFFS is a 2x multiplier)
        local collectibleNum = player:ToPlayer():GetCollectibleNum(SC.ID) * (player:ToPlayer():HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)

        -- Check if the amount of charmed enemies in the room reached the cap
        -- OR if the amount of times the cultist has revived in the room has reached the cap
        if charmedEnemies >= SC.MAX_CHARMED_TOTAL * collectibleNum or entity.I2 >= SC.MAX_REVIVE_ROOM then
            -- Set the cultist's internal revive flag to zero
            -- This stops the cultist from ever attempting to revive enemies
            entity.I1 = 0
            -- Set the color of the cultist to the exhausted color
            color = SC.EXHAUST_COLOR
        else
            -- Check if the current room has active enemies and the cultist is able to revive enemies
            -- Also make sure the cultist is not doing anything else
            if not currentRoom:IsClear() and entity.I2 < SC.MAX_REVIVE_ROOM and not (data.q_hasTarget or data.q_startRevive or data.q_isReviving) then
                -- Set the target of the cultist to a non-charmed enemy in the room
                data.q_target = UTILS.GetNearestEntity(currentRoom:GetRandomPosition(1), nil, function (e)
                    return UTILS.IsTargetableEnemy(e) and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
                end)
                -- If targeting was successful, mark that the cultist has a target
                data.q_hasTarget = data.q_target ~= nil
            end
            -- Check if the cultist has a target and the target is not dead
            if data.q_hasTarget and not data.q_target:IsDead() then
                -- Set the target position for the cultist to circle around the enemy
                entity.TargetPosition = data.q_target.Position + Vector(1,0):Rotated((entity.FrameCount * 1.5) % 360) * 50
                -- Set the internal revive flag to zero to stop the cultist from reviving other enemies
                entity.I1 = 0
            -- Check if the cultist has a target and they are dead
            elseif data.q_hasTarget and data.q_target:IsDead() then
                -- Mark that the cultist is no longer targeting an enemy
                data.q_hasTarget = false
                -- Signal that the revive process has started
                data.q_startRevive = true
                -- Mark the time that the revive process will time out (only if unsuccessful)
                data.q_reviveTimeout = Isaac.GetFrameCount() + SC.REVIVE_TIMEOUT
            end
            -- Check if the revive process has started
            if data.q_startRevive then
                -- Set the cultist's target position to the position of the enemy that was previously followed
                entity.TargetPosition = data.q_target.Position
                -- Set the cultist's internal revive flag to two
                -- This signals the cultist that a revive should be processed
                entity.I1 = 2
                -- Set the cultist's internal time keeping to zero
                -- This triggers logic for the cultist to revive (allegedly, unknown if this actually helps)
                entity.V1.X = 0
                -- Check if the revival state has been reached
                -- This means the cultist has traveled to the dead enemy's position and started to revive them
                if entity.State == NpcState.STATE_SUMMON then
                    -- Mark the inital revive process completed
                    data.q_startRevive = false
                    -- Mark the actual revival ongoing
                    data.q_isReviving = true
                end
                -- Check if the revive timeout has been triggered
                if Isaac.GetFrameCount() > data.q_reviveTimeout then
                    -- Reset the target for the cultist
                    data.q_target = nil
                    -- Mark the revive starting process as ended
                    data.q_startRevive = false
                    -- Reset the revive timeout
                    data.q_reviveTimeout = math.maxinteger
                    -- Set the internal revive flag to idle (normal state)
                    entity.I1 = 1
                end
            end
            -- Check if the animation's revive flag is triggered (happens around frame 19)
            if entity:GetSprite():IsEventTriggered("Shoot") then
                -- The amount of charmed enemies on the previous frame
                local prevCharmedCount = charmedEnemies
                -- Recalculate the amount of charmed enemies on this frame
                charmedEnemies = HandleCharmedEnemies()
                -- Check if the amount of charmed enemies has increased
                if charmedEnemies > prevCharmedCount then
                    -- Increase the amount of revives used in the room
                    entity.I2 = entity.I2 + 1
                    -- Set the revive recharge time
                    data.q_rechargeTime = Isaac.GetFrameCount() + SC.REVIVE_RECHARGE_TIME
                end
            end
            -- Check if the cultist has finished the revive animation
            if data.q_isReviving and entity.State ~= NpcState.STATE_SUMMON then
                -- Mark the revive as completed
                data.q_isReviving = false
            end
        end
        -- Check if the recharge time has been reached, and that the cultist is out of revives for the room
        if entity.I2 >= SC.MAX_REVIVE_ROOM and Isaac.GetFrameCount() > data.q_rechargeTime then
            -- Reset the amount of revives in the room
            entity.I2 = 0
            -- Reset the recharge timer
            data.q_rechargeTime = math.maxinteger
        end
        -- Check if the cultist has used up their revives for the room
        --   OR finding a target has failed
        -- AND the cultist is not currently doing anything else
        if (entity.I2 >= SC.MAX_REVIVE_ROOM or data.q_target == nil) and not (data.q_hasTarget or data.q_startRevive or data.q_isReviving) then
            -- Set the cultist's target position to circle around the player
            entity.TargetPosition = player.Position + Vector(1,0):Rotated((entity.FrameCount * 1.5) % 360) * 50
        end

        -- Slow down the velocity of the cultist based on what state the cultist is in
        entity.Velocity = entity.Velocity * ((data.q_hasTarget or data.q_startRevive) and SC.ENEMY_FOLLOW_MULT or SC.PLAYER_FOLLOW_MULT)
        -- Make the cultist face where they are going
        entity.FlipX = ((entity.TargetPosition - entity.Position):GetAngleDegrees() % 360) > 180
        -- Lerp the color of the cultist towards the color they should be
        entity:GetSprite().Color = Color.Lerp(entity:GetSprite().Color, color, 0.1)
    end
end

---Run every update frame, for each player
---@param player EntityPlayer
function SC:OnPlayerUpdate(player)
    -- Mod run save data
    local save = Quantum.save.GetRunSave()
    if save and player:HasCollectible(SC.ID) then
        -- Intialize save data
        save.playerToCultist = save.playerToCultist or {}
        save.cultistToPlayer = save.cultistToPlayer or {}
        save.playerToCultist[player.Index .. ""] = save.playerToCultist[player.Index .. ""] or {}
        -- The count of cultists in the room
        local cultistCount = #save.playerToCultist[player.Index .. ""]
        -- The amount of cultists there should be for this player
        local itemCount = player:GetCollectibleNum(SC.ID) * (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)
        -- Check if the amount of cultists assigned to the player is too low
        if itemCount > cultistCount then
            -- Spawn another cultists
            SpawnCultist(player)
        elseif itemCount < cultistCount then
            -- The index of the last cultist within the player owned cultist list
            local lastCultist = #save.playerToCultist[player.Index .. ""] - 1
            -- The index of the last cultist within the game
            local lastCultistIndex = save.playerToCultist[player.Index .. ""][lastCultist]
            -- The last cultist assigned to the player
            local cultist = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, SC.SUBTYPE), lastCultistIndex)
            -- Check if the cultist exists
            if cultist then
                -- Remove the cultist from the game
                cultist:Remove()
                -- Mark the cultist as not owned by the player
                save.playerToCultist[player.Index .. ""][lastCultist] = nil
                -- Remove the cultist from the list
                save.cultistToPlayer[lastCultistIndex] = nil
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, SC.OnPlayerUpdate)

---Run every update frame
function SC:OnUpdate()
    -- Check if any player has the item
    if UTILS.AnyPlayerHasCollectible(SC.ID) then
        -- Recalculate the amount of charmed enemies in the room and handle them
        charmedEnemies = HandleCharmedEnemies()
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, SC.OnUpdate)

---Run every update frame, for every NPC
---@param entity EntityNPC
function SC:OnNPCUpdate(entity)
    -- Check if the NPC is a cultist spawned by the item
    if entity.Type == EntityType.ENTITY_CULTIST and entity.SubType == SC.SUBTYPE then
        -- Handle their tracking and reviving behavior
        HandleCultistBehavior(entity)
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, SC.OnNPCUpdate)

---Run when a new room is loaded
function SC:OnNewRoom()
    -- All cultists spawned by the item
    local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, SC.SUBTYPE)
    -- Loop through the cultists
    for _, e in pairs(entities) do
        -- Reset the amount of revives each cultist has used
        e:ToNPC().I2 = 0
        -- The tracking data for the cultist
        local data = e:GetData()
        -- Reset all data
        data.q_target = nil
        data.q_hasTarget = false
        data.q_isReviving = false
        data.q_rechargeTime = math.maxinteger
        data.q_reviveTimeout = math.maxinteger
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, SC.OnNewRoom)

---Run whenever a run is started or continued
---@param isCont boolean
function SC:OnContinue(isCont)
    -- Check if the run has been continues
    if isCont then
        -- All cultists that were spawned by the item
        local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, SC.SUBTYPE)
        -- Loop through the cultists
        for _, e in pairs(entities) do
            -- Reset all flags for the cultist
            SetCultistFlags(e)
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, SC.OnContinue)

if EID then
    EID:addCollectible(
        SC.ID,
        "Spawns a cultist familiar that can revive enemies to fight for you" ..
        "#Can only revive enemies once per room" ..
        "#Stops reviving enemies when a cap is reached"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(SC.ID, "The cultist's revive cap is increased")
    end
end