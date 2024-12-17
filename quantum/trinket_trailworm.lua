Quantum.TrailWorm = {}
local TW = Quantum.TrailWorm
local game = Game()

---@class UTILS
local utils = include("quantum.utils")

-- ID of the item
TW.ID = Isaac.GetTrinketIdByName("Trail Worm")

TW.FRAME_CUTOFF = 5
TW.DAMAGE_MULTIPLIER = 0.25
TW.SCALE_MULTIPLIER = 0.6
TW.FOLLOW_DISTANCE = 15.0
TW.GROW_FRAME_MAX = 10.0
TW.REMOVE_FLAGS = TearFlags.TEAR_ORBIT

---When the item is used
---@param tear EntityTear
function TW:OnTearUpdate(tear)
    -- Only run code when tear is older than 0 frames
    if tear.FrameCount <= 0 then return end
    -- Make sure the tear has a parent
    if not tear.Parent then return end
    -- The player the tear belongs to
    local player = tear.Parent:ToPlayer()
    -- Make sure the player exists and the player has the trinket
    if not (player and player:GetTrinketMultiplier(TW.ID) > 0) then return end
    -- Get custom data for the tear
    local data = tear:GetData()
    -- Check if this tear is an following tear
    if data.q_tw_followTear ~= nil then
        -- The tear entity this tear is following
        ---@type EntityTear
        local followTear = data.q_tw_followTear.Entity:ToTear()
        -- Check if the follow tear has fallen
        if not followTear:IsDead() then
            -- Copy the follow tear's height variables
            tear.FallingAcceleration = followTear.FallingAcceleration
            tear.FallingSpeed = followTear.FallingSpeed
            tear.Height = followTear.Height
            -- Only run this on frame 1
            if tear.FrameCount == 1 then
                -- Set the position of the tear to the correct inital position
                tear.Position = followTear.Position - followTear.Velocity:Normalized() * (TW.FOLLOW_DISTANCE * followTear.Scale) * data.q_tw_followOffset
            end
            -- Set the velocity to follow around the tear
            tear.Velocity = followTear.Velocity
        end
        -- Lerp the scale tTWards the beginning of the tears life
        --tear.Scale = utils.Lerp(0, data.q_tw_targetScale, (tear.FrameCount - (data.q_tw_followOffset - 1) * 5) / TW.GROW_FRAME_MAX)
    -- Check whether this tear can spawn additional following tears
    elseif not data.q_tw_hasSpawnedfollowTear and tear.FrameCount <= TW.FRAME_CUTOFF then
        -- Set that this tear has spawned other tears
        data.q_tw_hasSpawnedfollowTear = true
        -- The trinket multiplier for the player
        local mult = player:GetTrinketMultiplier(TW.ID)
        -- Spawn a tear for each level of multiplier the player has
        for i = 0, mult - 1, 1 do
            -- Fire a tear
            local spawned_tear = player:FireTear(tear.Position, Vector.Zero, false, true, false, tear, TW.DAMAGE_MULTIPLIER)
            -- Change the tears variant to the correct version
            spawned_tear:ChangeVariant(tear.Variant)
            -- Remove flags that break the item
            spawned_tear:ClearTearFlags(TW.REMOVE_FLAGS)
            -- Set the inital scale
            spawned_tear.Scale = TW.SCALE_MULTIPLIER / (i + 1) * tear.Scale
            -- Stop the tear from falling
            spawned_tear.FallingAcceleration = 0
            spawned_tear.FallingSpeed = 0
            -- Stop the tear from homing as much
            spawned_tear.HomingFriction = 1
            -- The data for the spawned tear
            local spawned_data = spawned_tear:GetData()
            -- Set the tear entity the spawned tear should follow
            spawned_data.q_tw_followTear = EntityRef(tear)
            -- Set the offset for the spawned tear, with an additional offset based on the amount of tears already spawned
            spawned_data.q_tw_followOffset = i + 1
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, TW.OnTearUpdate)

if EID then
    EID:addTrinket(
        TW.ID,
        "#{{Collectible233}} An additional tear follows every tear fired#{{Damage}} Additional tears deal 0.25x damage"
    )
    EID:addGoldenTrinketTable(TW.ID, {findReplace = true})
    local t = { [TW.ID] = { "An additional tear follows", "Two additional tears follow", "Three additional tears follow" } }
    EID:updateDescriptionsViaTable(t, EID.descriptions["en_us"].goldenTrinketEffects)
end