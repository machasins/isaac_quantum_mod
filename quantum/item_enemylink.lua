Quantum.EnemyLink = {}
local EL = Quantum.EnemyLink

EL.ID = Isaac.GetItemIdByName("Heart to Heart")
---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

EL.BASE_CHANCE = 0.05
EL.LUCK_MULT = 0.01
EL.MIN_CHANCE = 0.01
EL.MAX_CHANCE = 0.25

EL.DEATH_DAMAGE_MULT = 0.25

EL.ENEMY_COLOR = Color(1,0.25,0.25,1,0.25,0.25,0.25)
EL.ENEMY_COLOR_DUR = 7
EL.ENEMY_COLOR_INTERVAL = 45

EL.EFFECT_AMOUNT = 5
EL.EFFECT_COLOR = Color(1,0.25,0.25,1,0.25,0.25,0.25)
EL.EFFECT_ALPHA = 0.5
EL.EFFECT_FADE_TIME = 15

---@type EntityPtr[]
local enemyList = {}
---@type table<integer, EntityPtr>
local enemyLinks = {}
---@type table<EntityPtr[], EntityPtr[]>
local enemyEffects = {}

---comment
---@param enemy1 EntityNPC
---@param enemy2 EntityNPC
local function SpawnEffect(enemy1, enemy2)
    local effectList = {}
    for i = 1, EL.EFFECT_AMOUNT do
        local pos = UTILS.LerpV(enemy1.Position, enemy2.Position, (i + 1) / (EL.EFFECT_AMOUNT + 2))
        local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.ENEMY_SOUL, 0, pos, Vector.Zero, enemy1):ToEffect()
        if effect then
            effect:SetTimeout(math.maxinteger)
            QUEUE:AddItem(0, EL.EFFECT_FADE_TIME,
            function(t)
                effect:GetSprite().Color.A = t / EL.EFFECT_FADE_TIME * EL.EFFECT_ALPHA
            end, QUEUE.UpdateType.Update)
            effect:GetSprite().Color = EL.EFFECT_COLOR
            effect:GetSprite().Color.A = 0
            effect.DepthOffset = -1
            effectList[i] = EntityPtr(effect)
        end
    end
    enemyEffects[effectList] = { EntityPtr(enemy1), EntityPtr(enemy2) }
end

---comment
---@param entity Entity
---@param amount number
---@param flags DamageFlag
---@param source EntityRef
---@param countdownFrames integer
function EL:OnEnemyDamage(entity, amount, flags, source, countdownFrames)
    if UTILS.AnyPlayerHasCollectible(EL.ID) then
        if enemyLinks[entity.Index] and enemyLinks[entity.Index].Ref and flags & DamageFlag.DAMAGE_INVINCIBLE == 0 then
            enemyLinks[entity.Index].Ref:TakeDamage(amount, flags | DamageFlag.DAMAGE_INVINCIBLE, source, countdownFrames)
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, EL.OnEnemyDamage)

---comment
---@param npc EntityNPC
function EL:OnEnemyCreate(npc)
    if npc.CanShutDoors and UTILS.AnyPlayerHasCollectible(EL.ID) then
        table.insert(enemyList, EntityPtr(npc))
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NPC_INIT, EL.OnEnemyCreate)

---comment
---@param npc EntityNPC
function EL:OnEnemyUpdate(npc)
    if enemyLinks[npc.Index] and enemyLinks[npc.Index].Ref then
        if npc:IsDead() then
            local linkedIndex = enemyLinks[npc.Index].Ref.Index
            enemyLinks[npc.Index].Ref:TakeDamage(npc.MaxHitPoints * EL.DEATH_DAMAGE_MULT, 0, EntityRef(npc), 0)
            enemyLinks[npc.Index] = nil
            enemyLinks[linkedIndex] = nil
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, EL.OnEnemyUpdate)

---comment
---@param player EntityPlayer
function EL:OnPlayerUpdate(player)
    if player:HasCollectible(EL.ID) then
        local rng = player:GetCollectibleRNG(EL.ID)
        for _ = 1, player:GetCollectibleNum(EL.ID) do
            local luckCheck = UTILS.GetLuckChance(player.Luck, EL.BASE_CHANCE, EL.LUCK_MULT, EL.MIN_CHANCE, EL.MAX_CHANCE)
            local roll = rng:RandomFloat()
            if #enemyList >= 2 and roll <= luckCheck then
                local first = table.remove(enemyList, rng:RandomInt(1, #enemyList))
                local second = table.remove(enemyList, rng:RandomInt(1, #enemyList))
                if first and second then
                    enemyLinks[first.Ref.Index] = second
                    enemyLinks[second.Ref.Index] = first
                    SpawnEffect(first.Ref, second.Ref)
                end
            end
        end
    end

    enemyList = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, EL.OnPlayerUpdate)

---comment
function EL:OnUpdate()
    for effectList, enemies in pairs(enemyEffects) do
        if enemies[1].Ref:IsDead() or enemies[2].Ref:IsDead() then
            enemyEffects[effectList] = nil
            for _, effect in pairs(effectList) do
                QUEUE:AddItem(0, EL.EFFECT_FADE_TIME,
                function(t)
                    effect.Ref:GetSprite().Color.A = (1.0 - t / EL.EFFECT_FADE_TIME) * EL.EFFECT_ALPHA
                end, QUEUE.UpdateType.Update)
                QUEUE:AddItem(EL.EFFECT_FADE_TIME, 0,
                function()
                    effect.Ref:Remove()
                end, QUEUE.UpdateType.Update)
            end
        else
            if enemies[1].Ref:IsFrame(EL.ENEMY_COLOR_INTERVAL, 1) then
                local color1 = enemies[1].Ref:GetSprite().Color
                local color2 = enemies[2].Ref:GetSprite().Color
                local origColor1 = Color(color1.R, color1.G, color1.B, color1.A)
                local origColor2 = Color(color2.R, color2.G, color2.B, color2.A)
                QUEUE:AddItem(0, EL.ENEMY_COLOR_DUR,
                function(t)
                    if enemies[1].Ref and enemies[2].Ref then
                        enemies[1].Ref:GetSprite().Color = Color.Lerp(origColor1, EL.ENEMY_COLOR, t / EL.ENEMY_COLOR_DUR)
                        enemies[2].Ref:GetSprite().Color = Color.Lerp(origColor2, EL.ENEMY_COLOR, t / EL.ENEMY_COLOR_DUR)
                    end
                end, QUEUE.UpdateType.Update)
                QUEUE:AddItem(EL.ENEMY_COLOR_DUR, EL.ENEMY_COLOR_DUR,
                function(t)
                    if enemies[1].Ref and enemies[2].Ref then
                        enemies[1].Ref:GetSprite().Color = Color.Lerp(EL.ENEMY_COLOR, origColor1, t / EL.ENEMY_COLOR_DUR)
                        enemies[2].Ref:GetSprite().Color = Color.Lerp(EL.ENEMY_COLOR, origColor2, t / EL.ENEMY_COLOR_DUR)
                    end
                end, QUEUE.UpdateType.Update)
            end
            for i, effect in pairs(effectList) do
                effect.Ref.Position = UTILS.LerpV(enemies[1].Ref.Position, enemies[2].Ref.Position, (i + 1) / (EL.EFFECT_AMOUNT + 2))
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, EL.OnUpdate)

---comment
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