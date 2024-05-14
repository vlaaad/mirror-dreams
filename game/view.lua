local logic = require("game.logic")
local config = require("game.config")
local camera = require("game.camera")

local M = {}

local function create_item_view(item, x, y)
    local item_go = factory.create("#item", vmath.vector3((x-1) * config.tile_size, (y-1) * config.tile_size, 0))
    go.set_parent(item_go, ".")
    sprite.play_flipbook(msg.url(nil, item_go, hash("view")), "item_" .. item)
end

---@generic T
---@param t T[]
---@return T[]
local function shuffle(t)
    local s = {}
    for i = 1, #t do s[i] = t[i] end
    for i = #t, 2, -1 do
        local j = math.random(i)
        s[i], s[j] = s[j], s[i]
    end
    return s
end

---@param level Level
---@param dot_x integer
---@param dot_y integer
---@return integer
local function dot_xy_to_index(level, dot_x, dot_y) 
    return dot_x + 1 + dot_y * (level.config.width + 1)
end

---@class LevelView
---@field level Level
---@field camera Camera
---@field dot_sprites userdata[]
---@field available_dots AvailableTurn[]

---@param level_id integer
---@return LevelView
function M.create_view(level_id)
    local level_config = config.levels[level_id]
    local random_items = shuffle(config.items)
    local id_to_item = {}
    for i = 1, #level_config.items do
        local id = level_config.items[i]
        if not id_to_item[id] then
            id_to_item[id] = assert(table.remove(random_items))
        end
    end
    local level = logic.create_level(level_config)
    local view_width = (level_config.width) * config.tile_size
    local view_height = (level_config.height) * config.tile_size
    go.set_position(vmath.vector3((config.display_width - view_width) * 0.5, (config.display_height - view_height) * 0.5, 0))
    for x = 1, level_config.width do
        local top = level_config.items[x]
        create_item_view(id_to_item[top], x, level_config.height + 1)
        local bottom = level_config.items[x + level_config.width + level_config.height]
        create_item_view(id_to_item[bottom], x, 0)
    end
    for y = 1, level_config.height do
        local right = level_config.items[level_config.width + y]
        create_item_view(id_to_item[right], level_config.width + 1, y)
        local left = level_config.items[level_config.width + level_config.width + level_config.height + y]
        create_item_view(id_to_item[left], 0, y)
    end
    local dot_sprites = {}
    for y = 0, level_config.height do
        for x = 0, level_config.width do
            local dot_go = factory.create("#dot", vmath.vector3(x * config.tile_size, y * config.tile_size, 0))
            go.set_parent(dot_go, ".")
            dot_sprites[dot_xy_to_index(level, x, y)] = msg.url(nil, dot_go, hash("view"))
        end
    end

    ---@type LevelView
    local ret = {
        level = level,
        camera = camera.create(0, 0, config.display_width, config.display_height),
        dot_sprites = dot_sprites,
        available_dots = {}
    }
    return ret
end

---@param view LevelView
---@param dot_x integer
---@param dot_y integer
---@param available_dots AvailableTurn[]
local function highlight_available_turns(view, dot_x, dot_y, available_dots)
    local active_index = dot_xy_to_index(view.level, dot_x, dot_y)
    for i = 1, #view.dot_sprites do
        sprite.play_flipbook(view.dot_sprites[i], active_index == i and "control_dot_active" or "control_dot")
    end
    for i = 1, #available_dots do
        local dot = available_dots[i]
        sprite.play_flipbook(view.dot_sprites[dot_xy_to_index(view.level, dot.dot_x, dot.dot_y)], "control_dot_available")
    end
    view.available_dots = available_dots
end

---@param view LevelView
local function clear_available_turns(view)
    for i = 1, #view.dot_sprites do
        sprite.play_flipbook(view.dot_sprites[i], "control_dot")
    end
    view.available_dots = {}
end

---@param view LevelView
---@param action_id userdata
---@param action table
function M.on_input(view, action_id, action)
    if action_id == hash("touch") then
        if action.pressed then
            local world_pos = camera.screen_to_world_2d(view.camera, action.screen_x, action.screen_y)
            local logic_pos = (world_pos - go.get_position()) / config.tile_size
            local dot_x = math.floor(logic_pos.x + 0.5)
            local dot_y = math.floor(logic_pos.y + 0.5)
            highlight_available_turns(view, dot_x, dot_y, logic.get_available_dots(view.level, dot_x, dot_y))
        elseif action.released then
            local world_pos = camera.screen_to_world_2d(view.camera, action.screen_x, action.screen_y)
            local logic_pos = (world_pos - go.get_position()) / config.tile_size
            local dot_x = math.floor(logic_pos.x + 0.5)
            local dot_y = math.floor(logic_pos.y + 0.5)
            for i = 1, #view.available_dots do
                local dot = view.available_dots[i]
                if dot.dot_x == dot_x and dot.dot_y == dot_y then
                    -- TODO: insert mirror here!
                    pprint(dot)
                    break
                end
            end
            clear_available_turns(view)
        end
    end
    -- pprint({level, action_id, action})
end

---@param level_view LevelView
function M.update(level_view)
    camera.update(level_view.camera)
end

return M