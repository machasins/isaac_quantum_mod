Quantum.DicedMeat = {}
local DM = Quantum.DicedMeat
local game = Game()

-- ID of the item
DM.ID = Isaac.GetItemIdByName("Diced Meat")

---When the item is used
---@param id CollectibleType
---@param RNG RNG
---@param player EntityPlayer
---@param Flags any
---@param Slot any
---@param CustomVarData any
function DM:OnUseItem(id, RNG, player, Flags, Slot, CustomVarData)
    local save = Quantum.save.GetFloorSave(player)
    if save and player:GetDamageCooldown() <= 0 then
        local changedItem = false
        -- Loop through all collectibles
        for _, e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)) do
            -- The itempool for the run
            local pool = game:GetItemPool()
            -- The current room's itempool
            local roomPool = pool:GetPoolForRoom(game:GetRoom():GetType(), player:GetCollectibleRNG(DM.ID):Next())
            -- The item ID the item should reroll into
            local rerolledItemID = pool:GetCollectible(roomPool, true)
            -- Morph the item into the rerolled item
            e:ToPickup():Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, rerolledItemID, true)
            -- Spawn a poof effect to signify reroll
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, e.Position, Vector.Zero, nil)
            -- Track that an item has changed
            changedItem = true
        end

        -- Do not damage the player if no items were rerolled
        if changedItem == false then
            return  {
                Discharge = false,
                Remove = false,
                ShowAnim = false,
            }
        end

        -- Apply damage to the player
        save.DM_DamageAmount = save.DM_DamageAmount or 1
        local damageFlags = DamageFlag.DAMAGE_IV_BAG | DamageFlag.DAMAGE_NO_MODIFIERS | DamageFlag.DAMAGE_INVINCIBLE | DamageFlag.DAMAGE_NO_PENALTIES
        player:ResetDamageCooldown()
        player:TakeDamage(save.DM_DamageAmount, damageFlags, EntityRef(player), 0)
        save.DM_DamageAmount = save.DM_DamageAmount * 2

        return {
            Discharge = true,
            Remove = false,
            ShowAnim = true,
        }
    end
end

Quantum:AddCallback(ModCallbacks.MC_USE_ITEM, DM.OnUseItem, DM.ID)

if EID then
    EID:addCollectible(
        DM.ID,
        "{{Collectible105}} Rerolls all item pedestals in the room and damages Isaac for half a heart on use" ..
        "#{{BrokenHeart}} Amount of damage caused doubles with each use, resets every floor"
    )
end