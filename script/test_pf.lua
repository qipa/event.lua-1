local util = require "util"
local finder_core = require "pathfinder.core"

local finder = finder_core.create(1,"./config/city.blk")

-- table.print(finder:find(93 ,178 ,133 ,118, 0),"1")
table.print(finder:find(87 ,123 ,372 ,106, 1),"2")
util.time_diff("PATH1",function ()
		for i = 1,1024 do
			finder:find(87 ,123 ,372 ,106, 1)
		end
	end)
	

-- util.time_diff("PATH2",function ()
-- 		for i = 1,1024 * 10 do
-- 			finder:find(87 ,123 ,372 ,106, 0)
-- 		end
-- 	end)
	
