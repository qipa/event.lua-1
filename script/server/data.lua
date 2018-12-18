local event = require "event"
local util = require "util"
local dataServer = import "module.data.data_server"

event.fork(function ()
	event.listen("ipc://data.ipc",4,function (channel)

	end)

	dataServer:start(8)

	util.time_diff("load",function ()
		for i = 1,1024 * 100 do
			dataServer:loadUser({userUid = i})
		end
	end)

	local now = util.time()
	for i = 1,1024 * 100 do
		event.fork(function ()
			dataServer:loadUser({userUid = i})
			if i == 1024 * 100 then
				print(util.time() - now)
			end
		end)
	end
end)