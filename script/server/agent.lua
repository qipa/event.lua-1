local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local http = require "http"
local route = require "route"
local channel = require "channel"
local startup = import "server.startup"
local id_builder = import "module.id_builder"
local agent_server = import "module.agent_server"

local mongo_indexes = import "common.mongo_indexes"

local xpcall = xpcall
local traceback = debug.traceback


local function client_data(cid,message_id,data,size)
	local ok,err = xpcall(agent_server.dispatch_client,traceback,agent_server,cid,message_id,data,size)
	if not ok then
		event.error(err)
	end
end

local function client_accept(cid,addr)
	local ok,err = xpcall(agent_server.enter,traceback,agent_server,cid,addr)
	if not ok then
		event.error(err)
	end
end

local function client_close(cid)
	local ok,err = xpcall(agent_server.leave,traceback,agent_server,cid)
	if not ok then
		event.error(err)
	end
end


event.fork(function ()
	env.dist_id = startup.reserve_id()

	server_manager:connect_server("logger")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)
	
	server_manager:connect_server("login")
	server_manager:connect_server("world")

	id_builder:init(env.dist_id)

	local gate = event.gate(1024)
	gate:set_callback(client_accept,client_close,client_data)
	local port,reason = gate:start("0.0.0.0",0)
	if not port then
		event.breakout(string.format("%s %s",env.name,reason))
		os.exit(1)
	end

	server_manager:send_login("module.agent_manager","register_agent_addr",{id = env.dist_id,addr = {ip = "0.0.0.0",port = port}})

	agent_server:start(gate)
	event.error("start success")
end)
