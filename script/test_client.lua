local event = require "event"
local channel = require "channel"
local util = require "util"
local protocol = require "protocol"
local startup = import "server.startup"

local response = {}

local client_channel = channel:inherit()

function client_channel:disconnect()
	-- event.error("client_channel disconnect")
end

function client_channel:data(data,size)
	local id,data,size = self.packet:unpack(data,size)
	
end


event.fork(function ()
	
	for i = 1,1000 do
		event.fork(function ()
			-- print(string.format("tcp://127.0.0.1:1989"))
			local channel,err = event.connect("tcp://127.0.0.1:1989",2,false,client_channel)
			if not channel then
				event.error(err)
				return
			end
			channel.packet = util.packet_new()
			for i = 1,2000 do
				channel:write(channel.packet:pack(1,table.encode{ta = 1,hi = "mrq"}))
				event.sleep(0.001)
			end
			-- channel:close()
		end)
	end
end)

