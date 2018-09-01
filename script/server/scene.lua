local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local mongo = require "mongo"
local route = require "route"
local channel = require "channel"
local http = require "http"
local helper = require "helper"
local startup = import "server.startup"
local server_manager = import "module.server_manager"
local id_builder = import "module.id_builder"
local mongo_indexes = import "common.mongo_indexes"



event.fork(function ()
	env.dist_id = startup.reserve_id()
	
	server_manager:connect_server("world")
	server_manager:connect_server("logger")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)

	id_builder:init(env.dist_id)

	local listener,reason = server_manager:listen_scene()
	if not listener then
		event.breakout(reason)
		return
	end

	local addr = listener:addr()
	server_manager:send_world("module.server_manager","register_scene_addr",{id = env.dist_id,addr = addr})

	import "handler.scene_handler"

end)
