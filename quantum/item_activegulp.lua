Quantum.ArtificalBloom = {}
local BG = Quantum.ArtificalBloom
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

-- ID of the item
BG.ID = Isaac.GetItemIdByName("Big Gulp")

-- The list of pickups that can trigger reroll
local pickupCollisionList = {}

---Run when colliding with a pickup
---@param entity EntityPickup
---@param collider Entity
function BG:OnPickupCollision(entity, collider, _)
    local player = collider:ToPlayer()
    if entity.Variant == PickupVariant.PICKUP_COLLECTIBLE and player and player:HasCollectible(BG.ID) then
        -- Insert into a list for later
        table.insert(pickupCollisionList, { player=player, pickup=entity })
    end
end

Quantum:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, BG.OnPickupCollision)

---Run every update frame
function BG:PickupUpdate()
    -- Loop through all players
    for _, data in pairs(pickupCollisionList) do
        -- Get specific player
        ---@type EntityPlayer
        local player = data.player
        -- Get the entity the 
        ---@type EntityPickup
        local entity = data.pickup
        -- Check if the player has the item and is holding up an item
        if player.QueuedItem.Item ~= nil and player.QueuedItem.Item:IsCollectible() then
            if player.QueuedItem.Item.Type == ItemType.ITEM_ACTIVE then
                Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.ABYSS_LOCUST, entity.SubType, entity.Position, Vector.Zero, player)
                entity:Remove()
            end
        end
    end
    pickupCollisionList = {}
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, BG.PickupUpdate)

if EID then
    EID:addCollectible(
        BG.ID,
        "{{Battery}} When picking up an active item, 'gulp' your current active item and replace it with the new active item" ..
        "#{{Pill}} 'Gulping' an active item gives you the {{Collectible706}} locust for that active item" ..
        "#{{AngelChance}} Using an active item gives a wisp of a random active item that has been 'gulped'"
    )
end