local event = require "event"
local protocol = require "protocol"
local serverMgr = import "module.server_manager"

local modf = math.modf
local xpcall = xpcall
local pairs = pairs
local ipairs = ipairs

_gate = _gate

_onAccept = _onAccept
_onClose = _onClose
_onData = _onData


function __init__(self)

end

local function _clientData(cid,message_id,data,size)
	local cid = cid * 100 + env.dist_id
	local ok,err = xpcall(_onData,debug.traceback,cid,message_id,data,size)
	if not ok then
		event.error(err)
	end
end

local function _clientAccept(cid,addr)
	local cid = cid * 100 + env.dist_id
	local ok,err = xpcall(_onAccept,debug.traceback,cid,addr)
	if not ok then
		event.error(err)
	end
end

local function _clientClose(cid)
	local cid = cid * 100 + env.dist_id
	local ok,err = xpcall(_onClose,debug.traceback,cid)
	if not ok then
		event.error(err)
	end
end


function start(conf)
	local gate = event.gate(conf.max or 1000)
	gate:set_callback(_clientAccept,_clientClose,_clientData)
	local port,reason = gate:start("0.0.0.0",conf.port or 0)
	if not port then
		return false,reason
	end

	_onAccept = conf.accept
	_onClose = conf.close
	_dataFunc = conf.data

	_gate = gate

	return gate
end

function stop(self)
	assert(_gate ~= nil)
	return _gate:stop()
end

function close(self,cid)
	assert(_gate ~= nil)
	local cid = modf(cid / 100) 
	_gate:close(cid)
end

local _doSendClient
local _doBroadcastClient
if env.name == "login" or env.name == "agent" then
	_doSendClient = function (cid,mid,data)
		cid = modf(cid / 100) 
		_gate:send(cid,mid,data)
	end

	_doBroadcastClient = function (cids,mid,data)
		for _,cid in pairs(cids) do
			cid = modf(cid / 100) 
			_gate:send(cid,mid,data)
		end
	end
else
	_doSendClient = function (cid,mid,data)
		local agentId = cid - modf(cid / 100) * 100
		serverMgr:sendAgent(agentId,"module.client_manager","sendClient",{cid = cid,mid = mid,data = data})
	end
	_doBroadcastClient = function (cids,mid,data)
		
		local forwardInfo = {}
		for cid in pairs(cids) do
			local agentId = cid - modf(cid / 100) * 100
			local info = forwardInfo[agentId]
			if not info then
				info = {}
				forwardInfo[agentId] = info
			end
			table.insert(info,cid)
		end

		for agentId,cids in pairs(forwardInfo) do
			serverMgr:sendAgent(agentId,"module.client_manager","broadcastClient",{cid = cids,mid = mid,data = data})
		end
	end
end

function sendClient(cid,pto,message)
	assert(protocol.encode[pto] ~= nil,string.format("no such pto:%s",pto))
	local mid,data = protocol.encode[pto](message)
	_doSendClient(cid,mid,data)
end

function broadcastClient(cids,pto,message)
	local mid,data = protocol.encode[pto](message)
	_doBroadcastClient(cids,mid,data)
end

_G.sendClient = sendClient
_G.broadcastClient = broadcastClient
