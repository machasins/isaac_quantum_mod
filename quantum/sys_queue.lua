---@class QUEUE
local Queue = {}
---@type table<number, fun(time:number?), number>[]
Queue.queue = {}
---@type ModReference
Queue.Mod = RegisterMod("Queue", 1)

-- The index into a queue item for the start time
local Q_START = 1
-- The index into a queue item for the function to run
local Q_FUNC = 2
-- The index into a queue item for the ending time
local Q_END = 3

---Add an item to the queue
---@param time number The time to call the function (in frames)
---@param func fun(time:number?) The function to call
---@param duration number? How many frames to call the function
function Queue:AddItem(time, func, duration)
    -- Initialize the duration
    duration = duration or 0
    -- The current frame count
    local currentFrame = Isaac.GetFrameCount()
    -- The time the event should start
    local startTime = currentFrame + time
    -- The time the event should end
    local endTime = currentFrame + time + duration

    -- Insert the event into the queue
    table.insert(Queue.queue, { startTime, func, endTime })
end

---Updating the queue, run every update frame
function Queue:OnUpdate()
    -- Get the current frame count
    local frameCount = Isaac.GetFrameCount()
    -- Loop through all items in the queue
    for i, q in pairs(Queue.queue) do
        -- Check if the queue item exists
        if q ~= nil then
            -- Check if it is time for the queue item to start
            if frameCount >= q[Q_START] then
                -- Run the queue item's function, with how much time has passed as input
                q[Q_FUNC](frameCount - q[Q_START])
                -- Check if it is time for the queue item to end
                if frameCount >= q[Q_END] then
                    -- Delete the item from the queue
                    Queue.queue[i] = nil
                end
            end
        end
    end
end

Queue.Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, Queue.OnUpdate)

return Queue