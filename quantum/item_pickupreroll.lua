Quantum.QD = {}
local game = Game()

local QD_ID = Isaac.GetItemIdByName("Butterfly's Effect")

local pickupCollisionList = {}
local pickupCollisionSubtypes = {}
local doReroll = false

function Quantum.QD:OnPickupInteract(entity, collider, low)
    local check = {
        [PickupVariant.PICKUP_HEART]=true,
        [PickupVariant.PICKUP_COIN]=true,
        [PickupVariant.PICKUP_BOMB]=true,
        [PickupVariant.PICKUP_KEY]=true,
        [PickupVariant.PICKUP_COLLECTIBLE]=true,
        [PickupVariant.PICKUP_POOP]=true,
        [PickupVariant.PICKUP_LIL_BATTERY]=true
    }
    local player = collider:ToPlayer()
    if player ~= nil and player:GetCollectibleNum(QD_ID) > 0 and check[entity.Variant] then
        if entity.Wait <= 0 and (entity.Variant ~= PickupVariant.PICKUP_COLLECTIBLE or (player:IsItemQueueEmpty() and player:CanPickupItem())) then
            table.insert(pickupCollisionList, entity)
            table.insert(pickupCollisionSubtypes, entity.SubType)
        end
    end
    return nil
end

function Quantum.QD:RerollRoom()
    for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
        local pool = game:GetItemPool()
        local roomPool = pool:GetPoolForRoom(game:GetRoom():GetType(), RNG():GetSeed())
        e:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, pool:GetCollectible(roomPool), true)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, e.Position, Vector.Zero, nil)
        pool:RemoveCollectible(e.SubType)
    end
end

function Quantum.QD:PickupUpdate()
    if doReroll then
        Quantum.QD:RerollRoom()
        doReroll = false
    end

    local numPlayers = game:GetNumPlayers()
    for num, pickup in ipairs(pickupCollisionList) do
        if pickup:IsDead() == true then
            -- REROLL!
            doReroll = true
            break
        end

        for i = 0, numPlayers - 1 do
            local player = Isaac.GetPlayer(i)
            if player.QueuedItem.Item ~= nil and player.QueuedItem.Item.ID == pickupCollisionSubtypes[num] then
                -- REROLL!
                doReroll = true
                break
            end
        end
    end

    pickupCollisionList = {}
    pickupCollisionSubtypes = {}
end

Quantum:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, Quantum.QD.OnPickupInteract)
Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, Quantum.QD.PickupUpdate)

if EID then
    EID:addCollectible(
        QD_ID,
        "{{Warning}} {{ColorError}}Passive Item#Rerolls pedestal items in the room when a pickup is collected" ..
        "#Rerolls when collecting: #{{Blank}} {{Heart}}, {{Coin}}, {{Bomb}}, {{Key}}, {{Battery}}, {{PoopPickup}}, {{Collectible}}" ..
        "#Does not reroll when collecting: #{{Blank}} {{Pill}}, {{Card}}, {{Rune}}, {{GrabBag}}, {{Chest}}"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(QD_ID, "No additional effect")
    end
end