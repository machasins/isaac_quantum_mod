
local Queue = {}
Queue.queue = {}
Queue.Mod = RegisterMod("Queue", 1)

---@enum TimeRelation
Queue.TimeRelation = {
    ABSOLUTE = 0,
    RELATIVE = 1
}

local Q_TIME = 1
local Q_FUNC = 2

---comment
---@param time number 
---@param func function
---@param mode TimeRelation?
function Queue:AddItem(time, func, mode)
    mode = mode or Queue.TimeRelation.RELATIVE

    if mode == Queue.TimeRelation.RELATIVE then
        time = time + Isaac.GetFrameCount()
    end

    table.insert(Queue.queue, { time, func })
end

function Queue:OnUpdate()
    for i, q in pairs(Queue.queue) do
        if q ~= nil then
            if Isaac.GetFrameCount() >= q[Q_TIME] then
                q[Q_FUNC]()
                Queue.queue[i] = nil
            end
        end
    end
end

Queue.Mod:AddCallback(ModCallbacks.MC_POST_UPDATE, Queue.OnUpdate)

return Queue