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



function __init__(self)

end

local function _onClientData(cid,mesasgeId,data,size)
	local reader = protocol.reader[messageId]
	if not reader then
		event.error(string.format("no such pto id:%d",mesasgeId))
		return
	end
	local cid = cid * 100 + env.distId
	local ok,err = xpcall(reader,debug.traceback,cid,data,size)
	if not ok then
		event.error(err)
	end
end

local function _onClientAccept(cid,addr)
	local cid = cid * 100 + env.distId
	local ok,err = xpcall(_onAccept,debug.traceback,cid,addr)
	if not ok then
		event.error(err)
	end
end

local function _onClientClose(cid)
	local cid = cid * 100 + env.distId
	local ok,err = xpcall(_onClose,debug.traceback,cid)
	if not ok then
		event.error(err)
	end
end


function start(conf)
	local gate = event.gate(conf.max or 1000)
	gate:set_callback(_onClientAccept,_onClientClose,_onClientData)
	local port,reason = gate:start("0.0.0.0",conf.port or 0)
	if not port then
		return false,reason
	end

	_onAccept = conf.onAccept
	_onClose = conf.onClose

	_gate = gate

	return port
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

function sendClientData(cid,mid,data)
	if type(cid) == "number" then
		_doSendClient(cid,mid,data)
	else
		_doBroadcastClient(cid,mid,data)
	end
end

rawset(_G,"sendClient",sendClient)
rawset(_G,"broadcastClient",broadcastClient)

