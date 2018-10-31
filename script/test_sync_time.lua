local event = require "event"
import "handler.sync_time"
event.fork(function ()
	local listener = event.listen("tcp://0.0.0.0:1989",2,function (...)
		print(...)
	end)
end)