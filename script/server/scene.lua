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
local idBuilder = import "module.id_builder"
local mongo_indexes = import "common.mongo_indexes"



event.fork(function ()
	env.distId = startup.reserveId()
	
	server_manager:connectServer("world")
	server_manager:connectServer("logger")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)

	idBuilder:init(env.distId)

	local listener,reason = server_manager:listenScene()
	if not listener then
		event.breakout(reason)
		return
	end

	local addr = listener:addr()
	server_manager:sendWorld("module.server_manager","register_scene_addr",{id = env.distId,addr = addr})

	import "handler.scene_handler"

end)
