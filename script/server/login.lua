local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local mongo = require "mongo"
local channel = require "channel"
local route = require "route"
local http = require "http"
local debugger = require "debugger"
local startup = import "server.startup"
local idBuilder = import "module.id_builder"
local clientMgr = import "module.client_manager"
local serverMgr = import "module.server_manager"
local loginServer = import "module.login.login_server"

event.fork(function ()
	env.dist_id = startup.reserveId()
	startup.run(env.uid,env.dist_id,env.monitor,env.mongodb,env.config,env.protocol)

	serverMgr:listenServer("login")

	local agentInfo = startup.agentAmount()
	while not agentInfo or agentInfo.needAmount ~= agentInfo.currAmount do
		agentInfo = startup.agentAmount()
		event.error(string.format("wait for agent connect:%d %d",agentInfo.needAmount,agentInfo.currAmount))
		event.sleep(1)
	end
	
	local gateConf = {
		max = 1000,
		port = 0,
		onData = loginServer.dispatch_client,
		onAccept = loginServer.enter,
		onClose = loginServer.leave
	}
	local port = clientMgr.start(gateConf)

	loginServer:start()
end)
