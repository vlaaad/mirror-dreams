---@class Config
---@field display_width integer
---@field display_height integer
---@field tile_size integer
---@field items string[]
---@field levels LevelConfig[]

---@class LevelConfig
---@field width integer
---@field height integer
---@field items Item[] number of items must be equal to `(width + height) * 2`, in the order `top -> right -> bottom -> left`, horizontal left to right, vertical bottom to top

---@alias Item string string like "a", "b" etc., identifies an unique abstract item

---@param width integer
---@param height integer
---@param str string
---@return LevelConfig
local function level(width, height, str)
    local items = {} ---@type Item[]
    for i = 1, #str do
        items[i] = string.sub(str, i, i)
    end
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

-- `top -> right -> bottom -> left`, horizontal left to right, vertical bottom to top
---@type Config
local M = {
    display_width = sys.get_config_int("display.width"),
    display_height = sys.get_config_int("display.height"),
    tile_size = 64,
    items = {"diamond", "opal", "blue", "violet", "yellow", "black"},
    levels = {
        -- 1-10
        level(1, 1, "abba"),
        level(2, 1, "abbcca"),
        level(2, 2, "aabbbbaa"),
        level(2, 2, "acacbbbb"),
        level(2, 3, "babcccbcba"),
        level(3, 3, "abbbacbaccca"),
        level(2, 2, "abcbdadc"),
        level(3, 3, "abacbbbcdada"),
        level(3, 3, "bbdbbacddadc"),
        level(4, 4, "abcddcacbdabcadb"),
        -- 11-20
        level(4, 4, "cbdbcbdbbdbcadca"),
        level(3, 3, "acbcbcbdabcd"),
        level(5, 3, "bdbcacabcbcacdca"),
        level(4, 3, "aebceedbacaeda"),
        level(4, 4, "accbcadeebacbdab"),
        level(4, 4, "adacdadbdecaebcc"),
        level(4, 3, "aecbccdbbacdbe"),
        level(3, 3, "acdccdcbebae"),
        level(3, 2, "acdecbdeab"),
        level(5, 5, "bcddbcaacbeaeadadbac"),
        -- 21-??
        level(4, 4, "dbcdfefccadedbca"),
        level(3, 4, "afcebfefaddfbc"),
        level(3, 3, "fcecddababfe"),
        level(5, 5, "adafbfedbdfbfcaedcab"),
        level(5, 5, "ababcedfbeccdefbecaa"),
        level(4, 3, "bacaacdebedfaf"),
        level(3, 3, "abcbecdfedfa"),
        level(5, 7, "baeadfacfddbaefcebcbefcd")
    },
    loop_from = 10
}

return M
