---@class Level
---@field config LevelConfig
---@field mirrors (MirrorDirection|false)[]

---@alias MirrorDirection "up-right"|"down-right"

local M = {}

---@param config LevelConfig
---@return Level
function M.create_level(config)
	local mirrors = {}
	for i = 1, config.width * config.height do
		mirrors[i] = false
	end
	---@type Level
	local level = { config = config, mirrors = mirrors }
	return level
end

---@param level Level
---@param x integer
---@param y integer
---@return MirrorDirection?
function M.get_mirror(level, x, y)
	assert(x >= 1 and x <= level.config.width)
	assert(y >= 1 and y <= level.config.height)
	local ret = level.mirrors[x + (y - 1) * level.config.width]
	return ret or nil
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

return M
