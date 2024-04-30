--#region TEAR

---@class TEAR
---@field normal table The normal tears that have been tracked
---@field spawned table The tears that have been spawned and tracked
---@field isSpawning boolean If the system is currently spawning a tear
---@field SPAWN_TIME number How long the spawn animation for the tear takes
---@field FIRE_TIME number When the tear gets fired at an enemy
---@field DAMAGE number The percent of damage the tear should do
---@field SCALE number The percent of original scale the tear should be
---@field INITIAL_HEIGHT number How high the tear should be when rising from the ground
---@field FOLLOW_PLAYER boolean If the tear should follow the player
---@field FOLLOW_SPEED number How fast should the tear follow the player
---@field SPAWN_MAX_DISTANCE number The max distance away from the player to spawn the tear, when the tears are following the player
---@field SPAWN_MIN_DISTANCE number The min distance away from the player to spawn the tear, when the tears are following the player
---@field FLAG_REMOVE_LIST TearFlags[] What tear flags should be removed from the tear when it is spawned
---@field FLAG_READD_LIST TearFlags[] What tear flags should be removed until the tear is fired
---@field FLAG_MATCH_LIST TearFlags[] What tear flags should match the base flags in order to consider spawning (stops infinite tear spawning)
Quantum.Hydrokinesis.Tear = {}
local TEAR = Quantum.Hydrokinesis.Tear

TEAR.SPAWN_TIME = 30
TEAR.FIRE_TIME = 50
TEAR.DAMAGE = 0.5
TEAR.SCALE = 0.75
TEAR.INITIAL_HEIGHT = -10

TEAR.FOLLOW_PLAYER = false
TEAR.FOLLOW_SPEED = 0.75
TEAR.SPAWN_MAX_DISTANCE = 60
TEAR.SPAWN_MIN_DISTANCE = 30

TEAR.FLAG_REMOVE_LIST = {
    TearFlags.TEAR_LASERSHOT,
    TearFlags.TEAR_ORBIT,
    TearFlags.TEAR_ORBIT_ADVANCED,
    TearFlags.TEAR_TRACTOR_BEAM,
    TearFlags.TEAR_WAIT,
    TearFlags.TEAR_OCCULT,
}

TEAR.FLAG_READD_LIST = {
    TearFlags.TEAR_HYDROBOUNCE,
    TearFlags.TEAR_SHRINK,
}

TEAR.FLAG_MATCH_LIST = {
    TearFlags.TEAR_SPLIT,
    TearFlags.TEAR_QUADSPLIT,
    TearFlags.TEAR_BOUNCE,
    TearFlags.TEAR_CONTINUUM,
    TearFlags.TEAR_BONE,
    TearFlags.TEAR_ABSORB,
    TearFlags.TEAR_BOUNCE_WALLSONLY,
    TearFlags.TEAR_FETUS_BOMBER,
}

--#endregion

--#region LASER

---@class LASER
---@field normal table Keeps track of the normal lasers that have been spawned
---@field spawned table Keeps track of the lasers that have been spawned by the script
---@field effect table Keeps track of the effects that have been spawned by the script
---@field DAMAGE number Percent of damage the laser deals
---@field FOLLOW_PLAYER boolean If the laser should follow the player
---@field FOLLOW_SPEED number The follow speed of the laser
---@field SPAWN_MAX_DISTANCE number The max distance the laser should spawn away from the player, if the laser follows the player
---@field SPAWN_MIN_DISTANCE number The min distance the laser should spawn away from the player, if the laser follows the player
---@field TYPE table The types of laser, generalized
---@field VAR_TO_TYPE table<LaserVariant, TYPE> Convert the variant of laser into the generalized type
---@field SUB_TO_TYPE table<LaserSubType, TYPE> Convert the subtype of laser into the generalized type (Checks if Tech X)
---@field TYPE_TO_WEAPON table<TYPE, WeaponType> Convert the generalized type into a weaponType used by the player
---@field TIME table<TYPE, { SPAWN: integer, FIRE: integer }> The spawn and fire times for each type of laser
---@field FLAG_REMOVE_LIST TearFlags[] Flags to remove before the laser is spawned
---@field FLAG_MATCH_LIST TearFlags[] Flags that should match the player's flags to spawn another laser
---@field TO_EFFECT table<TYPE, EffectVariant> Convert the generalized type into what effect it should spawn
---@field EFFECT_LIST table<EffectVariant, boolean> List of effects that are handled by this script
---@field HANDLE_LIST table<LaserVariant, boolean> List of lasers that are handled by this script
---@field WEAPON_EFFECT_ADD_LENGTH table<TYPE, number> How much time to add to the effect's lifetime, based on laser type
---@field WEAPON_EFFECT_SCALE table<TYPE, number> Percentage of the scale that the effect should have, based on laser type
---@field WEAPON_SCALE table<TYPE, number>  Percentage of the scale that the laser should have, based on laser type
---@field WEAPON_DURATION table<TYPE, number>  How long the laser should last, based on laser type
Quantum.Hydrokinesis.Laser = {}
local LASER = Quantum.Hydrokinesis.Laser

LASER.DAMAGE = 0.4

LASER.FOLLOW_PLAYER = false
LASER.FOLLOW_SPEED = 0.75
LASER.SPAWN_MAX_DISTANCE = 60
LASER.SPAWN_MIN_DISTANCE = 30

---@enum TYPE
LASER.TYPE = {
    TECH = 1,
    BRIMSTONE = 2,
    TECHX = 3,
}

LASER.VAR_TO_TYPE = {
    [LaserVariant.THICK_RED] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.THIN_RED] = LASER.TYPE.TECH,
    [LaserVariant.SHOOP] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.PRIDE] = LASER.TYPE.TECH,
    [LaserVariant.LIGHT_BEAM] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.GIANT_RED] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.TRACTOR_BEAM] = LASER.TYPE.TECH,
    [LaserVariant.LIGHT_RING] = LASER.TYPE.TECH,
    [LaserVariant.BRIM_TECH] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.ELECTRIC] = LASER.TYPE.TECH,
    [LaserVariant.THICKER_RED] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.THICK_BROWN] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.BEAST] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.THICKER_BRIM_TECH] = LASER.TYPE.BRIMSTONE,
    [LaserVariant.GIANT_BRIM_TECH] = LASER.TYPE.BRIMSTONE,
}

LASER.SUB_TO_TYPE = {
    [LaserSubType.LASER_SUBTYPE_RING_LUDOVICO] = LASER.TYPE.TECHX,
    [LaserSubType.LASER_SUBTYPE_RING_PROJECTILE] = LASER.TYPE.TECHX,
    [LaserSubType.LASER_SUBTYPE_RING_FOLLOW_PARENT] = LASER.TYPE.TECHX
}

LASER.TYPE_TO_WEAPON = {
    [LASER.TYPE.TECHX] = WeaponType.WEAPON_TECH_X,
    [LASER.TYPE.BRIMSTONE] = WeaponType.WEAPON_BRIMSTONE,
    [LASER.TYPE.TECH] = WeaponType.WEAPON_LASER,
}

LASER.TIME = {
    [LASER.TYPE.TECHX] = { SPAWN = 40, FIRE = 60 },
    [LASER.TYPE.BRIMSTONE] = { SPAWN = 30, FIRE = 40 },
    [LASER.TYPE.TECH] = { SPAWN = 20, FIRE = 30 },
}

LASER.FLAG_REMOVE_LIST = {
    TearFlags.TEAR_LASERSHOT,
    TearFlags.TEAR_ORBIT,
    TearFlags.TEAR_ORBIT_ADVANCED,
    TearFlags.TEAR_TRACTOR_BEAM,
    TearFlags.TEAR_WAIT,
    TearFlags.TEAR_OCCULT,
}

LASER.FLAG_MATCH_LIST = {
    TearFlags.TEAR_SPLIT,
    TearFlags.TEAR_QUADSPLIT,
    TearFlags.TEAR_BOUNCE,
    TearFlags.TEAR_CONTINUUM,
    TearFlags.TEAR_BONE,
    TearFlags.TEAR_ABSORB,
    TearFlags.TEAR_BOUNCE_WALLSONLY,
    TearFlags.TEAR_FETUS_TECH,
    TearFlags.TEAR_FETUS_TECHX,
    TearFlags.TEAR_FETUS_BRIMSTONE,
}

LASER.TO_EFFECT = {
    [LASER.TYPE.TECH] = EffectVariant.TECH_DOT,
    [LASER.TYPE.BRIMSTONE] = EffectVariant.BRIMSTONE_SWIRL,
    [LASER.TYPE.TECHX] = EffectVariant.TECH_DOT,
}

LASER.EFFECT_LIST = {
    [EffectVariant.TECH_DOT] = true,
    [EffectVariant.BRIMSTONE_SWIRL] = true,
}

LASER.HANDLE_LIST = {
    [LaserVariant.THICK_RED] = true,
    [LaserVariant.THIN_RED] = true,
    [LaserVariant.LIGHT_BEAM] = true,
    [LaserVariant.GIANT_RED] = true,
    [LaserVariant.BRIM_TECH] = true,
    [LaserVariant.THICKER_RED] = true,
    [LaserVariant.THICK_BROWN] = true,
    [LaserVariant.THICKER_BRIM_TECH] = true,
}

LASER.WEAPON_EFFECT_ADD_LENGTH = {
    [LASER.TYPE.TECHX] = 5,
    [LASER.TYPE.BRIMSTONE] = 40,
    [LASER.TYPE.TECH] = 5,
}

LASER.WEAPON_EFFECT_SCALE = {
    [LASER.TYPE.TECHX] = 1.5,
    [LASER.TYPE.BRIMSTONE] = 0.6,
    [LASER.TYPE.TECH] = 1,
}

LASER.WEAPON_SCALE = {
    [LASER.TYPE.TECHX] = 0.5,
    [LASER.TYPE.BRIMSTONE] = 0.5,
    [LASER.TYPE.TECH] = 1,
}

LASER.WEAPON_DURATION = {
    [LASER.TYPE.TECHX] = 0,
    [LASER.TYPE.BRIMSTONE] = 15,
    [LASER.TYPE.TECH] = 5,
}

--#endregion