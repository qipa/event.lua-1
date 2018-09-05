local event = require "event"
local model = require "model"

local server_manager = import "module.server_manager"
local id_builder = import "module.id_builder"


_agent_ctx = _agent_ctx or {}

function __init__(self)
	server_manager:registerEvent("SERVER_DOWN",self,"server_down")
end

function server_down(self,name,srv_id)
	if name ~= "agent" then
		return
	end
end

function register_agent_addr(_,args)
	_agent_ctx[args.id] = {
		addr = args.addr,
		amount = 0
	}
end

function selectAgent(self)
	local min
	local srv_id
	for agent_id,agent_info in pairs(_agent_ctx) do
		if not min or agent_info.amount < min then
			min = agent_info.amount
			srv_id = agent_id
		end
	end
	return srv_id,_agent_ctx[srv_id].addr
end