local event = require "event"
local channel = require "channel"


for i = 1,50 do
	event.fork(function ()
		local channel,err = event.connect("tcp://127.0.0.1:1989",4,false,channel)
		if not channel then
			event.breakout(err)
		end

		while true do
			for i = 1,1024 do
				channel:send("handler.test_handler","test_rpc",{fuck = 1})
			end
			event.sleep(0.2)
		end
	end)
end