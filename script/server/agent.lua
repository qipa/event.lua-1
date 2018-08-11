local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local http = require "http"
local route = require "route"
local channel = require "channel"
local client_manager = require "client_manager"

local startup = import "server.startup"
local id_builder = import "module.id_builder"
local agent_server = import "module.agent_server"

local mongo_indexes = import "common.mongo_indexes"

local xpcall = xpcall
local traceback = debug.traceback

event.fork(function ()
	env.dist_id = startup.reserve_id()

	server_manager:connect_server("logger")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)
	
	server_manager:connect_server("login")
	server_manager:connect_server("world")

	id_builder:init(env.dist_id)

	local gate_conf = {
		max = 1000,
		port = 0,
		data = agent_server.dispatch_client,
		accept = agent_server.enter,
		close = agent_server.leave
	}
	local port = client_manager.start(gate_conf)

	server_manager:send_login("module.agent_manager","register_agent_addr",{id = env.dist_id,addr = {ip = "0.0.0.0",port = port}})

	event.error("start success")
end)
