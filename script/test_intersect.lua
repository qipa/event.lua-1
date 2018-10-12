local util = require "util"


local count = 1024 * 1024

util.time_diff("!",function ()
	for i = 1,count do
		util.strtod_fast("123.456abc")
	end
end)

util.time_diff("#",function ()
	for i = 1,count do
		tonumber("123.456")
	end
end)