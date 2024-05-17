local logic = require("game.logic")
local config = require("game.config")
local camera = require("game.camera")

local M = {}


---@param x integer
---@param y integer
---@return vector3
local function coord_to_board_pos(x,y)
    return vmath.vector3((x - 1) * config.tile_size, (y - 1) * config.tile_size, 0)
end

---@param level Level
---@param id_to_item table<string,string>
---@param item_gos userdata[]
---@param x integer
---@param y integer
local function create_item_view(level, id_to_item, item_gos, x, y)
    local mi = assert(logic.get_mirror_index(level, x, y))
    local item = id_to_item[level.config.items[mi]]
    local item_go = factory.create("#item", coord_to_board_pos(x, y))
    go.set_parent(item_go, ".")
    sprite.play_flipbook(msg.url(nil, item_go, hash("view")), "item_" .. item)
    item_gos[mi] = item_go
end

local function create_mirror_view(x, y, direction)
    local mirror_go = factory.create("#mirror", coord_to_board_pos(x, y))
    go.set_parent(mirror_go, ".")
    sprite.play_flipbook(msg.url(nil, mirror_go, hash("view")), "mirror_" .. direction)
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
---@field item_gos userdata[]

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
    local item_gos = {}
    -- top right bottom left
    for x = 1, level_config.width do 
        local y = level_config.height + 1
        create_item_view(level, id_to_item, item_gos, x, y)
    end
    for y = 1, level_config.height do
        local x = level_config.width + 1
        create_item_view(level, id_to_item, item_gos, x, y)
    end
    for x = 1, level_config.width do 
        create_item_view(level, id_to_item, item_gos, x, 0)
    end
    for y = 1, level_config.height do
        create_item_view(level, id_to_item, item_gos, 0, y)
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
        item_gos = item_gos,
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
---@param x integer
---@param y integer
local function show_item_match(view, x, y)
    local item_go = view.item_gos[assert(logic.get_mirror_index(view.level, x, y))]
    local check_url = msg.url(nil, item_go, hash("check"))
    sprite.play_flipbook(check_url, "ui_item_match")
    go.set(check_url, "scale", vmath.vector3())
    go.animate(check_url, "scale", go.PLAYBACK_ONCE_FORWARD, vmath.vector3(1.0), go.EASING_OUTBACK, 0.5)
end

---@param view LevelView
---@param steps RayStep[]
local function show_ray_trail(view, steps) 
    for i = 1, #steps do
        local step = steps[i]
        local ray_go = factory.create("#ray", coord_to_board_pos(step.x, step.y))
        go.set_parent(ray_go, ".")
        local view_url = msg.url(nil, ray_go, hash("view"))
        sprite.play_flipbook(view_url, "ray_" .. step.shape)
        go.animate(view_url, "tint.w", go.PLAYBACK_ONCE_FORWARD, 0, go.EASING_LINEAR, 1.0, 0.0, function ()
            go.delete(ray_go)
        end)
    end
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
                    local matches = logic.place_mirror(view.level, dot.x, dot.y, dot.direction)
                    create_mirror_view(dot.x, dot.y, dot.direction)
                    for j = 1, #matches do
                        timer.delay((j - 1) * 0.5, false, function()
                            local match = matches[j]
                            local first = match[1]
                            show_item_match(view, first.x, first.y)
                            local last = match[#match]
                            show_item_match(view, last.x, last.y)
                            show_ray_trail(view, match)
                        end)
                    end
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