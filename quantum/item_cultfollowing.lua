Quantum.QC = {}
local game = Game()

---@type UTILS
local UTILS = include("quantum.utils")

local QC_ID = Isaac.GetItemIdByName("Cult Following")
Quantum.QC.ID = QC_ID

local CULTIST_SUBTYPE = 90210
local CULTIST_COLOR = Color(1,0,1,1)
local CULTIST_SCALE = 0.5
local CULTIST_SPEED_MULT = 0.8

local CULTIST_MAX_REVIVE_ROOM = 1
local CULTIST_MAX_CHARMED_TOTAL = 10
local CULTIST_ADD_CHARMED = 10

---comment
---@param cultist Entity
local function SetCultistFlags(cultist)
    cultist:ClearEntityFlags(EntityFlag.FLAG_CHARM | EntityFlag.FLAG_APPEAR)
    cultist:AddEntityFlags(EntityFlag.FLAG_HIDE_HP_BAR)
    cultist.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    cultist.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_WALLS
    cultist:GetSprite().Color = CULTIST_COLOR
    cultist:MultiplyFriction(100)

    cultist:ToNPC().Scale = CULTIST_SCALE

    cultist:ToNPC().I2 = CULTIST_MAX_REVIVE_ROOM
end

local function SpawnCultist(player)
    local position = game:GetLevel():GetCurrentRoom():FindFreePickupSpawnPosition(player.Position, 0, true)
    local cultist = Isaac.Spawn(EntityType.ENTITY_CULTIST, 0, CULTIST_SUBTYPE, position, Vector(0,0), player)
    cultist:AddCharmed(EntityRef(player), -1)
    SetCultistFlags(cultist)
end

local function GetCharmedEnemyCount()
    local entities = Isaac.GetRoomEntities()
    local charmedCount = 0
    for _, e in pairs(entities) do
        charmedCount = charmedCount + (e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and 1 or 0)
    end
    return charmedCount
end

function Quantum.QC:OnPlayerUpdate(player)
    local save = Quantum.save.GetRunSave()
    if save then
        save.spawnedNecro = save.spawnedNecro or false
        if player:HasCollectible(QC_ID) and (not save.spawnedNecro or Isaac.CountEntities(player, EntityType.ENTITY_CULTIST, 0, CULTIST_SUBTYPE) <= 0) then
            SpawnCultist(player)
            save.spawnedNecro = true
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, Quantum.QC.OnPlayerUpdate)

---comment
---@param entity EntityNPC
function Quantum.QC:OnNPCUpdate(entity)
    if entity.Type == EntityType.ENTITY_CULTIST and entity.SubType == CULTIST_SUBTYPE then
        local save = Quantum.save.GetRunSave()
        if save then
            save.charmedEnemies = save.charmedEnemies or 0
            if entity:GetSprite():IsEventTriggered("Shoot") then
                local charmedCount = GetCharmedEnemyCount()
                entity.I2 = entity.I2 + 1
                save.charmedEnemies = charmedCount
            elseif entity:IsFrame(30, 1) then
                local charmedCount = GetCharmedEnemyCount()
                save.charmedEnemies = math.min(charmedCount, save.charmedEnemies)
            end

            local collectibleNum = UTILS.GetPlayerCollectibleNum(QC_ID) - 1
            if save.charmedEnemies >= CULTIST_MAX_CHARMED_TOTAL + CULTIST_ADD_CHARMED * collectibleNum or entity.I2 >= CULTIST_MAX_REVIVE_ROOM then
                entity.I1 = 0
            end
        end
        entity.Velocity = entity.Velocity * CULTIST_SPEED_MULT
    end
end

Quantum:AddCallback(ModCallbacks.MC_NPC_UPDATE, Quantum.QC.OnNPCUpdate)

function Quantum.QC:OnNewRoom()
    local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CULTIST_SUBTYPE)
    for _, e in pairs(entities) do
        e:ToNPC().I2 = 0
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Quantum.QC.OnNewRoom)

function Quantum.QC:OnContinue(isCont)
    if isCont then
        local entities = Isaac.FindByType(EntityType.ENTITY_CULTIST, 0, CULTIST_SUBTYPE)
        for _, e in pairs(entities) do
            SetCultistFlags(e)
        end
    end
end

Quantum:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Quantum.QC.OnContinue)

if EID then
    EID:addCollectible(
        QC_ID,
        "Spawns a cultist familiar that can revive enemies to fight for you" ..
        "#Stops reviving enemies when a cap is reached"
    )

    if EIDD then
        EIDD:addDuplicateCollectible(QC_ID, "The cultist's revive cap is increased")
    end
end