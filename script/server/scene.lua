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

local agent_channel = channel:inherit()
function agent_channel:disconnect()

end

local function agent_accept(_,channel)


end

event.fork(function ()
	server_manager:connect_server("world")

	startup.run(env.monitor,env.mongodb,env.config,env.protocol)

	env.dist_id = startup.apply_id()
	id_builder:init(env.dist_id)

	local listener,reason = server_manager:listen_scene()
	if not listener then
		event.breakout(reason)
		return
	end
	local ip,port = listener:addr()
	local addr_info = {}
	if port == 0 then
		addr_info.file = ip
	else
		addr_info.ip = ip
		addr_info.port = port
	end

	local world_channel = model.get_world_channel()
	world_channel:send("module.server_manager","register_scene_server",{id = env.dist_id,addr = addr_info})

	import "handler.scene_handler"

end)
