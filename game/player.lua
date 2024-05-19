local config = require "game.config"

local M = {}
local save_file = sys.get_save_file("dev.vlaaad.mirrormatch", "player")

---@class PlayerState
---@field highest_level integer the highest real level the player already played
---@field display_level integer the level presented to the user, always incremented on success
---@field looping_level? integer when we will start repeating levels, this is will be the real level that the player currently plays

---@return PlayerState
function M.get()
	local player = sys.load(save_file)
	if not next(player) then
		---@type PlayerState
		local state = {
			highest_level = 0,
			display_level = 1
		}
		return state
	else
		return player
	end
end

---@param player PlayerState
---@return integer real_level
function M.get_next_real_level(player)
	local max_real_level = #config.levels
	if max_real_level > player.highest_level then
		-- haven't played all levels yet
		return player.highest_level + 1
	elseif not player.looping_level then
		-- just started looping
		return config.loop_from
	else
		-- we are already looping
		return player.looping_level
	end
end

---update the state to proceed to the next level and save
---@param player PlayerState
function M.complete_level(player)
	-- switch to next level
	local max_real_level = #config.levels
	if max_real_level > player.highest_level then
		-- there are new levels
		player.highest_level = player.highest_level + 1
	elseif not player.looping_level then
		-- just started looping
		player.looping_level = config.loop_from + 1
	elseif player.looping_level >= max_real_level then
		-- last level, restart the looping
		player.looping_level = config.loop_from
	else
		-- continue looping
		player.looping_level = player.looping_level + 1
	end
	player.display_level = player.display_level + 1

	-- save
	sys.save(save_file, player)
end

return M