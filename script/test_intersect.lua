local util = require "util"



local now = os.time()
local count = 1024 * 1024

util.time_diff("s0",function ()
	for i = 1,count do
		util.day_start(now)
	end
end)

util.time_diff("s1",function ()
	for i = 1,count do
		util.week_start(now)
	end
end)

