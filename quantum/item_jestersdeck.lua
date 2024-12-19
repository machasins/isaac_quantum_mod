Quantum.JestersDeck = {}
local JD = Quantum.JestersDeck
local game = Game()

---@type UTILS
local UTILS = Quantum.UTILS
---@type QUEUE
local QUEUE = Quantum.QUEUE

-- ID of the item
JD.ID = Isaac.GetItemIdByName("Jester's Deck")
JD.CARD = Isaac.GetCardIdByName("Jester")

JD.CARD_MIMIC_POOL = {
    { 10, Card.CARD_FOOL },
    { 10, Card.CARD_MAGICIAN },
    { 10, Card.CARD_HIGH_PRIESTESS },
    { 10, Card.CARD_EMPRESS },
    { 10, Card.CARD_EMPEROR },
    { 10, Card.CARD_HIEROPHANT },
    { 10, Card.CARD_LOVERS },
    { 10, Card.CARD_CHARIOT },
    { 10, Card.CARD_JUSTICE },
    { 10, Card.CARD_HERMIT },
    { 10, Card.CARD_WHEEL_OF_FORTUNE },
    { 10, Card.CARD_STRENGTH },
    { 10, Card.CARD_HANGED_MAN },
    { 10, Card.CARD_DEATH },
    { 10, Card.CARD_TEMPERANCE },
    { 10, Card.CARD_DEVIL },
    { 10, Card.CARD_TOWER },
    { 10, Card.CARD_STARS },
    { 10, Card.CARD_MOON },
    { 10, Card.CARD_SUN },
    { 10, Card.CARD_JUDGEMENT },
    { 10, Card.CARD_WORLD },
    {  5, Card.CARD_CLUBS_2 },
    {  2, Card.CARD_DIAMONDS_2 },
    {  5, Card.CARD_SPADES_2 },
    { 10, Card.CARD_HEARTS_2 },
    {  1, Card.CARD_ACE_OF_CLUBS },
    {  1, Card.CARD_ACE_OF_DIAMONDS },
    {  1, Card.CARD_ACE_OF_SPADES },
    {  1, Card.CARD_ACE_OF_HEARTS },
    {  3, Card.CARD_JOKER },
    {  2, Card.CARD_CHAOS },
    {  1, Card.CARD_CREDIT },
    {  2, Card.CARD_HUMANITY },
    {  1, Card.CARD_SUICIDE_KING },
    { 10, Card.CARD_GET_OUT_OF_JAIL },
    {  2, Card.CARD_QUESTIONMARK },
    {  2, Card.CARD_HOLY },
    {  1, Card.CARD_HUGE_GROWTH },
    {  2, Card.CARD_ANCIENT_RECALL },
    {  1, Card.CARD_ERA_WALK },
    {  8, Card.CARD_REVERSE_FOOL },
    {  8, Card.CARD_REVERSE_MAGICIAN },
    {  8, Card.CARD_REVERSE_HIGH_PRIESTESS },
    {  8, Card.CARD_REVERSE_EMPRESS },
    {  8, Card.CARD_REVERSE_EMPEROR },
    {  8, Card.CARD_REVERSE_HIEROPHANT },
    {  8, Card.CARD_REVERSE_LOVERS },
    {  8, Card.CARD_REVERSE_CHARIOT },
    {  8, Card.CARD_REVERSE_JUSTICE },
    {  8, Card.CARD_REVERSE_HERMIT },
    {  8, Card.CARD_REVERSE_WHEEL_OF_FORTUNE },
    {  8, Card.CARD_REVERSE_STRENGTH },
    {  8, Card.CARD_REVERSE_HANGED_MAN },
    {  8, Card.CARD_REVERSE_DEATH },
    {  8, Card.CARD_REVERSE_TEMPERANCE },
    {  8, Card.CARD_REVERSE_DEVIL },
    {  8, Card.CARD_REVERSE_TOWER },
    {  8, Card.CARD_REVERSE_STARS },
    {  8, Card.CARD_REVERSE_MOON },
    {  8, Card.CARD_REVERSE_SUN },
    {  8, Card.CARD_REVERSE_JUDGEMENT },
    {  8, Card.CARD_REVERSE_WORLD },
    {  2, Card.CARD_QUEEN_OF_HEARTS },
    {  1, Card.CARD_WILD },
}

JD.CARD_SOUND = Isaac.GetSoundIdByName("card_jester")
JD.ROOM_PAYOUT = 5

local sfx = SFXManager()

---Get the size of the trinket pool
---@param pool table
---@return integer
local function getPoolSize(pool)
    local poolsize = 0
    for _, v in pairs(pool) do
        poolsize = poolsize + v[1]
    end
    return poolsize
end

---Get a weighted random index for a pool
---@param pool table
---@param poolsize integer
---@return integer
local function weightedRandom(pool, poolsize)
    local selection = math.random(1, poolsize)
    for k, v in pairs(pool) do
        selection = selection - v[1]
        if (selection <= 0) then
            return v[2]
        end
    end
    return 1
end

---Get the pool of trinkets that should be used
---@return table
function JD:RemoveLockedCards()
    local cardList = {}
    for _, t in pairs(JD.CARD_MIMIC_POOL) do
        if Isaac.GetItemConfig():GetCard(t[2]):IsAvailable() then
            table.insert(cardList, t)
        end
    end
    return cardList
end

---When a Jester card is used
---@param id Card
---@param player EntityPlayer
---@param flags integer
function JD:OnCardUse(id, player, flags)
    -- Reduce the available card pool
    local cardPool = JD:RemoveLockedCards()
    -- Get a random card
    local randomCard = weightedRandom(cardPool, getPoolSize(cardPool))
    -- Play the jester sound effect
    sfx:Play(JD.CARD_SOUND, 4, 0, false)
    -- Queue using the actual card
    QUEUE:AddItem(30, 0, function (time)
        player:UseCard(randomCard, UseFlag.USE_NOANIM)
        -- Don't actually kill the player for using Suicide King
        if randomCard == Card.CARD_SUICIDE_KING then
            player:UseCard(Card.CARD_SOUL_LAZARUS, UseFlag.USE_NOANIM)
            sfx:Play(SoundEffect.SOUND_SOUL_OF_LAZARUS, 0, 60)
        end
        -- Don't kill the player if they run out of hearts using R. Lovers
        if randomCard == Card.CARD_REVERSE_LOVERS and player:GetHearts() + player:GetSoulHearts() <= 0 then
            if player:GetBrokenHearts() >= player:GetHeartLimit() then
                player:AddBrokenHearts(-1)
            end
            player:AddMaxHearts(1, false)
            player:AddHearts(1)
        end
        -- Don't kill the player if they use R. Devil in the Satan fight
        if randomCard == Card.CARD_REVERSE_DEVIL and game:GetRoom():GetType() == RoomType.ROOM_BOSS and #Isaac.FindByType(EntityType.ENTITY_SATAN) > 0 then
            player:UseCard(Card.CARD_SOUL_LAZARUS, UseFlag.USE_NOANIM)
            sfx:Play(SoundEffect.SOUND_SOUL_OF_LAZARUS, 0, 60)
        end
    end, QUEUE.UpdateType.Update)
end

Quantum:AddCallback(ModCallbacks.MC_USE_CARD, JD.OnCardUse, JD.CARD)

---Make all cards Jesters when the item is held
---@param rng RNG
---@param card Card
---@param playing boolean
---@param runes boolean
---@param onlyrunes boolean
---@return Card
function JD:OnCardSpawn(rng, card, playing, runes, onlyrunes)
    if UTILS.AnyPlayerHasCollectible(JD.ID) then
        return JD.CARD
    end
    return card
end

Quantum:AddCallback(ModCallbacks.MC_GET_CARD, JD.OnCardSpawn)

---Spawn a card every 5 rooms cleared
---@param rng RNG
---@param pos Vector
function JD:OnRoomClear(rng, pos)
    UTILS.ForEveryPlayerHasCollectible(JD.ID, function(player)
        local save = Quantum.save.GetRunSave(player)
        if save then
            save.JD_RoomClears = save.JD_RoomClears or 0
            save.JD_RoomClears = save.JD_RoomClears + 1
            if save.JD_RoomClears >= JD.ROOM_PAYOUT then
                save.JD_RoomClears = 0
                local cardPosition = game:GetRoom():FindFreePickupSpawnPosition(player.Position)
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, JD.CARD, cardPosition, Vector.Zero, player)
            end
        end
    end)
end

Quantum:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, JD.OnRoomClear)

if EID then
    EID:addCollectible(
        JD.ID,
        "{{Card}} Spawns a card every " .. JD.ROOM_PAYOUT .. " rooms" ..
        "{{Card" .. Card.CARD_JOKER .. "}} All cards become Jesters, which play a random card on use" ..
        "#{{Warning}} The Jester card will protect Isaac from {{Card" .. Card.CARD_SUICIDE_KING .. "}} instant death card effects when used"
    )

    EID:addCard(
        JD.CARD,
        "{{DiceRoom}} Plays a random card effect on use" ..
        "#{{Warning}} Protects Isaac from {{Card" .. Card.CARD_SUICIDE_KING .. "}} instant death card effects when used"
    )
end

