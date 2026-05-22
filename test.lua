
local RenderManager = {}

local pools = {}
local activeDrawings = {}
local pendingFrame = {}
local isRendering = false

local function getFromPool(shapeType)
    if not pools[shapeType] then
        pools[shapeType] = {}
    end
    local pool = pools[shapeType]
    if #pool > 0 then
        return table.remove(pool)
    end
    return Drawing.new(shapeType)
end

local function returnToPool(shapeType, obj)
    obj.Visible = false
    if not pools[shapeType] then
        pools[shapeType] = {}
    end
    table.insert(pools[shapeType], obj)
end

function RenderManager.push(key, drawData)
    pendingFrame[key] = drawData
end

function RenderManager.flush()
    if isRendering then return end
    isRendering = true

    local visited = {}

    for key, data in next, pendingFrame do
        visited[key] = true
        local existing = activeDrawings[key]

        if not existing or existing.__type ~= data.type then
            if existing then
                returnToPool(existing.__type, existing.obj)
            end
            local obj = getFromPool(data.type)
            existing = { __type = data.type, obj = obj }
            activeDrawings[key] = existing
        end

        local obj = existing.obj
        local props = data.props
        for prop, value in next, props do
            obj[prop] = value
        end
        obj.Visible = props.Visible ~= false -- default visible unless explicitly false
    end

    for key, existing in next, activeDrawings do
        if not visited[key] then
            returnToPool(existing.__type, existing.obj)
            activeDrawings[key] = nil
        end
    end

    for k in next, pendingFrame do
        pendingFrame[k] = nil
    end

    isRendering = false
end

function RenderManager.remove(key)
    local existing = activeDrawings[key]
    if existing then
        returnToPool(existing.__type, existing.obj)
        activeDrawings[key] = nil
    end
    pendingFrame[key] = nil
end

function RenderManager.destroy()
    for key, existing in next, activeDrawings do
        existing.obj:Remove()
        activeDrawings[key] = nil
    end
    for shapeType, pool in next, pools do
        for _, obj in ipairs(pool) do
            obj:Remove()
        end
        pools[shapeType] = nil
    end
    for k in next, pendingFrame do
        pendingFrame[k] = nil
    end
end

return RenderManager
