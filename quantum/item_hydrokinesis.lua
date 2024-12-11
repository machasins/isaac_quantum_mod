Quantum.Hydrokinesis = {}
local HK = Quantum.Hydrokinesis

---@class UTILS
HK.UTILS = include("quantum.utils")

HK.ID = Isaac.GetItemIdByName("Hydrokinesis")

HK.Luck = {}
local LUCK = HK.Luck

-- Base chance for a tear to spawn
LUCK.BASE_CHANCE = 0.2
-- Additional chance for extra copies
LUCK.ADD_CHANCE = 0.1
-- Chance for every Luck the player has
LUCK.MULTIPLIER = 0.012
-- Minimum chance for a tear to spawn
LUCK.MIN_CHANCE = 0.05
-- Maximum chance for a tear to spawn
LUCK.MAX_CHANCE = 0.8

-- Multiplier for bigger rooms
HK.ROOM_MULTIPLIER = {
    [RoomShape.ROOMSHAPE_1x1] = 1,
    [RoomShape.ROOMSHAPE_IH] = 0.75,
    [RoomShape.ROOMSHAPE_IV] = 0.75,
    [RoomShape.ROOMSHAPE_1x2] = 2,
    [RoomShape.ROOMSHAPE_IIV] = 1.75,
    [RoomShape.ROOMSHAPE_2x1] = 2,
    [RoomShape.ROOMSHAPE_IIH] = 1,
    [RoomShape.ROOMSHAPE_2x2] = 4,
    [RoomShape.ROOMSHAPE_LTL] = 3,
    [RoomShape.ROOMSHAPE_LTR] = 3,
    [RoomShape.ROOMSHAPE_LBL] = 3,
    [RoomShape.ROOMSHAPE_LBR] = 3,
}

-- Which weapons will trigger the item
HK.VALID_WEAPONS = {
    [WeaponType.WEAPON_TEARS] = true,
    [WeaponType.WEAPON_BRIMSTONE] = true,
    [WeaponType.WEAPON_LASER] = true,
    [WeaponType.WEAPON_KNIFE] = true,
    [WeaponType.WEAPON_BOMBS] = true,
    [WeaponType.WEAPON_LUDOVICO_TECHNIQUE] = true,
    [WeaponType.WEAPON_TECH_X] = true,
    [WeaponType.WEAPON_BONE] = true,
    [WeaponType.WEAPON_SPIRIT_SWORD] = true,
    [WeaponType.WEAPON_FETUS] = true,
}

-- How often continuously fired tear effects will spawn additional tears
HK.CONT_SPAWNED_COOLDOWN = 20

-- If a tear has been spawned by a continuously firing tear effect
HK.hasSpawned = false

include("quantum.item_hydrokinesis_def")
include("quantum.item_hydrokinesis_tear")
include("quantum.item_hydrokinesis_laser")

---Runs every update frame
function HK:OnUpdate()
    -- Every X frames, reset whether a tear has been spawned
    if Isaac.GetFrameCount() % HK.CONT_SPAWNED_COOLDOWN == 0 then
        HK.hasSpawned = false
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, HK.OnUpdate)

if EID then
    EID:addCollectible(
        HK.ID,
        "{{Tearsize}} 20% chance to summon a tear randomly in the room when firing a tear" ..
        "#{{Bait}} Summoned tears are fired at the nearest enemy" ..
        "#{{Luck}} 80% chance at 50 Luck"
    )
end