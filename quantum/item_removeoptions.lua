Quantum.QS = {}
local game = Game()

local QS_ID = Isaac.GetItemIdByName("Quantum Scissors")
local QUEUE = include("quantum.sys_queue")
---@type UTILS
local UTILS = include("quantum.utils")

local REMOVE_CHANCE = 0.1
local ADDITIONAL_CHANCE = 0.1
local LUCK_MULT = 0.02
local MIN_CHANCE = 0.05
local MAX_CHANCE = 0.5

local EFFECT_SPAWN_DELAY = 30

local VISIBLE_OPTIONS_EFFECT = 695

local checkedPickups = {}

local function ForEachPlayer(func)
    local num = game:GetNumPlayers()
    for i = 0, num - 1 do
        func(i, game:GetPlayer(i))
    end
end

local function RemoveAdditionalEffect(effect_type, match)
    local choices = Isaac.FindByType(EntityType.ENTITY_EFFECT, effect_type)
    for _, e in pairs(choices) do
        if e.Parent.Index == match then
            e:Remove()
        end
    end
end

---comment
---@param pickup EntityPickup
function Quantum.QS:RemoveOptions(pickup)
    if checkedPickups[pickup.Index] == nil then
        if pickup.OptionsPickupIndex ~= 0 then
            -- Chance to remove Options
            local numItem = 0
            local highestPlayerLuck = 0
            ForEachPlayer(function(_, e)
                if e:HasCollectible(QS_ID) then
                    numItem = numItem + e:GetCollectibleNum(QS_ID)
                    highestPlayerLuck = highestPlayerLuck < e.Luck and e.Luck or highestPlayerLuck
                end
            end)
            if numItem > 0 then
                local rng = Isaac.GetPlayer():GetCollectibleRNG(QS_ID)
                local chance = UTILS.GetLuckChance(highestPlayerLuck, REMOVE_CHANCE + ADDITIONAL_CHANCE * (numItem - 1), LUCK_MULT, MIN_CHANCE, MAX_CHANCE)
                if rng:RandomFloat() <= chance then
                    pickup.OptionsPickupIndex = 0
                    QUEUE:AddItem(EFFECT_SPAWN_DELAY, function()
                        local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF02, 0, pickup.Position, Vector(0,0), nil) 
                        effect:GetSprite().Color:SetOffset(0,1,1)
                        effect:GetSprite().Color.A = 0.5
                    end)
                    -- Addition for Choice Viewer
                    RemoveAdditionalEffect(VISIBLE_OPTIONS_EFFECT, pickup.Index)
                end
            end
        end
        checkedPickups[pickup.Index] = true
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, Quantum.QS.RemoveOptions)

if EID then
    EID:addCollectible(
        QS_ID,
        "Gives a luck affected 10% chance to decouple a pickup from other linked pickups" ..
        "#This includes Alt Path treasure rooms, all Options items, Angel rooms, Boss Rush, etc." ..
        "#50% chance to decouple at 20 Luck"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(QS_ID, "Gives an additional 10% chance")
    end
end