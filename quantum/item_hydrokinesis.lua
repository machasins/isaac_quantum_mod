Quantum.QW = {}

---@class UTILS
Quantum.QW.UTILS = include("quantum.utils")

Quantum.QW.ID = Isaac.GetItemIdByName("Hydrokinesis")

Quantum.QW.Luck = {}
local LUCK = Quantum.QW.Luck

LUCK.BASE_CHANCE = 0.2
LUCK.ADD_CHANCE = 0.1
LUCK.MULTIPLIER = 0.05
LUCK.MIN_CHANCE = 0.05
LUCK.MAX_CHANCE = 0.8

Quantum.QW.ROOM_MULTIPLIER = {
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

Quantum.QW.VALID_WEAPONS = {
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

Quantum.QW.CONT_SPAWNED_COOLDOWN = 20

Quantum.QW.hasSpawned = false

include("quantum.item_hydrokinesis_def")
include("quantum.item_hydrokinesis_tear")
include("quantum.item_hydrokinesis_laser")


function Quantum.QW:OnUpdate()
    if Isaac.GetFrameCount() % Quantum.QW.CONT_SPAWNED_COOLDOWN == 0 then
        Quantum.QW.hasSpawned = false
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_UPDATE, Quantum.QW.OnUpdate)

if EID then
    EID:addCollectible(
        Quantum.QW.ID,
        "Gives a 10% chance to decouple a pickup from other linked pickups" ..
        "#This includes Alt Path treasure rooms, all Options items, Angel rooms, Boss Rush, etc."
    )

    if EIDD then
        EIDD:addDuplicateCollectible(Quantum.QW.ID, "Gives an additional 10% chance")
    end
end