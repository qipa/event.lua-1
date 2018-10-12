local util = require "util"



local count = 1024 * 1024

util.time_diff("s0",function ()
	for i = 1,count do
		util.same_day(1539313692,1539187200)
	end
end)

util.time_diff("s1",function ()
	for i = 1,count do
		util.is_same_day(1539313692,1539187200)
	end
end)

