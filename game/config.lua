---@class Config
---@field display_width integer
---@field display_height integer
---@field tile_width integer
---@field tile_height integer
---@field levels LevelConfig[]

---@class LevelConfig
---@field width integer
---@field height integer
---@field items Item[] number of items must be equal to `(width + height) * 2`, in the order `top -> right -> bottom -> left`, horizontal left to right, vertical top to bottom

---@alias Item string string like "a", "b" etc., identifies an unique abstract item

---@param width integer
---@param height integer
---@param items Item[]
---@return LevelConfig
local function level(width, height, items)
    assert(#items == (width + height) * 2)
    local freqs = {}
    for i = 1, #items do
        local k = items[i]
        freqs[k] = (freqs[k] or 0) + 1
    end
    for k, v in pairs(freqs) do
        assert(v % 2 == 0, ("number of %s items must be even, was %s"):format(k, v))
    end
    return {
        width = width,
        height = height,
        items = items
    }
end

---@type Config
local M = {
    display_width = sys.get_config_int("display.width"),
    display_height = sys.get_config_int("display.width"),
    tile_width = 64,
    tile_height = 64,
    levels = {
        level(1, 1, { "a", "b", "b", "a" })
    }
}

return M
