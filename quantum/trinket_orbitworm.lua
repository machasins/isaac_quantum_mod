Quantum.OrbitWorm = {}
local OW = Quantum.OrbitWorm
local game = Game()

---@class UTILS
local UTILS = Quantum.UTILS

local GetData = UTILS.FuncGetData("q_ow")

-- ID of the item
OW.ID = Isaac.GetTrinketIdByName("Orbit Worm")

OW.FRAME_CUTOFF = 5
OW.DAMAGE_MULTIPLIER = 0.5
OW.SCALE_MULTIPLIER = 0.5
OW.ORBIT_SPEED_RANGE = { MIN = 1, MAX = 4 }
OW.ORBIT_DISTANCE = 30.0
OW.GROW_FRAME_MAX = 10.0
OW.REMOVE_FLAGS = TearFlags.TEAR_ORBIT

---When the item is used
---@param tear EntityTear
function OW:OnTearUpdate(tear)
    -- Only run code when tear is older than 0 frames
    if tear.FrameCount <= 0 then return end
    -- Make sure the tear has a parent
    if not tear.Parent then return end
    -- The player the tear belongs to
    local player = tear.Parent:ToPlayer()
    -- Make sure the player exists and the player has the trinket
    if not (player and player:GetTrinketMultiplier(OW.ID) > 0) then return end
    -- Get custom data for the tear
    local data = GetData(tear)
    -- Check if this tear is an orbiting tear
    if data.orbitTear ~= nil then
        -- The tear entity this tear is orbiting
        ---@type EntityTear
        local orbitTear = data.orbitTear.Entity:ToTear()
        -- Check if the orbit tear has fallen
        if not orbitTear:IsDead() then
            -- Copy the orbit tear's height variables
            tear.FallingAcceleration = orbitTear.FallingAcceleration
            tear.FallingSpeed = orbitTear.FallingSpeed
            tear.Height = orbitTear.Height
            -- The term going into sin / cos
            local spin = (tear.FrameCount / 30.0) * data.orbitSpeed * 2.0 * math.pi + data.orbitOffset
            -- The derivative of the term inside of sin / cos
            local dspin = data.orbitSpeed * 2.0 * math.pi
            -- Only run this on frame 1
            if tear.FrameCount == 1 then
                -- Set the position of the tear to the correct inital position
                tear.Position = orbitTear.Position + Vector(OW.ORBIT_DISTANCE * math.sin(spin), OW.ORBIT_DISTANCE * math.cos(spin))
            end
            -- Set the velocity to orbit around the tear
            tear.Velocity = orbitTear.Velocity + Vector(OW.ORBIT_DISTANCE * dspin * math.cos(spin), -OW.ORBIT_DISTANCE * dspin * math.sin(spin)) / 30.0
        else
            -- Set the velocity to go straight from where it was, and set speed according to shot speed
            tear.Velocity = tear.Velocity:Normalized() * player.ShotSpeed * 10
        end
        -- Lerp the scale towards the beginning of the tears life
        tear.Scale = UTILS.Lerp(0, data.targetScale, tear.FrameCount / OW.GROW_FRAME_MAX)
    -- Check whether this tear can spawn additional orbiting tears
    elseif not data.hasSpawnedOrbitTear and tear.FrameCount <= OW.FRAME_CUTOFF then
        -- Set that this tear has spawned other tears
        data.hasSpawnedOrbitTear = true
        -- The trinket multiplier for the player
        local mult = player:GetTrinketMultiplier(OW.ID)
        -- How fast the tear should orbit this tear, based on shot speed with a random direction
        local rand_speed = math.max(math.min(player.ShotSpeed / 3.0, OW.ORBIT_SPEED_RANGE.MAX), OW.ORBIT_SPEED_RANGE.MIN) * (math.random(0,1) * 2 - 1)
        -- A random radian offset, where the orbiting tears should start off
        local rand_offset = math.random() * 2.0 * math.pi
        -- Spawn a tear for each level of multiplier the player has
        for i = 0, mult - 1, 1 do
            -- Fire a tear
            local spawned_tear = player:FireTear(tear.Position, Vector.Zero, false, true, false, tear, OW.DAMAGE_MULTIPLIER)
            -- Change the tears variant to the correct version
            spawned_tear:ChangeVariant(tear.Variant)
            -- Remove flags that break the item
            spawned_tear:ClearTearFlags(OW.REMOVE_FLAGS)
            -- Set the inital scale to invisible
            spawned_tear.Scale = 0
            -- Stop the tear from falling
            spawned_tear.FallingAcceleration = 0
            spawned_tear.FallingSpeed = 0
            -- Stop the tear from homing as much
            spawned_tear.HomingFriction = 1
            -- The data for the spawned tear
            local spawned_data = GetData(spawned_tear)
            -- Set the tear entity the spawned tear should orbit
            spawned_data.orbitTear = EntityRef(tear)
            -- Set the speed of the orbiting tear
            spawned_data.orbitSpeed = rand_speed
            -- Set the random offset for the spawned tear, with an additional offset based on the amount of tears already spawned
            spawned_data.orbitOffset = rand_offset + i * (2.0 * math.pi) / mult
            -- Set the target scale for the spawned tear
            spawned_data.targetScale = OW.SCALE_MULTIPLIER * tear.Scale
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, OW.OnTearUpdate)

if EID then
    EID:addTrinket(
        OW.ID,
        "#{{Collectible233}} An additional tear orbits around every tear fired#{{Damage}} Additional tears deal 0.5x damage"
    )
    EID:addGoldenTrinketTable(OW.ID, {findReplace = true})
    local t = { [OW.ID] = { "An additional tear orbits", "Two additional tears orbit", "Three additional tears orbit" } }
    EID:updateDescriptionsViaTable(t, EID.descriptions["en_us"].goldenTrinketEffects)
end