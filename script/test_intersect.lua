local util = require "util"


local count = 1024 * 1024

util.time_diff("!",function ()
	for i = 1,count do
		util.strtod_fast0("1.23456")
	end
end)

util.time_diff("#",function ()
	for i = 1,count do
		util.strtod_fast1("1.23456")
	end
end)

util.time_diff("$",function ()
	for i = 1,count do
		tonumber("1.23456")
	end
end)