---@class Level
---@field config LevelConfig
---@field mirrors (MirrorDirection|false)[]
---@field matches boolean[] item matches, same ordering as config's items

---@alias MirrorDirection "up-right"|"down-right"



local M = {}

---@param config LevelConfig
---@return Level
function M.create_level(config)
    local mirrors = {}
    for i = 1, config.width * config.height do
        mirrors[i] = false
    end
    local matches = {}
    for i = 1, #config.items do
        matches[i] = false
    end
    ---@type Level
    local level = { 
        config = config, 
        mirrors = mirrors,
        matches = matches
    }
    return level
end

---@param level Level
---@param x integer
---@param y integer
---@return boolean
local function coordinate_in_bounds(level, x, y)
    return x >= 1 and x <= level.config.width and y >= 1 and y <= level.config.height
end

---@param level Level
---@param x integer
---@param y integer
---@return integer
local function coordinate_to_index(level, x, y)
    assert(coordinate_in_bounds(level, x, y))
    return x + (y - 1) * level.config.width
end

---@param level Level
---@param x integer
---@param y integer
---@return MirrorDirection?
function M.get_mirror(level, x, y)
    local ret = level.mirrors[coordinate_to_index(level, x, y)]
    return ret or nil
end

---@param level Level
---@param x integer
---@param y integer
---@return integer?
function M.get_mirror_index(level, x, y) 
    -- number of items must be equal to `(width + height) * 2`, 
    -- in the order `top -> right -> bottom -> left`, 
    -- horizontal left to right, vertical bototm to top
    local w = level.config.width
    local h = level.config.height
    local x_in_bounds = x >= 1 and x <= w
    local y_in_bounds = y >= 1 and y <= h
    -- top
    if y == h + 1 and x_in_bounds then
        return x
    end
    -- bottom
    if y == 0 and x_in_bounds then
        return w + h + x
    end
    -- right
    if x == w + 1 and y_in_bounds then
        return w + y
    end
    -- left
    if x == 0 and y_in_bounds then
        return w + w + h + y
    end
end

---@param level Level
---@param x integer
---@param y integer
---@return MirrorDirection | nil | string
local function get_mirror_or_item(level, x, y)
    local mi = M.get_mirror_index(level, x, y)
    return mi and level.config.items[mi] or M.get_mirror(level, x, y)
end

---@param level Level
---@param dot_x integer
---@param dot_y integer
---@return boolean
local function dot_in_bounds(level, dot_x, dot_y)
    return dot_x >= 0 and dot_x <= level.config.width and dot_y >= 0 and dot_y <= level.config.height
end

---@class AvailableTurn
---@field dot_x integer
---@field dot_y integer
---@field x integer
---@field y integer
---@field direction MirrorDirection

---@param level Level
---@param dot_x integer
---@param dot_y integer
---@return AvailableTurn[]
function M.get_available_dots(level, dot_x, dot_y)
    if not dot_in_bounds(level, dot_x, dot_y) then
        return {}
    end

    local ret = {} ---@type AvailableTurn[]
    local right = dot_x + 1
    local up = dot_y + 1
    -- up right
    if dot_x < level.config.width and dot_y < level.config.height and not M.get_mirror(level, right, up) then
        ret[#ret+1] = {dot_x = right, dot_y = up, x = right, y = up, direction = "up-right"}
    end
    -- down right
    local down = dot_y - 1
    if dot_x < level.config.width and dot_y > 0 and not M.get_mirror(level, right, dot_y) then
        ret[#ret+1] = {dot_x = right, dot_y = down, x = right, y = dot_y, direction = "down-right"}
    end
    -- down left
    local left = dot_x - 1
    if dot_x > 0 and dot_y > 0 and not M.get_mirror(level, dot_x, dot_y) then
        ret[#ret+1] = {dot_x = left, dot_y = down, x = dot_x, y = dot_y, direction = "up-right"}
    end
    -- up left
    if dot_x > 0 and dot_y < level.config.height and not M.get_mirror(level, dot_x, up) then
        ret[#ret+1] = {dot_x = left, dot_y = up, x = dot_x, y = up, direction = "down-right"}
    end
    return ret
end

---@alias RayDirection "up" | "down" | "left" | "right"
---@alias RayShape "horizontal" | "vertical" | "up-left" | "up-right" | "down-left" | "down-right"

---@class RayStep
---@field x integer
---@field y integer
---@field item string?
---@field shape RayShape

---@param x integer
---@param y integer
---@param direction RayDirection
---@return string
local function cast_ray_next_todo(x, y, direction) 
    local template = "%d/%d/%s"
    if direction == "up" then
        return template:format(x, y + 1, direction)
    elseif direction == "down" then
        return template:format(x, y - 1, direction)
    elseif direction == "left" then
        return template:format(x - 1, y, direction)
    else
        return template:format(x + 1, y, direction)
    end
end

---@param old RayDirection
---@param new RayDirection
---@return RayShape
local function cast_ray_reflection_shape(old, new)
    -- invert old because old is "enter", but ray shape is "2 exits"
    if old == "up" then 
        old = "down"
    elseif old == "down" then
        old = "up"
    elseif old == "left" then
        old = "right"
    else
        old = "left"
    end
    if new == "up" or new == "down" then
        return ("%s-%s"):format(new, old)
    else
        return ("%s-%s"):format(old, new)
    end
end

---@param s any
---@return boolean
local function is_mirror(s) 
    return s == "down-right" or s == "up-right" 
end

---@param ray_direction RayDirection
---@param mirror_direction MirrorDirection
---@return RayDirection
local function reflect(ray_direction, mirror_direction)
    assert(is_mirror(mirror_direction))
    if mirror_direction == "down-right" then
        if ray_direction == "up" then return "left"
        elseif ray_direction == "down" then return "right"
        elseif ray_direction == "left" then return "up"
        else return "down" end
    else
        if ray_direction == "up" then return "right"
        elseif ray_direction == "down" then return "left"
        elseif ray_direction == "left" then return "down"
        else return "up" end
    end
end 

---@param level Level
---@param x integer
---@param y integer
---@param direction RayDirection
---@return RayStep[]
local function cast_ray(level, x, y, direction)
    local visited = {}
    local fmt = "%d/%d/%s"
    local parse = "^(%d+)/(%d+)/(.+)"
    local todo = string.format(fmt, x, y, direction) ---@type string?
    local steps = {} ---@type RayStep[]
    while todo do
        if visited[todo] then 
            break 
        end
        visited[todo] = true

        local sx, sy, sdir = string.match(todo, parse)
        local tx = assert(tonumber(sx)) ---@type integer
        local ty = assert(tonumber(sy)) ---@type integer 
        local dir = sdir ---@type RayDirection
        local mirror_or_item = get_mirror_or_item(level, tx, ty)
        if is_mirror(mirror_or_item) then
            local next_dir = reflect(dir, mirror_or_item --[[@as MirrorDirection]])
            steps[#steps+1] = {x = tx, y = ty, shape = cast_ray_reflection_shape(dir, next_dir)}
            todo = cast_ray_next_todo(tx, ty, next_dir)
        elseif not mirror_or_item then
            -- empty space, continue ray
            steps[#steps+1] = {x = tx, y = ty, shape = (dir == "up" or dir == "down") and "vertical" or "horizontal"}
            todo = cast_ray_next_todo(tx, ty, dir)
        else
            -- found an item, finishing
            steps[#steps+1] = {x = tx, y = ty, item = mirror_or_item, shape = (dir == "up" or dir == "down") and "vertical" or "horizontal"}
            todo = nil
        end
    end
    return steps
end

---@param level Level
---@param x integer
---@param y integer
---@param direction MirrorDirection
---@return RayStep[][]
function M.place_mirror(level, x, y, direction)
    local index = coordinate_to_index(level, x, y)
    assert(not level.mirrors[index])
    level.mirrors[index] = direction

    local left = cast_ray(level, x, y, "left")
    local right = cast_ray(level, x, y, "right")
    local up = cast_ray(level, x, y, "up")
    local down = cast_ray(level, x, y, "down")

    local ray_pairs
    if direction == "up-right" then
        ray_pairs = {{down, right}, {up, left}}
    else
        ray_pairs = {{up, right}, {down, left}}
    end

    local ret = {} ---@type RayStep[][]
    for i = 1, #ray_pairs do
        local a = ray_pairs[i][1] --- @type RayStep[]
        local b = ray_pairs[i][2] --- @type RayStep[]
        local ais = a[#a]
        local bis = b[#b]
        

        if ais.item and bis.item and ais.item == bis.item then -- match?
            local ami = assert(M.get_mirror_index(level, ais.x, ais.y))
            local bmi = assert(M.get_mirror_index(level, bis.x, bis.y))
            if not level.matches[ami] and not level.matches[bmi] then -- match!
                level.matches[ami] = true
                level.matches[bmi] = true
                -- level
                local steps = {}
                for j = 1, #a do
                    steps[#steps+1] = a[#a-j+1]
                end
                for j = 2, #b do
                    steps[#steps+1] = b[j]
                end
                ret[#ret+1] = steps
            end
        end
    end

    return ret
    -- TODO: also find if the game is failed by creating 2 disconnected regions
end

return M
