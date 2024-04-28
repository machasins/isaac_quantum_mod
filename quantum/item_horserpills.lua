Quantum.QP = {}
local game = Game()
local rng = RNG()

---@type UTILS
local UTILS = include("quantum.utils")

local QP_ID = Isaac.GetItemIdByName("Clyde Pills")
Quantum.QP.ID = QP_ID

local PILLS_GOOD = {
    PillEffect.PILLEFFECT_BAD_GAS,
    PillEffect.PILLEFFECT_BALLS_OF_STEEL,
    PillEffect.PILLEFFECT_BOMBS_ARE_KEYS,
    PillEffect.PILLEFFECT_EXPLOSIVE_DIARRHEA,
    PillEffect.PILLEFFECT_FULL_HEALTH,
    PillEffect.PILLEFFECT_HEALTH_UP,
    PillEffect.PILLEFFECT_I_FOUND_PILLS,
    PillEffect.PILLEFFECT_PUBERTY,
    PillEffect.PILLEFFECT_PRETTY_FLY,
    PillEffect.PILLEFFECT_RANGE_UP,
    PillEffect.PILLEFFECT_SPEED_UP,
    PillEffect.PILLEFFECT_TEARS_UP,
    PillEffect.PILLEFFECT_LUCK_UP,
    PillEffect.PILLEFFECT_TELEPILLS,
    PillEffect.PILLEFFECT_48HOUR_ENERGY,
    PillEffect.PILLEFFECT_HEMATEMESIS,
    PillEffect.PILLEFFECT_SEE_FOREVER,
    PillEffect.PILLEFFECT_PHEROMONES,
    PillEffect.PILLEFFECT_LEMON_PARTY,
    PillEffect.PILLEFFECT_PERCS,
    PillEffect.PILLEFFECT_ADDICTED,
    PillEffect.PILLEFFECT_QUESTIONMARK,
    PillEffect.PILLEFFECT_LARGER,
    PillEffect.PILLEFFECT_SMALLER,
    PillEffect.PILLEFFECT_INFESTED_EXCLAMATION,
    PillEffect.PILLEFFECT_INFESTED_QUESTION,
    PillEffect.PILLEFFECT_POWER,
    PillEffect.PILLEFFECT_FRIENDS_TILL_THE_END,
    PillEffect.PILLEFFECT_X_LAX,
    PillEffect.PILLEFFECT_SOMETHINGS_WRONG,
    PillEffect.PILLEFFECT_IM_DROWSY,
    PillEffect.PILLEFFECT_GULP,
    PillEffect.PILLEFFECT_HORF,
    PillEffect.PILLEFFECT_SUNSHINE,
    PillEffect.PILLEFFECT_VURP,
    PillEffect.PILLEFFECT_SHOT_SPEED_UP,
}

local IS_PILL_GOOD = {}
for _, k in pairs(PILLS_GOOD) do
    IS_PILL_GOOD[k] = true
end

local PILLS_BAD = {
    PillEffect.PILLEFFECT_BAD_TRIP,
    PillEffect.PILLEFFECT_HEALTH_DOWN,
    PillEffect.PILLEFFECT_I_FOUND_PILLS,
    PillEffect.PILLEFFECT_PUBERTY,
    PillEffect.PILLEFFECT_RANGE_DOWN,
    PillEffect.PILLEFFECT_SPEED_DOWN,
    PillEffect.PILLEFFECT_TEARS_DOWN,
    PillEffect.PILLEFFECT_LUCK_DOWN,
    PillEffect.PILLEFFECT_PARALYSIS,
    PillEffect.PILLEFFECT_AMNESIA,
    PillEffect.PILLEFFECT_WIZARD,
    PillEffect.PILLEFFECT_ADDICTED,
    PillEffect.PILLEFFECT_RELAX,
    PillEffect.PILLEFFECT_QUESTIONMARK,
    PillEffect.PILLEFFECT_RETRO_VISION,
    PillEffect.PILLEFFECT_X_LAX,
    PillEffect.PILLEFFECT_IM_EXCITED,
    PillEffect.PILLEFFECT_HORF,
    PillEffect.PILLEFFECT_SHOT_SPEED_DOWN,
}

local IS_PILL_BAD = {}
for _, k in pairs(PILLS_BAD) do
    IS_PILL_BAD[k] = true
end

local PILLS_NEUTRAL = {
    PillEffect.PILLEFFECT_I_FOUND_PILLS,
    PillEffect.PILLEFFECT_PUBERTY,
    PillEffect.PILLEFFECT_RELAX,
    PillEffect.PILLEFFECT_EXPERIMENTAL,
}

local IS_PILL_NEUTRAL = {}
for _, k in pairs(PILLS_NEUTRAL) do
    IS_PILL_NEUTRAL[k] = true
end

local hasItem = false

function Quantum.QP:OnPickupSpawn(type, var, sub, _, _, _, seed)
    if type == EntityType.ENTITY_PICKUP and var == PickupVariant.PICKUP_PILL and sub < PillColor.PILL_GIANT_FLAG and UTILS.AnyPlayerHasCollectible(QP_ID) then
        return {
            type,
            var,
            sub + PillColor.PILL_GIANT_FLAG,
            seed
        }
    end
end

Quantum:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, Quantum.QP.OnPickupSpawn)

---
---@param pickup EntityPickup
function Quantum.QP:OnPickupUpdate(pickup)
    if pickup.Variant == PickupVariant.PICKUP_PILL and pickup.SubType < PillColor.PILL_GIANT_FLAG and UTILS.AnyPlayerHasCollectible(QP_ID) then
        pickup:Morph(pickup.Type, pickup.Variant, pickup.SubType + PillColor.PILL_GIANT_FLAG, true, true, false)
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, Quantum.QP.OnPickupUpdate)

---
---@param player EntityPlayer
function Quantum.QP:OnPlayerUpdate(player)
    if player:HasCollectible(QP_ID) then
        for slot = 0, 3 do
            local pill = player:GetPill(slot)
            if pill > 0 and pill < PillColor.PILL_GIANT_FLAG then
                player:SetPill(slot, pill + PillColor.PILL_GIANT_FLAG)
            end
        end
    end
    if player.QueuedItem.Item and player.QueuedItem.Item.ID == QP_ID then
        hasItem = true
    elseif hasItem == true then
        Isaac.Spawn(
            EntityType.ENTITY_PICKUP,
            PickupVariant.PICKUP_PILL,
            game:GetItemPool():GetPill(rng:RandomInt(80)),
            game:GetLevel():GetCurrentRoom():FindFreePickupSpawnPosition(player.Position, 0, true, false),
            Vector(0,0),
            player
        )
        hasItem = false
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, Quantum.QP.OnPlayerUpdate)

---comment
---@param pillEffect PillEffect
---@param player EntityPlayer
---@return PillEffect?
function Quantum.QP:OnPillUse(pillEffect, player, flags)
    if player:HasCollectible(QP_ID) then
        local save = Quantum.save.GetRunSave()
        save.pillEffects = save.pillEffects or {}
        for color, effect in pairs(save.pillEffects) do
            if IS_PILL_NEUTRAL[effect] then
                save.pillEffects[color .. ""] = PILLS_NEUTRAL[rng:RandomInt(#PILLS_NEUTRAL)]
            end
            if IS_PILL_BAD[effect] then
                save.pillEffects[color .. ""] = PILLS_BAD[rng:RandomInt(#PILLS_BAD)]
            end
            if IS_PILL_GOOD[effect] then
                save.pillEffects[color .. ""] = PILLS_GOOD[rng:RandomInt(#PILLS_GOOD)]
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_USE_PILL, Quantum.QP.OnPillUse)

---comment
---@param pillEffect PillEffect
---@param pillColor PillColor
---@return PillEffect?
function Quantum.QP:GetPillEffect(pillEffect, pillColor)
    if UTILS.AnyPlayerHasCollectible(QP_ID) then
        local save = Quantum.save.GetRunSave()
        local pillEffects = save.QP or {}
        if not pillEffects[pillColor .. ""] then
            pillEffects[pillColor .. ""] = pillEffect
        end
        return pillEffects[pillColor .. ""]
    end
end

Quantum:AddCallback(ModCallbacks.MC_GET_PILL_EFFECT, Quantum.QP.GetPillEffect)

if EID then
    EID:addCollectible(
        QP_ID,
        "{{Pill}} All pills become horse pills" ..
        "#↓ After using a pill, all pill effects are randomized"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(QP_ID, "Gives an additional 10% chance")
    end
end