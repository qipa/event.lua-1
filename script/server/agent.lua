local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local http = require "http"
local route = require "route"
local channel = require "channel"
local clientMgr = import "module.client_manager"
local serverMgr = import "module.server_manager"
local startup = import "server.startup"
local idBuilder = import "module.id_builder"
local agent_server = import "module.agent.agent_server"

local mongo_indexes = import "common.mongo_indexes"

local xpcall = xpcall
local traceback = debug.traceback

event.fork(function ()
	env.distId = startup.reserveId()

	startup.run(env.serverId,env.distId,env.monitor,env.mongodb,env.config,env.protocol)
	
	serverMgr:connectServer("world")

	while true do
		local isStart = serverMgr:sendWorld("module.world.world_server","isServerStart")
		if not isStart then
			event.sleep(1)
		else
			break
		end
	end

	serverMgr:connectServer("login")

	local gate_conf = {
		max = 1000,
		port = 0,
		data = agent_server.dispatch_client,
		accept = agent_server.enter,
		close = agent_server.leave
	}
	local port = clientMgr.start(gate_conf)

	serverMgr:sendLogin("module.login.agent_manager","reportAgentAddr",{id = env.distId,addr = {ip = "0.0.0.0",port = port}})

	event.error("start success")
end)
