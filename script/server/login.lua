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
local id_builder = import "module.id_builder"
local client_manager = import "module.client_manager"
local server_manager = import "module.server_manager"
local login_server = import "module.login.login_server"
local mongo_indexes = import "common.mongo_indexes"


local function channel_accept(_,channel)
	
end

local function client_data(cid,message_id,data,size)
	local ok,err = xpcall(login_server.dispatch_client,debug.traceback,login_server,cid,message_id,data,size)
	if not ok then
		event.error(err)
	end
end

local function client_accept(cid,addr)
	local ok,err = xpcall(login_server.enter,debug.traceback,login_server,cid,addr)
	if not ok then
		event.error(err)
	end
end

local function client_close(cid)
	local ok,err = xpcall(login_server.leave,debug.traceback,login_server,cid)
	if not ok then
		event.error(err)
	end
end

event.fork(function ()
	env.dist_id = startup.reserve_id()
	server_manager:connect_server("logger")
	startup.run(env.monitor,env.mongodb,env.config,env.protocol)

	id_builder:init(env.dist_id)
	
	local gate_conf = {
		max = 1000,
		port = 0,
		data = login_server.dispatch_client,
		accept = login_server.enter,
		close = login_server.leave
	}
	local port = client_manager.start(gate_conf)

	login_server:start()
end)
