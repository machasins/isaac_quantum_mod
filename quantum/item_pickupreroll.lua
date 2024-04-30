Quantum.PickupReroll = {}
local PR = Quantum.PickupReroll
local game = Game()

---@type UTILS
local UTILS = include("quantum.utils")
---@type QUEUE
local QUEUE = include("quantum.sys_queue")

-- ID of the item
PR.ID = Isaac.GetItemIdByName("Butterfly's Effect")

-- Which pickups are valid to trigger reroll
PR.VALID_PICKUPS = {
    [PickupVariant.PICKUP_HEART]=true,
    [PickupVariant.PICKUP_COIN]=true,
    [PickupVariant.PICKUP_BOMB]=true,
    [PickupVariant.PICKUP_KEY]=true,
    [PickupVariant.PICKUP_POOP]=true,
    [PickupVariant.PICKUP_LIL_BATTERY]=true
}

-- The list of pickups that can trigger reroll
local pickupCollisionList = {}

---Mark any pickups that the palyer is interacting with
---@param entity EntityPickup
---@param collider Entity
function PR:OnPickupInteract(entity, collider, _)
    -- Check if the collider is a player
    local player = collider:ToPlayer()
    -- Check if the palyer has the item and that the pickup is a valid reroll candidate
    if player and player:HasCollectible(PR.ID) and PR.VALID_PICKUPS[entity.Variant] then
        -- Insert into a list for later
        table.insert(pickupCollisionList, entity)
    end
end

Quantum:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, PR.OnPickupInteract)

---Reroll the current room
function PR:RerollRoom()
    -- Loop through all collectibles
    for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
        -- The itempool for the run
        local pool = game:GetItemPool()
        -- The current room's itempool
        local roomPool = pool:GetPoolForRoom(game:GetRoom():GetType(), RNG():GetSeed())
        -- The item ID the item should reroll into
        local rerolledItemID = pool:GetCollectible(roomPool, true)
        -- Morph the item into the rerolled item
        e:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, rerolledItemID, true)
        -- Spawn a poof effect to signify reroll
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, e.Position, Vector.Zero, nil)
    end
end

---Run every update frame
function PR:PickupUpdate()
    -- The save data for the room
    local save = Quantum.save.GetRoomSave()

    --- Check if save data exists and if any player has the item
    if save and UTILS.AnyPlayerHasCollectible(PR.ID) then
        -- Loop through the pickups that have been collided with
        for _, pickup in ipairs(pickupCollisionList) do
            -- Check if the pickup is playing it's collection animation
            if pickup:IsDead() then
                -- REROLL!
                PR:RerollRoom()
                -- Only one reroll per collecting pickups
                break
            end
        end
        pickupCollisionList = {}
        
        -- Initalize save data for player's picking up items
        save.playerHasItem = save.playerHasItem or {}
        -- Get number of players
        local numPlayers = game:GetNumPlayers()
        -- Loop through all players
        for i = 0, numPlayers - 1 do
            -- Get specific player
            local player = Isaac.GetPlayer(i)
            -- Check if the player has the item and is holding up an item
            if player:HasCollectible(PR.ID) and player.QueuedItem.Item ~= nil and player.QueuedItem.Item:IsCollectible() then
                -- If the player has not held up an item in the previous frame
                if not save.playerHasItem[i] then
                    -- Queue the reroll to happen in five frames (prevents empty item pedestals from generating new items)
                    QUEUE:AddItem(5, PR.RerollRoom)
                    -- Mark that the player has picked up an item
                    save.playerHasItem[i] = true
                end
            elseif save.playerHasItem[i] then
                -- Reset the ability for a player picking up an item to reroll
                save.playerHasItem[i] = false
            end
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, PR.PickupUpdate)

if EID then
    EID:addCollectible(
        PR.ID,
        "Rerolls pedestal items in the room when a pickup is collected" ..
        "#Rerolls when collecting: #{{Blank}} {{Heart}}, {{Coin}}, {{Bomb}}, {{Key}}, {{Battery}}, {{PoopPickup}}, {{Collectible}}" ..
        "#Does not reroll when collecting: #{{Blank}} {{Pill}}, {{Card}}, {{Rune}}, {{Trinket}}, {{GrabBag}}, {{Chest}}"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(PR.ID, "No additional effect")
    end
end