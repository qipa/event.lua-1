local util = require "util"
local dump = require "dump.core"

-- print(util.size_of("111111"))
-- print(util.size_of("111111xvdfgdsssssssssssssssssssssssssssbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"))


-- print(util.size_of(true))
-- print(util.size_of(1989))
-- print(util.size_of(1989.1006))
-- print(util.size_of(filter_inst0))
-- print(util.size_of(aoi))

local FILE = assert(io.open("./config/filter.lua","r"))
local content = FILE:read("*a")
FILE:close()

local count = collectgarbage("count")

local filter_list = dump.unpack(content)


print(util.size_of(filter_list))
print(util.size_of(content))

print("mem",collectgarbage("count") - count)
