local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local http = require "http"
local route = require "route"
local channel = require "channel"
local clientMgr = require "client_manager"
local serverMgr = require "server_manager"
local startup = import "server.startup"
local id_builder = import "module.id_builder"
local agent_server = import "module.agent_server"

local mongo_indexes = import "common.mongo_indexes"

local xpcall = xpcall
local traceback = debug.traceback

event.fork(function ()
	env.dist_id = startup.reserve_id()

	serverMgr:connect_server("logger")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)
	
	serverMgr:connect_server("world")

	local currentNum,expectNum
	while true do
		currentNum,expectNum = serverMgr:call_world("server_manager","scene_num")
		if currentNum == expectNum then
			break
		end
		event.sleep(1)
	end

	local sceneServerInfo
	while true do
		sceneServerInfo = serverMgr:call_world("scene_manager","sceneServerInfo")
		if #sceneServerInfo == currentNum then
			break
		end
		event.sleep(1)
	end

	for _,info in pairs(sceneServerInfo) do
		serverMgr:connect_server_with_addr()
	end


	serverMgr:connect_server("login")
	

	id_builder:init(env.dist_id)

	local gate_conf = {
		max = 1000,
		port = 0,
		data = agent_server.dispatch_client,
		accept = agent_server.enter,
		close = agent_server.leave
	}
	local port = clientMgr.start(gate_conf)

	serverMgr:send_login("module.agent_manager","register_agent_addr",{id = env.dist_id,addr = {ip = "0.0.0.0",port = port}})

	event.error("start success")
end)
