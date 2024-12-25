Quantum.EnemyLink = {}
local EL = Quantum.EnemyLink

EL.ID = Isaac.GetItemIdByName("Heart to Heart")
---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

-- The base chance for the effect to trigger
EL.BASE_CHANCE = 0.05
-- How much luck effects the change
EL.LUCK_MULT = 0.01
-- The minimum chance after luck
EL.MIN_CHANCE = 0.01
-- The maximum chance after luck
EL.MAX_CHANCE = 0.25

-- What percent of max health to deal as damage when a linked enemy dies
EL.DEATH_DAMAGE_MULT = 0.1

-- The color of a ripple
EL.RIPPLE_COLOR = Color(1,0.25,0.25,1,0.25,0.25,0.25)
-- How long to track the ripple for
EL.RIPPLE_DUR = 10
-- How often the passive ripple spawns
EL.RIPPLE_INTERVAL = 120
-- How big the ripple should be when taking damage
EL.RIPPLE_SCALE_DAMAGE = 2
-- how big the ripple should be passively
EL.RIPPLE_SCALE_PASSIVE = 1.2

-- How many orbs between the enemies that are linked
EL.EFFECT_AMOUNT = 7
-- The color of the orbs
EL.EFFECT_COLOR = Color(1,0.25,0.25,1,0.25,0.25,0.25)
-- The transparency of the orbs
EL.EFFECT_ALPHA = 0.5
-- How long the orbs take to fade after death
EL.EFFECT_FADE_TIME = 15
-- How far the orbs should be from the enemy at a minimum
EL.EFFECT_MIN_DISTANCE = 20

-- The list of enemies to attempt to link together
---@type EntityPtr[]
local enemyList = {}
-- The current enemies that are linked together
---@type table<integer, EntityPtr>
local enemyLinks = {}
-- The list of effects that are being managed
---@type table<EntityPtr[], EntityPtr[]>
local enemyEffects = {}

---Spawns a ripple effect on two enemies that are linked
---@param enemy1 Entity
---@param enemy2 Entity
---@param scale number
---@param color Color
local function SpawnRipple(enemy1, enemy2, scale, color)
    ---Create a ripple for a single entity
    ---@param e Entity
    ---@return Entity
    local function CreateRippleEffect(e)
        -- Spawn the effect on the entity
        local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.WATER_RIPPLE, 0, e.Position, Vector.Zero, e)
        -- Change aspects of the effect
        effect.Color = color
        effect.SpriteScale = Vector.One * scale
        return effect
    end
    -- Spawn one effect for each enemy
    local effect1 = CreateRippleEffect(enemy1)
    local effect2 = CreateRippleEffect(enemy2)
    -- Set them to follow the enemies over the effects lifetime
    QUEUE:AddItem(0, EL.RIPPLE_DUR,
    function(t)
        if enemy1 and enemy2 then
            effect1.Position = enemy1.Position
            effect2.Position = enemy2.Position
        end
    end, QUEUE.UpdateType.Update)
end

---Spawn the linking effect between the enemies
---@param enemy1 EntityNPC
---@param enemy2 EntityNPC
local function SpawnEffect(enemy1, enemy2)
    -- The list of spawned effects
    local effectList = {}
    -- Adjusted positions for each enemy, based on minimum distance away the effect should be
    local pos1 = enemy1.Position + (enemy2.Position - enemy1.Position):Normalized() * EL.EFFECT_MIN_DISTANCE
    local pos2 = enemy2.Position + (enemy1.Position - enemy2.Position):Normalized() * EL.EFFECT_MIN_DISTANCE
    -- Spawn an amount of orbs
    for i = 1, EL.EFFECT_AMOUNT do
        -- Get the lerped position of this orb
        local pos = UTILS.LerpV(pos1, pos2, i / (EL.EFFECT_AMOUNT + 1))
        -- Spawn the orb
        local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.ENEMY_SOUL, 0, pos, Vector.Zero, enemy1):ToEffect()
        if effect then
            -- Make sure the effect does not time out
            effect:SetTimeout(math.maxinteger)
            -- Fade the orbs in as they spawn
            QUEUE:AddItem(0, EL.EFFECT_FADE_TIME,
            function(t)
                UTILS.ChangeSpriteAlpha(effect:GetSprite(), t / EL.EFFECT_FADE_TIME * EL.EFFECT_ALPHA)
            end, QUEUE.UpdateType.Update)
            -- Set color and depth
            effect:GetSprite().Color = EL.EFFECT_COLOR
            UTILS.ChangeSpriteAlpha(effect:GetSprite(), 0)
            effect.DepthOffset = -1
            -- Add the effect to the list
            effectList[i] = EntityPtr(effect)
        end
    end
    -- Add the entire effect to the list of effects to track
    enemyEffects[effectList] = { EntityPtr(enemy1), EntityPtr(enemy2) }
end

---When an enemy takes damage, any linked enemies also take damage
---@param entity Entity
---@param amount number
---@param flags DamageFlag
---@param source EntityRef
---@param countdownFrames integer
function EL:OnEnemyDamage(entity, amount, flags, source, countdownFrames)
    -- Check if any player has the item
    if UTILS.AnyPlayerHasCollectible(EL.ID) then
        -- Make sure the entity taking damage is valid
        if enemyLinks[entity.Index] and enemyLinks[entity.Index].Ref and flags & DamageFlag.DAMAGE_INVINCIBLE == 0 then
            -- Have the linked enemy take damage with a special damage flag set to prevent infinite loops
            enemyLinks[entity.Index].Ref:TakeDamage(amount, flags | DamageFlag.DAMAGE_INVINCIBLE, source, countdownFrames)
            -- Spawn a ripple to indicate damage
            SpawnRipple(entity, enemyLinks[entity.Index].Ref, EL.RIPPLE_SCALE_DAMAGE, EL.RIPPLE_COLOR)
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, EL.OnEnemyDamage)

---Add enemies to a list to process later
---@param npc EntityNPC
function EL:OnEnemyCreate(npc)
    if npc.CanShutDoors and not npc:IsInvincible() and UTILS.AnyPlayerHasCollectible(EL.ID) then
        table.insert(enemyList, EntityPtr(npc))
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NPC_INIT, EL.OnEnemyCreate)

---If a linked enemy dies, take extra damage
---@param npc EntityNPC
function EL:OnEnemyUpdate(npc)
    -- Make sure the enemy has a link
    if enemyLinks[npc.Index] and enemyLinks[npc.Index].Ref then
        -- Check if the enemy is dead
        if npc:IsDead() then
            local linkedIndex = enemyLinks[npc.Index].Ref.Index
            -- Damage the linked enemy
            enemyLinks[npc.Index].Ref:TakeDamage(npc.MaxHitPoints * EL.DEATH_DAMAGE_MULT, 0, EntityRef(npc), 0)
            -- Remove both enemies from the lists
            enemyLinks[npc.Index] = nil
            enemyLinks[linkedIndex] = nil
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, EL.OnEnemyUpdate)

---Randomly link enemies together that have been spawned on the same frame
---@param player EntityPlayer
function EL:OnPlayerUpdate(player)
    -- Make sure the player has the collectible
    if player:HasCollectible(EL.ID) then
        local rng = player:GetCollectibleRNG(EL.ID)
        -- For each collectible the player has, attempt to link two enemies together once
        for _ = 1, player:GetCollectibleNum(EL.ID) do
            -- The barrier the player has to pass to trigger linking
            local luckCheck = UTILS.GetLuckChance(player.Luck, EL.BASE_CHANCE, EL.LUCK_MULT, EL.MIN_CHANCE, EL.MAX_CHANCE)
            -- The random roll
            local roll = rng:RandomFloat()
            -- Checks if two enemies can be linked and if the player has passed the check
            if #enemyList >= 2 and roll <= luckCheck then
                -- Get two random enemies from the list, adn remove them from the list at the same time
                local first  = table.remove(enemyList, math.floor(rng:RandomFloat() * (#enemyList - 1) + 1))
                local second = table.remove(enemyList, math.floor(rng:RandomFloat() * (#enemyList - 1) + 1))
                if first and second then
                    -- Link the two enemies together
                    enemyLinks[first.Ref.Index] = second
                    enemyLinks[second.Ref.Index] = first
                    -- Spawn the effects for the linking
                    SpawnEffect(first.Ref, second.Ref)
                end
            end
        end
    end

    -- Clear the enemy list for the frame
    enemyList = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, EL.OnPlayerUpdate)

---Updates the effects for linked enemies
function EL:OnUpdate()
    -- Loop through all linked enemies
    for effectList, enemies in pairs(enemyEffects) do
        -- Check if either enemy is dead
        if enemies[1].Ref:IsDead() or enemies[2].Ref:IsDead() then
            -- Remove them from the list
            enemyEffects[effectList] = nil
            -- For each orb in the effect list
            for _, effect in pairs(effectList) do
                -- Slowly fade out the orb
                QUEUE:AddItem(0, EL.EFFECT_FADE_TIME,
                function(t)
                    UTILS.ChangeSpriteAlpha(effect.Ref:GetSprite(), (1.0 - t / EL.EFFECT_FADE_TIME) * EL.EFFECT_ALPHA)
                end, QUEUE.UpdateType.Update)
                -- Remove the orb after fading out
                QUEUE:AddItem(EL.EFFECT_FADE_TIME, 0,
                function()
                    effect.Ref:Remove()
                end, QUEUE.UpdateType.Update)
            end
        else
            -- Check if the enemies should spawn a ripple effect on this frame
            if enemies[1].Ref:IsFrame(EL.RIPPLE_INTERVAL, 1) then
                -- Spawn a passive ripple effect
                SpawnRipple(enemies[1].Ref, enemies[2].Ref, EL.RIPPLE_SCALE_PASSIVE, EL.RIPPLE_COLOR)
            end
            -- The positions of the two enemies adjusted for minimum distances
            local pos1 = enemies[1].Ref.Position + (enemies[2].Ref.Position - enemies[1].Ref.Position):Normalized() * EL.EFFECT_MIN_DISTANCE
            local pos2 = enemies[2].Ref.Position + (enemies[1].Ref.Position - enemies[2].Ref.Position):Normalized() * EL.EFFECT_MIN_DISTANCE
            -- Update the positions of the effect orbs
            for i, effect in pairs(effectList) do
                effect.Ref.Position = UTILS.LerpV(pos1, pos2, i / (EL.EFFECT_AMOUNT + 1))
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, EL.OnUpdate)

---Clear any lists when a new room is entered
function EL:OnNewRoom()
    enemyLinks = {}
    enemyEffects = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, EL.OnNewRoom)

if EID then
    EID:addCollectible(
        EL.ID,
        "{{Heart}} 5% to link two enemies together and share any damage received" ..
        "#{{BrokenHeart}} When a linked enemy dies, it damages the other for a percentage of its health" ..
        "#{{Luck}} 25% chance at 20 Luck"
    )
end