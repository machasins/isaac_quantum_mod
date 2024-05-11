Quantum.EnemyLink = {}
local FP = Quantum.EnemyLink

FP.ID = Isaac.GetItemIdByName("Frying Pan")
---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

FP.CRIT_BASE_CHANCE = 0.05
FP.CRIT_LUCK_MULT = 0.01
FP.CRIT_MIN_CHANCE = 0.01
FP.CRIT_MAX_CHANCE = 0.25

---comment  
---@param player EntityPlayer
function FP:OnPlayerInit(player)
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, FP.OnPlayerInit)

---comment  
---@param player EntityPlayer
function FP:OnPlayerUpdate(player)
    if player.FrameCount == 1 then
    else
        --player:GetActiveWeaponEntity().Variant = 0
        --[[ local knife = player:GetActiveWeaponEntity()
        if knife ~= nil then
            print("EntityFlags:")
            for i, e in pairs(EntityFlag) do
                if knife:HasEntityFlags(e) then
                    print("i: " .. i .. ", v:" .. tostring(knife:HasEntityFlags(e)))
                end
            end
            local vars = {"Child", "CollisionDamage", "Color", "DepthOffset", "DropSeed", "EntityCollisionClass", "FlipX", "FrameCount", "Friction", "GridCollisionClass",
        "HitPoints", "Index", "InitSeed", "Mass", "MaxHitPoints", "Parent", "Position", "PositionOffset", "RenderZOffset", "Size", "SizeMulti", "SortingLayer", "SpawnerEntity",
        "SpawnerType", "SpawnerVariant", "SpawnGridIndex", "SplatColor", "SpriteOffset", "SpriteRotation", "SpriteScale", "SubType", "Target", "TargetPosition", "Type",
        "Variant", "Velocity", "Visible"}
            print("Vars")
            for _, e in pairs(vars) do
                print(e .. ": " .. tostring(knife[e]))
            end
        end ]]
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, FP.OnPlayerUpdate)

if EID then
    EID:addCollectible(
        FP.ID,
        "{{Heart}} 5% to link two enemies together and share any damage received" ..
        "#{{BrokenHeart}} When a linked enemy dies, it damages the other for a percentage of its health" ..
        "#{{Luck}} 25% chance at 20 Luck"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(FP.ID, "Gives a chance to link another two enemies")
    end
end