local util = require "util"


local in_front_of = util.in_front_of
local count = 1024*1024

util.time_diff("infrontof1",function ()
	for i = 1,count do
		util.in_front_of(0,0,30,-1,-1)
	end
end)

util.time_diff("infrontof2",function ()
	for i = 1,count do
		in_front_of(0,0,30,-1,-1)
	end
end)


