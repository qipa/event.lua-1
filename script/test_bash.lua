local event =require "event"
local channel = require "channel"

local cClientChannel = channel:inherit()


function cClientChannel:data()
	local line = self:read_util("\r\n")
	if line then
		line = string.sub(line,1,string.len(line) - 2)
		event.fork(function ()
			local result = event.run_process("vim README.md")
			self.buffer:write(result)
		end)
		
	end
end

event.fork(function ()
	event.listen("tcp://0.0.0.0:1989",0,function (...)

	end,cClientChannel)
end)