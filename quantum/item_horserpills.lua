Quantum.HorserPills = {}
local HP = Quantum.HorserPills
local game = Game()
local rng = RNG()

---@type UTILS
local UTILS = include("quantum.utils")

HP.ID = Isaac.GetItemIdByName("Clyde Pills")

--#region Pill definitions

HP.PILLS_GOOD = {
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

HP.IS_PILL_GOOD = {}
for _, k in pairs(HP.PILLS_GOOD) do
    HP.IS_PILL_GOOD[k] = true
end

HP.PILLS_BAD = {
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

HP.IS_PILL_BAD = {}
for _, k in pairs(HP.PILLS_BAD) do
    HP.IS_PILL_BAD[k] = true
end

HP.PILLS_NEUTRAL = {
    PillEffect.PILLEFFECT_I_FOUND_PILLS,
    PillEffect.PILLEFFECT_PUBERTY,
    PillEffect.PILLEFFECT_RELAX,
    PillEffect.PILLEFFECT_EXPERIMENTAL,
}

HP.IS_PILL_NEUTRAL = {}
for _, k in pairs(HP.PILLS_NEUTRAL) do
    HP.IS_PILL_NEUTRAL[k] = true
end

--#endregion

---Runs when an entity is spawned
---@param type EntityType
---@param var PickupVariant
---@param sub PillColor
---@param seed integer
---@return {Type: EntityType, Variant: integer, SubType: integer, Seed: integer}?
function HP:OnPickupSpawn(type, var, sub, _, _, _, seed)
    -- Check if the entity is a pill but not a horse pill
    -- Also check if any player has the item
    if type == EntityType.ENTITY_PICKUP and var == PickupVariant.PICKUP_PILL and sub < PillColor.PILL_GIANT_FLAG and UTILS.AnyPlayerHasCollectible(HP.ID) then
        -- Return a horse pill version of the pill
        return {
            type,
            var,
            sub + PillColor.PILL_GIANT_FLAG,
            seed
        }
    end
end

Quantum:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, HP.OnPickupSpawn)

---Runs on every update frame, for every pickup
---@param pickup EntityPickup
function HP:OnPickupUpdate(pickup)
    -- Check if the pickup is a pill but not a horse pill
    -- Also check if any player has the item
    if pickup.Variant == PickupVariant.PICKUP_PILL and pickup.SubType < PillColor.PILL_GIANT_FLAG and UTILS.AnyPlayerHasCollectible(HP.ID) then
        -- Change the pill into a horse pill
        pickup:Morph(pickup.Type, pickup.Variant, pickup.SubType + PillColor.PILL_GIANT_FLAG, true, true, false)
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, HP.OnPickupUpdate)

---Runs every update frame, for every player
---@param player EntityPlayer
function HP:OnPlayerUpdate(player)
    -- Handle changing any pills the player is holding into horse pills when having the item
    -- Check if the player has the item
    if player:HasCollectible(HP.ID) then
        -- Loop through slots for pills
        for slot = 0, 3 do
            -- The pill in the current slot
            local pill = player:GetPill(slot)
            -- Check if the pill exists and if it is not a horse pill
            if pill > 0 and pill < PillColor.PILL_GIANT_FLAG then
                -- Change the pill into a horse pill
                player:SetPill(slot, pill + PillColor.PILL_GIANT_FLAG)
            end
        end
    end

    -- Handle spawning a horse pill on pickup
    -- The mod's save data
    local save = Quantum.save.GetRunSave()
    if save then
        -- Initialize the count for player's items
        save.horserpillsCount = save.horserpillsCount or {}
        -- The previous frames count for items
        local prevCount = save.horserpillsCount[player.Index .. ""] or 0
        -- Refresh the count for items
        save.horserpillsCount[player.Index .. ""] = player:GetCollectibleNum(HP.ID)
        -- Check if the player has more of the item than they did before
        if save.horserpillsCount[player.Index .. ""] > prevCount then
            -- Spawn a random horse pill
            Isaac.Spawn(
                EntityType.ENTITY_PICKUP,
                PickupVariant.PICKUP_PILL,
                game:GetItemPool():GetPill(rng:RandomInt(80)),
                game:GetLevel():GetCurrentRoom():FindFreePickupSpawnPosition(player.Position, 0, true, false),
                Vector.Zero,
                player
            )
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, HP.OnPlayerUpdate)

---Runs whenever a pill is used
---@param pillEffect PillEffect The effect that happened
---@param player EntityPlayer The player that used the pill
function HP:OnPillUse(pillEffect, player, flags)
    -- Handle randomizing pill effects when a pill is used
    -- Check if the player has the item
    if player:HasCollectible(HP.ID) then
        -- The save data for the mod
        local save = Quantum.save.GetRunSave()
        -- Initialize the saved pill effects
        save.pillEffects = save.pillEffects or {}
        -- Loop through every saved pill effect
        for color, effect in pairs(save.pillEffects) do
            -- Change neutral pill effects into another neutral pill effect
            if HP.IS_PILL_NEUTRAL[effect] then
                save.pillEffects[color .. ""] = HP.PILLS_NEUTRAL[rng:RandomInt(#HP.PILLS_NEUTRAL)]
            end
            -- Change bad pill effects into other bad effects
            if HP.IS_PILL_BAD[effect] then
                save.pillEffects[color .. ""] = HP.PILLS_BAD[rng:RandomInt(#HP.PILLS_BAD)]
            end
            -- Change good pill effects into other good effects
            if HP.IS_PILL_GOOD[effect] then
                save.pillEffects[color .. ""] = HP.PILLS_GOOD[rng:RandomInt(#HP.PILLS_GOOD)]
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_USE_PILL, HP.OnPillUse)

---Runs whenever the game needs a pills effect
---@param pillEffect PillEffect The effect the pill should be
---@param pillColor PillColor The color the pill is
---@return PillEffect? newEffect The effect the pill is changed to
function HP:GetPillEffect(pillEffect, pillColor)
    -- Check if any player has the item
    if UTILS.AnyPlayerHasCollectible(HP.ID) then
        -- Get the mod's save data
        local save = Quantum.save.GetRunSave()
        -- Initialize the saved pill effects
        local pillEffects = save.pillEffects or {}
        -- If the current pill effect is not saved, save it
        if not pillEffects[pillColor .. ""] then
            pillEffects[pillColor .. ""] = pillEffect
        end
        -- Return the saved pill effect for the color
        return pillEffects[pillColor .. ""]
    end
end

Quantum:AddCallback(ModCallbacks.MC_GET_PILL_EFFECT, HP.GetPillEffect)

if EID then
    EID:addCollectible(
        HP.ID,
        "{{Pill}} All pills become horse pills" ..
        "#↓ After using a pill, all pill effects are randomized"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(HP.ID, "Gives an additional 10% chance")
    end
end