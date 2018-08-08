local event = require "event"
local protocol = require "protocol"
local server_manager = import "module.server_manager"

local modf = math.modf
local xpcall = xpcall
local pairs = pairs
local ipairs = ipairs

_gate = _gate

_accept_func = _accept_func
_close_func = _close_func
_data_func = _data_func


function __init__(self)

end

local function client_data(cid,message_id,data,size)
	local cid = cid * 100 + env.dist_id
	local ok,err = xpcall(_data_func,debug.traceback,cid,message_id,data,size)
	if not ok then
		event.error(err)
	end
end

local function client_accept(cid,addr)
	local cid = cid * 100 + env.dist_id
	local ok,err = xpcall(_accept_func,debug.traceback,cid,addr)
	if not ok then
		event.error(err)
	end
end

local function client_close(cid)
	local cid = cid * 100 + env.dist_id
	local ok,err = xpcall(_data_func,debug.traceback,cid)
	if not ok then
		event.error(err)
	end
end


function start(conf)
	local gate = event.gate(conf.max or 1000)
	gate:set_callback(client_accept,client_close,client_data)
	local port,reason = gate:start("0.0.0.0",conf.port or 0)
	if not port then
		return false,reason
	end

	_accept_func = conf.accept
	_close_func = conf.close
	_data_func = conf.data

	_gate = gate

	return gate
end

local do_send_client
local do_broadcast_client
if env.name == "login" or env.name == "agent" then
	do_send_client = function (cid,mid,data)
		cid = modf(cid / 100) 
		_gate:send(cid,mid,data)
	end

	do_broadcast_client = function (cids,mid,data)
		for _,cid in pairs(cids) do
			cid = modf(cid / 100) 
			_gate:send(cid,mid,data)
		end
	end
else
	do_send_client = function (cid,mid,data)
		local agent_id = cid - modf(cid / 100) * 100
		server_manager:send_agent(agent_id,"module.client_manager","send_client",{cid = cid,mid = mid,data = data})
	end
	do_broadcast_client = function (cids,mid,data)
		
		local forward_info = {}
		for cid in pairs(cids) do
			local agent_id = cid - modf(cid / 100) * 100
			local info = forward_info[agent_id]
			if not info then
				info = {}
				forward_info[agent_id] = info
			end
			table.insert(info,cid)
		end

		for agent_id,cids in pairs(forward_info) do
			server_manager:send_agent(agent_id,"module.client_manager","broadcast_client",{cid = cids,mid = mid,data = data})
		end
	end
end

function send_client(cid,pto,message)
	local mid,data = protocol.encode[pto](message)
	do_send_client(cid,mid,data)
end

function broadcast_client(cids,pto,message)
	local mid,data = protocol.encode[pto](message)
	do_broadcast_client(cids,mid,data)
end

_G.send_client = send_client
_G.broadcast_client = broadcast_client