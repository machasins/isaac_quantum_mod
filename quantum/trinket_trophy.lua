Quantum.ParticipationTrophy = {}
local PT = Quantum.ParticipationTrophy
local game = Game()

---@class UTILS
local UTILS = Quantum.UTILS

-- ID of the item
PT.ID = Isaac.GetTrinketIdByName("Participation Trophy")

PT.TEARS_UP = 0.3

local qualityZero = nil
local qualityZeroWorth = nil

---Get every quality zero item currently in the game
local function GetQualityZeroItems()
    print("reset")
    qualityZero = {}
    qualityZeroWorth = {}
    ---@diagnostic disable-next-line: undefined-field
    local maxCollectibles = Isaac.GetItemConfig():GetCollectibles().Size - 1
    local config = Isaac.GetItemConfig()
    for i = 1, maxCollectibles do
        local item = config:GetCollectible(i)
        if item and item.Quality == 0 then
            qualityZero[i] = true
            qualityZeroWorth[i] = item.Type == ItemType.ITEM_ACTIVE and 2 or 1
        end
    end
end

---Get the current amount of quality zero items the player has
---@param player EntityPlayer
local function CountQualityZero(player)
    if qualityZero == nil or qualityZeroWorth == nil then
        qualityZero = {}
        qualityZeroWorth = {}
        GetQualityZeroItems()
    end
    ---@diagnostic disable-next-line: undefined-field
    local maxCollectibles = Isaac.GetItemConfig():GetCollectibles().Size - 1
    local amount = 0
    for i = 1, maxCollectibles do
        if player:HasCollectible(i) and qualityZero[i] ~= nil then
            amount = amount + player:GetCollectibleNum(i) * qualityZeroWorth[i]
        end
    end

    return amount
end

---Runs when anything collides with a pickup
---@param player EntityPlayer
---@param flags CacheFlag
function PT:OnCacheEval(player, flags)
    local amount = CountQualityZero(player)
    player.MaxFireDelay = UTILS.toMaxFireDelay(UTILS.toTearsPerSecond(player.MaxFireDelay) + (amount * PT.TEARS_UP * player:GetTrinketMultiplier(PT.ID)))
end
Quantum:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, PT.OnCacheEval, CacheFlag.CACHE_FIREDELAY)

---Run every update frame
function PT:PickupUpdate()
    -- The save data for the room
    local save = Quantum.save.GetRoomSave()
    --- Check if save data exists
    if save then
        -- Initalize save data
        save.pt_playerHasItem = save.pt_playerHasItem or {}
        save.pt_playerQualityCount = save.pt_playerQualityCount or {}
        -- Get number of players
        local numPlayers = game:GetNumPlayers()
        -- Loop through all players
        for i = 0, numPlayers - 1 do
            -- Get specific player
            local player = Isaac.GetPlayer(i)
            -- Check if the player has the item and is holding up an item
            if player:GetTrinketMultiplier(PT.ID) and player.QueuedItem.Item ~= nil and player.QueuedItem.Item:IsCollectible() then
                -- If the player has not held up an item in the previous frame
                if not save.pt_playerHasItem[i] then
                    -- Mark that the player has picked up an item
                    save.pt_playerHasItem[i] = true
                end
            elseif save.pt_playerHasItem[i] then
                -- Trigger Cache eval
                player:AddCacheFlags(CacheFlag.CACHE_FIREDELAY)
                player:EvaluateItems()
                -- Reset the ability for a player picking up an item
                save.pt_playerHasItem[i] = false
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, PT.PickupUpdate)

if EID then
    EID:addTrinket(
        PT.ID,
        "{{ArrowUp}} +" .. PT.TEARS_UP .. " tears up for each {{Quality0}} item Isaac has"
    )
    EID:addGoldenTrinketMetadata(
        PT.ID,
        "",
        PT.TEARS_UP,
        3
    )
end