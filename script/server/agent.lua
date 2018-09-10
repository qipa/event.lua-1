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
	env.dist_id = startup.reserveId()

	serverMgr:connectServer("logger")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)
	
	serverMgr:connectServer("world")

	local currentNum,expectNum
	while true do
		currentNum,expectNum = serverMgr:callWorld("server_manager","scene_num")
		if currentNum == expectNum then
			break
		end
		event.sleep(1)
	end

	local sceneServerInfo
	while true do
		sceneServerInfo = serverMgr:callWorld("scene_manager","sceneServerInfo")
		if #sceneServerInfo == currentNum then
			break
		end
		event.sleep(1)
	end

	for _,info in pairs(sceneServerInfo) do
		serverMgr:connectServerWithAddr()
	end


	serverMgr:connectServer("login")
	

	id_builder:init(env.dist_id)

	local gate_conf = {
		max = 1000,
		port = 0,
		data = agent_server.dispatch_client,
		accept = agent_server.enter,
		close = agent_server.leave
	}
	local port = clientMgr.start(gate_conf)

	serverMgr:sendLogin("module.agent_manager","register_agent_addr",{id = env.dist_id,addr = {ip = "0.0.0.0",port = port}})

	event.error("start success")
end)
