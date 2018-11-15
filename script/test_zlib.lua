


local util = require "util"

local FILE = io.open("./event","rb")
local content = FILE:read("*a")
FILE:close()

local out
local count = 100
util.time_diff("compress",function ()
	for i = 1,count do
		out = util.compress(content)
	end
end)

util.time_diff("uncompress",function ()
	for i = 1,count do
		util.uncompress(out,content:len())
	end
end)

