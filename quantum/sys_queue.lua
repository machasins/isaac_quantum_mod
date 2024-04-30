---@class QUEUE
local Queue = {}
---@type table<number, fun(time:number?), number>[]
Queue.queue = {}
---@type ModReference
Queue.Mod = RegisterMod("Queue", 1)

local Q_START = 1
local Q_FUNC = 2
local Q_END = 3

---Add an item to the queue
---@param time number The time to call the function (in frames)
---@param func fun(time:number?) The function to call
---@param duration number? How many frames to call the function
function Queue:AddItem(time, func, duration)
    duration = duration or 0
    local currentFrame = Isaac.GetFrameCount()
    local startTime = currentFrame + time
    local endTime = currentFrame + time + duration

    table.insert(Queue.queue, { startTime, func, endTime })
end

---Updating the queue
function Queue:OnUpdate()
    local frameCount = Isaac.GetFrameCount()
    for i, q in pairs(Queue.queue) do
        if q ~= nil then
            if frameCount >= q[Q_START] then
                q[Q_FUNC](frameCount - q[Q_START])
                if frameCount >= q[Q_END] then
                    Queue.queue[i] = nil
                end
            end
        end
    end
end

Queue.Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, Queue.OnUpdate)

return Queue