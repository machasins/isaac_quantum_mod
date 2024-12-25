Quantum.D4Sale = {}
local DS = Quantum.D4Sale
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS

local GetSharedData = UTILS.FuncGetData("q_smds")

local devilPriceToWeight = {
    [PickupPrice.PRICE_ONE_SOUL_HEART] = 1,
    [PickupPrice.PRICE_TWO_SOUL_HEARTS] = 2,
    [PickupPrice.PRICE_ONE_HEART] = 3,
    [PickupPrice.PRICE_THREE_SOULHEARTS] = 4,
    [PickupPrice.PRICE_ONE_HEART_AND_ONE_SOUL_HEART] = 5,
    [PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS] = 6,
    [PickupPrice.PRICE_TWO_HEARTS] = 7,
}

local weightToDevilPrice = {
    [1] = PickupPrice.PRICE_ONE_SOUL_HEART,
    [2] = PickupPrice.PRICE_TWO_SOUL_HEARTS,
    [3] = PickupPrice.PRICE_ONE_HEART,
    [4] = PickupPrice.PRICE_THREE_SOULHEARTS,
    [5] = PickupPrice.PRICE_ONE_HEART_AND_ONE_SOUL_HEART,
    [6] = PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS,
    [7] = PickupPrice.PRICE_TWO_HEARTS,
}

local staticPrices = {
    [PickupPrice.PRICE_SPIKES] = true,
    [PickupPrice.PRICE_SOUL] = true,
    [PickupPrice.PRICE_FREE] = true,
}

-- ID of the item
DS.ID = Isaac.GetItemIdByName("Haggled Dice")

---When the item is used
---@param id CollectibleType
---@param RNG RNG
---@param player EntityPlayer
---@param Flags any
---@param Slot any
---@param CustomVarData any
function DS:OnUseItem(id, RNG, player, Flags, Slot, CustomVarData)
    -- If any prices were changed
    local priceUpdate = false
    -- Loop through all pickups
    for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
        -- If the collectible has a price
        if e:ToPickup().Price ~= 0 and not staticPrices[e:ToPickup().Price] then
            -- The data for the item
            local data = GetSharedData(e)
            -- The saved original price of the item
            data.OriginalPrice = data.OriginalPrice ~= nil and data.OriginalPrice or e:ToPickup().Price
            -- The current price of the item
            local price = e:ToPickup().Price
            -- Loop multiple times to prevent the same price from coming up when rolled
            for _ = 1, 20 do
                -- The price or the weight of the devil deal price
                local weightedPrice = data.OriginalPrice > 0 and data.OriginalPrice or devilPriceToWeight[data.OriginalPrice]
                -- The minimum price that can be rerolled into
                local min = math.abs(math.ceil(weightedPrice * 0.25))
                -- The maximum price that can be rerolled into
                local max = math.abs(math.floor(weightedPrice * 2))
                -- The random price that was chosen
                local subPrice = math.max(math.floor(player:GetCollectibleRNG(DS.ID):RandomFloat() * (max - min) + min), 1)
                -- The price adjusted for devil deals
                local newPrice = data.OriginalPrice > 0 and subPrice or weightToDevilPrice[math.min(subPrice, #weightToDevilPrice)]
                -- Check if this is actually a new price
                if price ~= newPrice then
                    price = newPrice
                    break
                end
            end
            -- Make sure the price has changed
            if price ~= e:ToPickup().Price then
                -- Set the price
                e:ToPickup().Price = price
                -- Stop the price from updating back to what it was
                e:ToPickup().AutoUpdatePrice = false
                -- Spawn a poof effect to signify reroll
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, e.Position, Vector.Zero, nil)
                -- Signify that a price was rerolled
                priceUpdate = true
            end
            
        end
    end

    if priceUpdate then
        return {
            Discharge = true,
            Remove = false,
            ShowAnim = true,
        }
    end
end

Quantum:AddCallback(ModCallbacks.MC_USE_ITEM, DS.OnUseItem, DS.ID)

if EID then
    EID:addCollectible(
        DS.ID,
        "{{Collectible64}} Rerolls the costs of all items in the room to a random amount" ..
        "# Prices range from a quarter of the original cost to double it" ..
        "#{{DevilChance}} Devil deals will change to similar heart amounts" ..
        "#{{Warning}} Will not consume charges if no prices were changed"
    )
end