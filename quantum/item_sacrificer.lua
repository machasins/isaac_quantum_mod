Quantum.ForgottenFriend = {}
local FF = Quantum.ForgottenFriend
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS

local GetData = UTILS.FuncGetData("q_ff")

FF.ID = Isaac.GetItemIdByName("Forgotten Friend")

-- Random number to signify that this is a unique cultist
FF.SUBTYPE = 8043807
-- The color of the cultist
FF.NORMAL_COLOR = Color(2,2,2,1)
FF.NORMAL_COLOR:SetColorize(2,2,2,1)
-- The scale of the cultist
FF.SCALE = 0.5
-- The speed multiplier for the cultist when close to the player
FF.NEAR_FOLLOW_MULT = 0.5
-- The speed multiplier for the cultist when far from the player
FF.FAR_FOLLOW_MULT = 0.95

-- The scale of the claws
FF.CLAW_SCALE = 0.5
-- The max random positional offest of the claws
FF.CLAW_OFFSET = 10
-- How long the cultist waits before summoning more claws
FF.CLAW_RECHARGE = 7
-- How mush random variance there is in the time between summoning claws
FF.CLAW_RECHARGE_VARIANCE = 2
-- The minimum amount of time between claws
FF.MIN_CLAW_RECHARGE = 3

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
    cultist:GetSprite().Color = FF.NORMAL_COLOR

    -- Set the scale of the cultist
    cultist:ToNPC().Scale = FF.SCALE
    -- Initialize targeting data
    local data = GetData(cultist)
    data.rechargeTime = 0
    data.isSpawning = false
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
        local cultist = Isaac.Spawn(EntityType.ENTITY_CULTIST, 1, FF.SUBTYPE, position, Vector.Zero, player)
        -- Charm the cultist
        cultist:AddCharmed(EntityRef(player), -1)
        -- Intialize save data
        -- Table to convert cultist index to owner index
        save.ff_sacrificerToPlayer = save.ff_sacrificerToPlayer or {}
        -- Table to list all the cultists that a player owns
        save.ff_playerToSacrificer = save.ff_playerToSacrificer or {}
        -- Initalize the player specific table
        save.ff_playerToSacrificer[player.Index .. ""] = save.ff_playerToSacrificer[player.Index .. ""] or {}
        -- Mark the cultist as belonging to the player
        save.ff_sacrificerToPlayer[cultist.Index .. ""] = player.Index
        -- Mark the player as owning the cultist
        table.insert(save.ff_playerToSacrificer[player.Index .. ""], cultist.Index)
        -- Set the cultists flags
        SetCultistFlags(cultist)
        GetData(cultist).index = #save.ff_playerToSacrificer[player.Index .. ""]
    end
end

---Handle cultist's tracking behavior as well as reviving
---@param entity EntityNPC
local function HandleCultistBehavior(entity)
    -- Mod save data
    local save = Quantum.save.GetRunSave()
    if save then
        entity:GetSprite().Color = FF.NORMAL_COLOR
        -- The cultist's tracking data
        local data = GetData(entity)
        -- The current room of the floor
        local currentRoom = game:GetLevel():GetCurrentRoom()
        -- The cultist's owner
        local player = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_PLAYER), save.ff_sacrificerToPlayer[entity.Index]) or Isaac.GetPlayer()
        -- The amount of collectibles the player has (BFFS is a 2x multiplier)
        local collectibleNum = player:ToPlayer():GetCollectibleNum(FF.ID) * (player:ToPlayer():HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)
        -- The sprite of the cultist
        local sprite = entity:GetSprite()

        -- Check if the cultist is spawning claws but the respawn animation is finished
        if data.isSpawning and sprite and sprite:GetAnimation() ~= "Respawn" then
            -- Reset the cooldown
            data.rechargeTime = entity.FrameCount + (math.max(FF.CLAW_RECHARGE - (collectibleNum - 1), FF.MIN_CLAW_RECHARGE)) * 30 + math.random(0, FF.CLAW_RECHARGE_VARIANCE * 30)
            -- The cultist is no longer spawning claws
            data.isSpawning = false
        -- Check if the amount of charmed enemies in the room reached the cap
        -- OR if the amount of times the cultist has revived in the room has reached the cap
        -- OR the room is clear and no actions are currently being taken
        elseif not currentRoom:IsClear() and entity.FrameCount >= data.rechargeTime then
            -- Start the cultists summoning claws
            entity:GetSprite():Play("Respawn", true)
            entity.State = 13
            -- Keep track that the cultist is spawning claws
            data.isSpawning = true
            -- Stop the cultist from starting to spawn any more claws in this period
            data.rechargeTime = math.maxinteger
            -- Stop the cultist from moving erradically
            entity.TargetPosition = entity.Position
        end
        -- Only set the target position if the cultist is not spawning claws (pathfinding is not run during the animation)
        if not data.isSpawning then
            -- The rotation offset for other cultists
            local offset = data.index * (360 / #save.ff_playerToSacrificer[player.Index .. ""])
            -- Set the cultist's target position to circle around the player
            entity.TargetPosition = player.Position + Vector(1,0):Rotated((player.FrameCount * 0.75) % 360 + offset) * 50
        end

        -- Make the cultist move faster when further away from the player
        local player_follow_mult = UTILS.Lerp(FF.NEAR_FOLLOW_MULT, FF.FAR_FOLLOW_MULT, (entity.Position:Distance(player.Position) - 50) / 50)
        -- Adjust velocity based on current state
        entity.Velocity = entity.Velocity * player_follow_mult
        -- Make the cultist face where they are going
        local cross = entity.TargetPosition:Cross(entity.Position)
        entity.FlipX = cross > 0 or math.abs(cross) < 5
    end
end

---Handle claw behaviors
---@param entity EntityNPC
local function HandleClawBehavior(entity)
    -- The cultist's tracking data
    local data = GetData(entity)
    data.setData = data.setData or false
    if not data.setData then
        -- Set random offset
        entity.PositionOffset = Vector(math.random(-FF.CLAW_OFFSET,FF.CLAW_OFFSET), math.random(-FF.CLAW_OFFSET, FF.CLAW_OFFSET))
        -- Set scale
        entity.Scale = FF.CLAW_SCALE
        data.setData = true
    end
end

---Run every update frame, for each player
---@param player EntityPlayer
function FF:OnPlayerUpdate(player)
    -- Mod run save data
    local save = Quantum.save.GetRunSave()
    if save and player and player:HasCollectible(FF.ID) then
        -- Intialize save data
        save.ff_playerToSacrificer = save.ff_playerToSacrificer or {}
        save.ff_sacrificerToPlayer = save.ff_sacrificerToPlayer or {}
        save.ff_playerToSacrificer[player.Index .. ""] = save.ff_playerToSacrificer[player.Index .. ""] or {}
        -- The count of cultists in the room
        local cultistCount = #save.ff_playerToSacrificer[player.Index .. ""]
        -- The amount of cultists there should be for this player
        local itemCount = player:GetCollectibleNum(FF.ID) * (player:HasCollectible(CollectibleType.COLLECTIBLE_BFFS) and 2 or 1)
        -- Check if the amount of cultists assigned to the player is too low
        if itemCount > cultistCount then
            -- Spawn another cultists
            SpawnCultist(player)
        elseif itemCount < cultistCount then
            -- The index of the last cultist within the player owned cultist list
            local lastCultist = #save.ff_playerToSacrificer[player.Index .. ""] - 1
            -- The index of the last cultist within the game
            local lastCultistIndex = save.ff_playerToSacrificer[player.Index .. ""][lastCultist]
            -- The last cultist assigned to the player
            local cultist = UTILS.GetEntityWithIndex(Isaac.FindByType(EntityType.ENTITY_CULTIST, 1, FF.SUBTYPE), lastCultistIndex)
            -- Check if the cultist exists
            if cultist then
                -- Remove the cultist from the game
                cultist:Remove()
                -- Mark the cultist as not owned by the player
                save.ff_playerToSacrificer[player.Index .. ""][lastCultist] = nil
                -- Remove the cultist from the list
                save.ff_sacrificerToPlayer[lastCultistIndex] = nil
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, FF.OnPlayerUpdate)

---Run every update frame, for every NPC
---@param entity EntityNPC
function FF:OnNPCUpdate(entity)
    -- Check if the NPC is a cultist spawned by the item
    if entity.Type == EntityType.ENTITY_CULTIST and entity.Variant == 1 and entity.SubType == FF.SUBTYPE then
        -- Handle their tracking and reviving behavior
        HandleCultistBehavior(entity)
    end
    -- Check if the NPC is a claw a cultist spawned
    if entity.Type == EntityType.ENTITY_CULTIST and entity.Variant == 10 and entity.SpawnerEntity.SubType == FF.SUBTYPE then
        HandleClawBehavior(entity)
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, FF.OnNPCUpdate)

---Run when a new room is loaded
function FF:OnNewRoom()
    -- All cultists spawned by the item
    local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 1, FF.SUBTYPE)
    -- Loop through the cultists
    for _, e in pairs(entities) do
        -- The tracking data for the cultist
        local data = GetData(e)
        -- Reset all data
        data.rechargeTime = e.FrameCount + math.random(3 * 30) + 30
        data.isSpawning = false
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, FF.OnNewRoom)

---Run whenever a run is started or continued
---@param isCont boolean
function FF:OnContinue(isCont)
    -- Check if the run has been continues
    if isCont then
        -- All cultists that were spawned by the item
        local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 1, FF.SUBTYPE)
        -- Loop through the cultists
        for _, e in pairs(entities) do
            -- Reset all flags for the cultist
            SetCultistFlags(e)
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, FF.OnContinue)

if EID then
    EID:addCollectible(
        FF.ID,
        "Spawns a cultist familiar that summons bone claw traps around Isaac" ..
        "#Traps petrify enemies for a short time when they run into them "
    )
end