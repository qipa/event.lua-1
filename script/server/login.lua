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
	env.distId = startup.reserveId()
	startup.run(env.serverId,env.distId,env.monitor,env.mongodb,env.config,env.protocol)

	serverMgr:listenServer("login")

	local gateConf = {
		max = 1000,
		port = 0,
		onAccept = loginServer.enter,
		onClose = loginServer.leave
	}
	local port = clientMgr.start(gateConf)

	loginServer:start()
end)
