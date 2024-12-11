Quantum.CultFollowing = {}
local CF = Quantum.CultFollowing
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

CF.ID = Isaac.GetItemIdByName("Cult Following")

-- Random number to signify that this is a unique cultist
CF.SUBTYPE = 90210
-- The color of the cultist
CF.NORMAL_COLOR = Color(1.25,1.25,1.25,1)
-- The color of the cultist when they can't revive enemies
CF.EXHAUST_COLOR = Color(3,3,3,1)
CF.EXHAUST_COLOR:SetColorize(1,0.75,1,0.75)
-- The scale of the cultist
CF.SCALE = 0.5
-- The speed multiplier for the cultist when following the player
CF.PLAYER_FOLLOW_MULT = 0.5
-- The speed multiplier for the cultist when following an enemy
CF.ENEMY_FOLLOW_MULT = 1

-- How many revives the cultist gets per room
CF.MAX_REVIVE_ROOM = 1
-- How many charmed enemies need to exist for the cultist to stop reviving (per cultist)
CF.MAX_CHARMED_TOTAL = 10
-- How long the revive takes to recharge in one room
CF.REVIVE_RECHARGE_TIME = 20 * 30
-- The time it takes for a revive to cancel
CF.REVIVE_TIMEOUT = 5 * 30
-- How long a charmed enemy can exist before dying
CF.CHARMED_MAX_LIFESPAN = 1 * 60 * 30
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
    -- Initialize targeting data
    local data = cultist:GetData()
    data.q_cf_target = nil
    data.q_cf_hasTarget = false
    data.q_cf_startRevive = false
    data.q_cf_isReviving = false
    data.q_cf_rechargeTime = math.maxinteger
    data.q_cf_reviveTimeout = math.maxinteger
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
        -- Table to convert cultist index to owner index
        save.cf_cultistToPlayer = save.cf_cultistToPlayer or {}
        -- Table to list all the cultists that a player owns
        save.cf_playerToCultist = save.cf_playerToCultist or {}
        -- Initalize the player specific table
        save.cf_playerToCultist[player.Index .. ""] = save.cf_playerToCultist[player.Index .. ""] or {}
        -- Mark the cultist as belonging to the player
        save.cf_cultistToPlayer[cultist.Index .. ""] = player.Index
        -- Mark the player as owning the cultist
        table.insert(save.cf_playerToCultist[player.Index .. ""], cultist.Index)
        -- Set the cultists flags
        SetCultistFlags(cultist)
        cultist:GetData().q_cf_index = #save.cf_playerToCultist[player.Index .. ""]
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
                if not e:GetData().q_cf_beingKilled then
                    -- Handle death animation
                    -- Lerp the color and velocity of the enemy
                    QUEUE:AddItem(0, 30, function (t)
                        local lerp = t / 30
                        e:GetSprite().Color = Color.Lerp(e:GetSprite().Color, Color(1,1,1,1,0.75,0.75,0.75), lerp)
                        e.Velocity = e.Velocity * (1.0 - lerp)
                    end, QUEUE.UpdateType.Update)
                    -- Trigger death and effect
                    QUEUE:AddItem(30, 0, function (t)
                        e:Remove()
                        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 2, e.Position, Vector.Zero, e)
                    end, QUEUE.UpdateType.Update)
                    e:GetData().q_cf_beingKilled = true
                end
                
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
        local color = CF.NORMAL_COLOR
        -- The cultist's tracking data
        local data = entity:GetData()
        -- The current room of the floor
        local currentRoom = game:GetLevel():GetCurrentRoom()
        -- The cultist's owner
        local player = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_PLAYER), save.cf_cultistToPlayer[entity.Index]) or Isaac.GetPlayer()
        -- The amount of collectibles the player has (BFFS is a 2x multiplier)
        local collectibleNum = player:ToPlayer():GetCollectibleNum(CF.ID) * (player:ToPlayer():HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)

        -- Check if the amount of charmed enemies in the room reached the cap
        -- OR if the amount of times the cultist has revived in the room has reached the cap
        -- OR the room is clear and no actions are currently being taken
        if charmedEnemies >= CF.MAX_CHARMED_TOTAL * collectibleNum
            or entity.I2 >= CF.MAX_REVIVE_ROOM
            or currentRoom:IsClear() and not (data.q_cf_hasTarget or data.q_cf_startRevive or data.q_cf_isReviving) then
            -- Set the cultist's internal revive flag to zero
            -- This stops the cultist from ever attempting to revive enemies
            entity.I1 = 0
            -- Set the color of the cultist to the exhausted color
            color = CF.EXHAUST_COLOR
        end
        -- Check if the current room has active enemies and the cultist is able to revive enemies
        -- Also make sure the cultist is not doing anything else
        if not currentRoom:IsClear() and entity.I2 < CF.MAX_REVIVE_ROOM and not (data.q_cf_hasTarget or data.q_cf_startRevive or data.q_cf_isReviving) then
            -- Set the target of the cultist to a non-charmed enemy in the room
            data.q_cf_target = UTILS.GetNearestEntity(currentRoom:GetRandomPosition(1), nil, function (e)
                return UTILS.IsTargetableEnemy(e) and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
            end)
            -- If targeting was successful, mark that the cultist has a target
            data.q_cf_hasTarget = data.q_cf_target ~= nil
        end
        -- Check if the cultist has a target and the target is not dead
        if data.q_cf_hasTarget and data.q_cf_target and not data.q_cf_target:IsDead() then
            -- The rotation offset for other cultists
            local offset = data.q_cf_index * (360 / #save.cf_playerToCultist[player.Index .. ""])
            -- Set the target position for the cultist to circle around the enemy
            entity.TargetPosition = data.q_cf_target.Position + Vector(1,0):Rotated((entity.FrameCount * 0.75) % 360 + offset) * 50
            -- Set the internal revive flag to zero to stop the cultist from reviving other enemies
            entity.I1 = 0
        -- Check if the cultist has a target and they are dead
        elseif data.q_cf_hasTarget and data.q_cf_target and data.q_cf_target:IsDead() then
            -- Mark that the cultist is no longer targeting an enemy
            data.q_cf_hasTarget = false
            -- Signal that the revive process has started
            data.q_cf_startRevive = true
            -- Mark the time that the revive process will time out (only if unsuccessful)
            data.q_cf_reviveTimeout = Isaac.GetFrameCount() + CF.REVIVE_TIMEOUT
        end
        -- Check if the revive process has started
        if data.q_cf_startRevive then
            -- Set the cultist's target position to the position of the enemy that was previously followed
            entity.TargetPosition = data.q_cf_target.Position
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
                data.q_cf_startRevive = false
                -- Mark the actual revival ongoing
                data.q_cf_isReviving = true
            end
            -- Check if the revive timeout has been triggered
            if Isaac.GetFrameCount() > data.q_cf_reviveTimeout then
                -- Reset the target for the cultist
                data.q_cf_target = nil
                -- Mark that the cultist is no longer targeting an enemy
                data.q_cf_hasTarget = false
                -- Mark the revive starting process as ended
                data.q_cf_startRevive = false
                -- Reset the revive timeout
                data.q_cf_reviveTimeout = math.maxinteger
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
                -- data.q_cf_rechargeTime = Isaac.GetFrameCount() + CF.REVIVE_RECHARGE_TIME
            end
        end
        -- Check if the cultist has finished the revive animation
        if data.q_cf_isReviving and entity.State ~= NpcState.STATE_SUMMON then
            -- Reset the target for the cultist
            data.q_cf_target = nil
            -- Mark that the cultist is no longer targeting an enemy
            data.q_cf_hasTarget = false
            -- Mark the revive as completed
            data.q_cf_isReviving = false
        end
        -- Check if the recharge time has been reached, and that the cultist is out of revives for the room
        --[[ if entity.I2 >= CF.MAX_REVIVE_ROOM and Isaac.GetFrameCount() > data.q_cf_rechargeTime then
            -- Reset the amount of revives in the room
            entity.I2 = 0
            -- Reset the recharge timer
            data.q_cf_rechargeTime = math.maxinteger
        end ]]
        -- Check if the cultist has used up their revives for the room
        --   OR finding a target has failed
        --   OR the room is clear
        -- AND the cultist is not currently doing anything else
        if (entity.I2 >= CF.MAX_REVIVE_ROOM or data.q_cf_target == nil or currentRoom:IsClear()) and not (data.q_cf_hasTarget or data.q_cf_startRevive or data.q_cf_isReviving) then
            -- The rotation offset for other cultists
            local offset = data.q_cf_index * (360 / #save.cf_playerToCultist[player.Index .. ""])
            -- Set the cultist's target position to circle around the player
            entity.TargetPosition = player.Position + Vector(1,0):Rotated((player.FrameCount * 0.75) % 360 + offset) * 50
        end

        -- Make the cultist move faster when further away from the player
        local player_follow_mult = UTILS.Lerp(CF.PLAYER_FOLLOW_MULT, CF.ENEMY_FOLLOW_MULT, (entity.Position:Distance(player.Position) - 50) / 50)
        -- Adjust velocity based on current state
        entity.Velocity = entity.Velocity * ((data.q_cf_hasTarget or data.q_cf_startRevive) and CF.ENEMY_FOLLOW_MULT or player_follow_mult)
        -- Make the cultist face where they are going
        local target_entity_position = (data.q_cf_hasTarget or data.q_cf_startRevive) and data.q_cf_target.Position or player.Position
        local cross = target_entity_position:Cross(entity.Position)
        entity.FlipX = cross > 0 or math.abs(cross) < 5
        -- Lerp the color of the cultist towards the color they should be
        entity:GetSprite().Color = Color.Lerp(entity:GetSprite().Color, color, 0.1)
    end
end

---Run every update frame, for each player
---@param player EntityPlayer
function CF:OnPlayerUpdate(player)
    -- Mod run save data
    local save = Quantum.save.GetRunSave()
    if save and player:HasCollectible(CF.ID) then
        -- Intialize save data
        save.cf_playerToCultist = save.cf_playerToCultist or {}
        save.cf_cultistToPlayer = save.cf_cultistToPlayer or {}
        save.cf_playerToCultist[player.Index .. ""] = save.cf_playerToCultist[player.Index .. ""] or {}
        -- The count of cultists in the room
        local cultistCount = #save.cf_playerToCultist[player.Index .. ""]
        -- The amount of cultists there should be for this player
        local itemCount = player:GetCollectibleNum(CF.ID) * (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)
        -- Check if the amount of cultists assigned to the player is too low
        if itemCount > cultistCount then
            -- Spawn another cultists
            SpawnCultist(player)
        elseif itemCount < cultistCount then
            -- The index of the last cultist within the player owned cultist list
            local lastCultist = #save.cf_playerToCultist[player.Index .. ""] - 1
            -- The index of the last cultist within the game
            local lastCultistIndex = save.cf_playerToCultist[player.Index .. ""][lastCultist]
            -- The last cultist assigned to the player
            local cultist = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE), lastCultistIndex)
            -- Check if the cultist exists
            if cultist then
                -- Remove the cultist from the game
                cultist:Remove()
                -- Mark the cultist as not owned by the player
                save.cf_playerToCultist[player.Index .. ""][lastCultist] = nil
                -- Remove the cultist from the list
                save.cf_cultistToPlayer[lastCultistIndex] = nil
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, CF.OnPlayerUpdate)

---Run every update frame
function CF:OnUpdate()
    -- Check if any player has the item
    if UTILS.AnyPlayerHasCollectible(CF.ID) then
        -- Recalculate the amount of charmed enemies in the room and handle them
        charmedEnemies = HandleCharmedEnemies()
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, CF.OnUpdate)

---Run every update frame, for every NPC
---@param entity EntityNPC
function CF:OnNPCUpdate(entity)
    -- Check if the NPC is a cultist spawned by the item
    if entity.Type == EntityType.ENTITY_CULTIST and entity.Variant == 0 and entity.SubType == CF.SUBTYPE then
        -- Handle their tracking and reviving behavior
        HandleCultistBehavior(entity)
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, CF.OnNPCUpdate)

---Run when a new room is loaded
function CF:OnNewRoom()
    -- All cultists spawned by the item
    local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE)
    -- Loop through the cultists
    for _, e in pairs(entities) do
        -- Reset the amount of revives each cultist has used
        e:ToNPC().I2 = 0
        -- The tracking data for the cultist
        local data = e:GetData()
        -- Reset all data
        data.q_cf_target = nil
        data.q_cf_hasTarget = false
        data.q_cf_isReviving = false
        data.q_cf_rechargeTime = math.maxinteger
        data.q_cf_reviveTimeout = math.maxinteger
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, CF.OnNewRoom)

---Run whenever a run is started or continued
---@param isCont boolean
function CF:OnContinue(isCont)
    -- Check if the run has been continues
    if isCont then
        -- All cultists that were spawned by the item
        local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CF.SUBTYPE)
        -- Loop through the cultists
        for _, e in pairs(entities) do
            -- Reset all flags for the cultist
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