Quantum.ArtificalBloom = {}
local AB = Quantum.ArtificalBloom
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

local GetData = UTILS.FuncGetData("q_ab")

-- ID of the item
AB.ID = Isaac.GetItemIdByName("Artifical Bloom")

-- Maximum amount of hitpoints to consider
AB.MAX_HITPOINTS = 10000

-- How long the enemy should stay frozen
AB.FREEZE_TIME = 90
-- How many wobbles back anf forth the enemy should do
AB.FREEZE_WOBBLES = 12
-- How far the wobbles should go
AB.FREEZE_WOBBLE_DISTANCE = 3
-- How long the enemy should be still for before wobbling
AB.FREEZE_START_TIME = 0.2
-- The color when the enemy is frozen
AB.FREEZE_COLOR = Color(1,1,1,1,0.25,0.5,4)

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
function AB:OnUseItem(id, RNG, player, Flags, Slot, CustomVarData)
    -- All entities in the room
    local entities = Isaac.GetRoomEntities()
    -- Candidates for metamorphosis
    local candidates = {}
    -- Total amount of hitpoints of the candidates
    local totalWeight = 0
    -- Loop through the entities
    for _, e in pairs(entities) do
        -- Check if the entity is a charmed enemy
        if e:IsActiveEnemy(false) and e:ToNPC() ~= nil and not (e:IsBoss() or e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) or e:HasEntityFlags(EntityFlag.FLAG_FREEZE) or e.Parent) then
            local weight = AB.MAX_HITPOINTS + 1 - (e:IsInvincible() and AB.MAX_HITPOINTS or math.min(e.HitPoints, AB.MAX_HITPOINTS))
            table.insert(candidates, { weight, e })
            totalWeight = totalWeight + weight
        end
    end
    -- If no eligable enemies, cancel the active
    if #candidates <= 0 then
        return {
            Discharge = false,
            Remove = false,
            ShowAnim = true,
        }
    end
    -- Get random enemy to charm
    ---@type Entity
    local randomEnemy = candidates[weightedRandom(candidates, totalWeight)][2]
    -- Play sound effect
    SFXManager():Play(SoundEffect.SOUND_FREEZE)
    -- Keep track of the inital enemy color
    local enemyColor = randomEnemy.Color
    -- Freeze the enemy in place
    randomEnemy:AddFreeze(EntityRef(player), AB.FREEZE_TIME)
    -- Set the enemy's color to the freeze color
    randomEnemy:GetSprite().Color = AB.FREEZE_COLOR
    -- Queue a lasting effect
    QUEUE:AddItem(0, AB.FREEZE_TIME, function (time)
        -- The interpolation time
        local t = (time - AB.FREEZE_START_TIME) / (AB.FREEZE_TIME - AB.FREEZE_START_TIME)
        -- Wobble the enemy in place
        randomEnemy.Position = randomEnemy.Position + Vector(
            AB.FREEZE_WOBBLE_DISTANCE * t *
            math.sin(t * AB.FREEZE_WOBBLES * 2 * math.pi)
            , 0)
        -- Slowly thaw the enemy out of the frozen color
        randomEnemy:GetSprite().Color = Color.Lerp(AB.FREEZE_COLOR, enemyColor, t)
        -- Stop any damage
        randomEnemy.HitPoints = randomEnemy.MaxHitPoints
    end, QUEUE.UpdateType.Update)
    -- Queue an ending effect
    QUEUE:AddItem(91, 0, function ()
        if randomEnemy and not randomEnemy:IsDead() then
            -- Play a sound for the enemy unfreezing
            SFXManager():Play(SoundEffect.SOUND_FREEZE_SHATTER)
            -- Refresh the hitpoints of the enemy
            randomEnemy.HitPoints = randomEnemy.MaxHitPoints
            -- Charm the enemy
            randomEnemy:AddCharmed(EntityRef(player), -1)
            -- Mark the enemy as charmed by the mod
            local enemyData = GetData(randomEnemy)
            enemyData.isCharmedEnemy = true
        end
    end, QUEUE.UpdateType.Update)

    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true,
    }
end

Quantum:AddCallback(ModCallbacks.MC_USE_ITEM, AB.OnUseItem, AB.ID)

if EID then
    EID:addCollectible(
        AB.ID,
        "#{{Freezing}} Freezes one non-boss enemy in the room for 3 seconds" ..
        "#{{Charm}} After unfreezing, the enemy is permanently charmed" ..
        "#{{DiceRoom}} Chooses enemies to freeze randomly, weighted based on health. The more health an enemy has, the less likely to be chosen"
    )
end