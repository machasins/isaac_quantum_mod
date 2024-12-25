Quantum.StockMarket = {}
local SM = Quantum.StockMarket
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS

local GetSharedData = UTILS.FuncGetData("q_smds")

-- What the multipliers start at
SM.PRICE_MIN_MULT_INITIAL = 0.7
SM.PRICE_MAX_MULT_INITIAL = 2
-- The minimum values for the multipliers
SM.PRICE_MIN_MULT_MIN = 0.1
SM.PRICE_MAX_MULT_MIN = 1.4
-- The maximum values for the multipliers
SM.PRICE_MIN_MULT_MAX = 1.7
SM.PRICE_MAX_MULT_MAX = 3
-- How much to add when changed
SM.PRICE_MULT_ADD = 0.1

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
SM.ID = Isaac.GetItemIdByName("Stock Market")

---When a new room is entered
function SM:OnNewRoom()
    local save = Quantum.save.GetFloorSave()
    if save and UTILS.AnyPlayerHasCollectible(SM.ID) then
        -- Initialize the save data
        save.priceMult = save.priceMult or {}
        -- Loop through all pickups
        for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
            -- If the collectible has a price
            if e:ToPickup().Price ~= 0 and not staticPrices[e:ToPickup().Price] then
                -- The data for the item
                local data = GetSharedData(e)
                save.priceMult[e.Variant] = save.priceMult[e.Variant] or { min = 0.25, max = 2 }
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
                    local subPrice = math.max(math.floor(Isaac.GetPlayer():GetCollectibleRNG(SM.ID):RandomFloat() * (max - min) + min), 1)
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
                end
                
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, SM.OnNewRoom)

if EID then
    EID:addCollectible(
        SM.ID,
        "{{Collectible64}} Rerolls the costs of all items in the room to a random amount" ..
        "# Prices range from a quarter of the original cost to double it" ..
        "#{{DevilChance}} Devil deals will change to similar heart amounts" ..
        "#{{Warning}} Will not consume charges if no prices were changed"
    )
end