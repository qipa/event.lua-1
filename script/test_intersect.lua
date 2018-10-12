local util = require "util"
local cjson = require "cjson"
local dumpcore = require "dump.core"


local t = {
	a = 1,
	b = "mrq",
	c = 1989.1006,
	d = {
		e = "a",
		f = 1
	}
}

local count = 1024 * 1024 

util.time_diff("cjson",function ()
	for i = 1,count do
		cjson.encode(t)
	end
end)

util.time_diff("dumpcore",function ()
	for i = 1,count do
		dumpcore.tostring(t)
	end
end)

print(cjson.encode(t))
print(dumpcore.tostring(t))