local util = require "util"
local vector2 = require "common.vector2"

-- print(util.capsule_intersect(200,50,300,100,50,99,50,50))


-- local count = 1

-- util.time_diff("decimal_bit0",function ()
-- 	for i = 1,count do
-- 		print(util.decimal_sub0(19891006,5,6))
-- 	end
-- end)

-- util.time_diff("decimal_bit1",function ()
-- 	for i = 1,count do
-- 		print(util.decimal_sub(19891006,5,6))
-- 	end
-- end)

while true do
	local line = util.readline(":",nil,function (str)
		return {"mem"}
	end)
	if line == "q" then
		break
	end
end
-- print(util.sector_intersect(100,100,30,40,100,80,100,50))



-- local count = 1024*1024
-- util.time_diff("dt0",function ()

-- 	for i = 1,count do
-- 		util.sqrt_distance(1,1,100,100,50)
-- 	end
-- end)

-- util.time_diff("dt1",function ()

-- 	for i = 1,count do
-- 		util.sqrt_dot2dot(1,1,100,100,50)
-- 	end
-- end)