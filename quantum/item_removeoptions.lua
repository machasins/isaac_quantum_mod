Quantum.RemoveOptions = {}
local RO = Quantum.RemoveOptions

RO.ID = Isaac.GetItemIdByName("Quantum Scissors")
---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

RO.REMOVE_CHANCE = 0.1
RO.ADDITIONAL_CHANCE = 0.1
RO.LUCK_MULT = 0.02
RO.MIN_CHANCE = 0.05
RO.MAX_CHANCE = 0.5

RO.EFFECT_SPAWN_DELAY = 30

RO.VISIBLE_OPTIONS_EFFECT = Isaac.GetEntityVariantByName("Fire Indicator")

---Remove the choice effect when choices are removed
---@param effect_type EffectVariant
---@param match CollectibleType
local function RemoveAdditionalEffect(effect_type, match)
    -- Get all possible effects that could match
    local choices = Isaac.FindByType(EntityType.ENTITY_EFFECT, effect_type)
    -- Loop through the effects
    for _, e in pairs(choices) do
        -- Check if the parent's index matches the item's index
        if e.Parent.Index == match then
            -- Remove the effect
            e:Remove()
        end
    end
end

---Chance to remove options when they spawn
---@param pickup EntityPickup
function RO:RemoveOptions(pickup)
    -- Get the save data for the floor
    local save = Quantum.save.GetFloorSave()
    save.pickupHashes = save.pickupHashes or {}
    -- Check if the save data for the pickup exists
    if not save.pickupHashes[pickup.Index .. ""] then
        -- Check if the pickup is tied to other items
        if pickup.OptionsPickupIndex ~= 0 then
            -- Chance to remove Options
            -- Get the number of items all players have
            local numItem = UTILS.GetPlayerCollectibleNum(RO.ID)
            -- Get the highest luck stat of the players
            local highestPlayerLuck = UTILS.GetHighestPlayerStat("Luck", RO.ID)
            -- If any player has the item
            if numItem > 0 then
                -- Get the RNG object for the item
                local rng = UTILS.GetCollectibleRNG(RO.ID)
                -- Get the chance for the options to remove from the item
                local chance = UTILS.GetLuckChance(highestPlayerLuck, RO.REMOVE_CHANCE + RO.ADDITIONAL_CHANCE * (numItem - 1), RO.LUCK_MULT, RO.MIN_CHANCE, RO.MAX_CHANCE)
                -- Check if the luck check is passed
                if rng:RandomFloat() <= chance then
                    -- Remove the item from options
                    pickup.OptionsPickupIndex = 0
                    -- Spawn an effect to indicate it was removed
                    QUEUE:AddItem(RO.EFFECT_SPAWN_DELAY, 0, function()
                        local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, pickup.Position, Vector.Zero, nil)
                        effect:GetSprite().Color:SetOffset(0,1,1)
                        effect:GetSprite().Color.A = 0.75
                    end, QUEUE.UpdateType.Update)
                    -- Remove the effect from Choice Viewer
                    RemoveAdditionalEffect(RO.VISIBLE_OPTIONS_EFFECT, pickup.Index)
                end
            end
        end
        -- Save the item as processed
        save.pickupHashes[pickup.Index .. ""] = true
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, RO.RemoveOptions)

if EID then
    EID:addCollectible(
        RO.ID,
        "{{TreasureRoomChance}} 10% chance to decouple a pickup from other linked pickups" ..
        "#This includes Alt Path treasure rooms, all Options items, Angel rooms, Boss Rush, etc." ..
        "#{{Luck}} 50% chance at 20 Luck"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(RO.ID, "Gives an additional 10% chance")
    end
end