---@class Level
---@field config LevelConfig
---@field mirrors (MirrorDirection|false)[]
---@field matches boolean[] item matches, same ordering as config's items
---@field failed boolean

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
        matches = matches,
        failed = false
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

local todo_template = "%d/%d/%s"

---@param x integer
---@param y integer
---@param direction RayDirection
---@return string
local function cast_ray_make_todo(x, y, direction)
    return todo_template:format(x, y, direction)
end

local todo_parse = "^(%d+)/(%d+)/(.+)"

---@param todo string
---@return integer x
---@return integer y
---@return RayDirection direction
local function cast_ray_parse_todo(todo)
    local sx, sy, dir = string.match(todo, todo_parse)
    return tonumber(sx) --[[@as integer]], tonumber(sy) --[[@as integer]], dir
end

---@param x integer
---@param y integer
---@param direction RayDirection
---@return string
local function cast_ray_next_todo(x, y, direction)
    if direction == "up" then
        return cast_ray_make_todo(x, y + 1, direction)
    elseif direction == "down" then
        return cast_ray_make_todo(x, y - 1, direction)
    elseif direction == "left" then
        return cast_ray_make_todo(x - 1, y, direction)
    else
        return cast_ray_make_todo(x + 1, y, direction)
    end
end

---@param x integer
---@param y integer
---@param direction RayDirection
---@return string
local function fill_ray_reverse_todo(x, y, direction) 
    if direction == "up" then
        return cast_ray_make_todo(x, y - 1, "down")
    elseif direction == "down" then
        return cast_ray_make_todo(x, y + 1, "up")
    elseif direction == "left" then
        return cast_ray_make_todo(x + 1, y, "right")
    else
        return cast_ray_make_todo(x - 1, y, "left")
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
local function cast_ray_reflect(ray_direction, mirror_direction)
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
    local todo = cast_ray_make_todo(x, y, direction) ---@type string?
    local steps = {} ---@type RayStep[]
    while todo do
        if visited[todo] then 
            break 
        end
        visited[todo] = true
        local tx, ty, dir = cast_ray_parse_todo(todo)
        local mirror_or_item = get_mirror_or_item(level, tx, ty)
        if is_mirror(mirror_or_item) then
            -- found mirror, reflect
            local next_dir = cast_ray_reflect(dir, mirror_or_item --[[@as MirrorDirection]])
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

---@class ReachableItem
---@field x integer
---@field y integer
---@field item string

---@param level Level
---@param x integer
---@param y integer
---@param direction RayDirection
---@return ReachableItem[] reachable_items
local function fill_ray(level, x, y, direction)
    local visited = {}
    local todos = {cast_ray_make_todo(x, y, direction), fill_ray_reverse_todo(x, y, direction)}
    local results = {} ---@type ReachableItem[]
    while #todos > 0 do
        local todo = table.remove(todos)
        if not visited[todo] then
            visited[todo] = true
            local tx, ty, dir = cast_ray_parse_todo(todo)
            local mirror_or_item = get_mirror_or_item(level, tx, ty)
            if is_mirror(mirror_or_item) then
                -- found mirror, reflect
                todos[#todos+1] = cast_ray_next_todo(tx, ty, cast_ray_reflect(dir, mirror_or_item --[[@as MirrorDirection]]))
            elseif not mirror_or_item then
                -- empty space, fill in every possible direction
                todos[#todos+1] = cast_ray_next_todo(tx, ty, "up")
                todos[#todos+1] = cast_ray_next_todo(tx, ty, "down")
                todos[#todos+1] = cast_ray_next_todo(tx, ty, "left")
                todos[#todos+1] = cast_ray_next_todo(tx, ty, "right")
            elseif not level.matches[assert(M.get_mirror_index(level, tx, ty))] then
                -- found an unmatched item
                results[#results+1] = {x = tx, y = ty, item = mirror_or_item}
            end
        end
    end
    return results
end

---@param level Level
---@return boolean
function M.is_win(level)
    for i = 1, #level.matches do
        if not level.matches[i] then 
            return false 
        end
    end
    return true
end

---@param level Level
---@return boolean
function M.is_ended(level)
    return level.failed or M.is_win(level)
end

---@class PlaceMirrorResult
---@field match_rays RayStep[][]
---@field failures ReachableItem[]?

---@param level Level
---@param x integer
---@param y integer
---@param direction MirrorDirection
---@return PlaceMirrorResult
function M.place_mirror(level, x, y, direction)
    assert(not M.is_ended(level))
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

    local match_rays = {} ---@type RayStep[][]
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
                match_rays[#match_rays+1] = steps
            end
        end
    end

    local unmatchable_items = {} ---@type ReachableItem[]
    local reachable_regions = {fill_ray(level, x, y, "up"), fill_ray(level, x, y, "down")}
    for i = 1, #reachable_regions do
        local reachable_items = reachable_regions[i]
        local item_to_reachable_items = {} ---@type table<string, ReachableItem[]>
        for j = 1, #reachable_items do
            local reachable_item = reachable_items[j]
            local grouped_items = item_to_reachable_items[reachable_item.item]
            if not grouped_items then
                grouped_items = {}
                item_to_reachable_items[reachable_item.item] = grouped_items
            end
            grouped_items[#grouped_items+1] = reachable_item
        end
        for _, grouped_reachable_items in pairs(item_to_reachable_items) do
            if #grouped_reachable_items % 2 ~= 0 then
                unmatchable_items[#unmatchable_items+1] = grouped_reachable_items[1]
            end
        end
    end
    if #unmatchable_items > 0 then
        level.failed = true
    end
    ---@type PlaceMirrorResult
    local result = {
        match_rays = match_rays,
        failures = #unmatchable_items > 0 and unmatchable_items or nil
    }
    return result
end

return M
