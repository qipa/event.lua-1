local event = require "event"
local model = require "model"
local channel = require "channel"
local mongo = require "mongo"
local util = require "util"
local persistence = require "persistence"

local object_module = import "module.object"

_server_channel = _server_channel or {}
_server_name_ctx = _server_name_ctx or {}
_server_counter = _server_counter or nil
_event_listener = _event_listener or object_module.cls_base:new()

local client_channel = channel:inherit()
function client_channel:disconnect()
	_event_listener:fire_event("SERVER_DOWN",self.name,self.id)
	_server_channel[self.id] = nil
	_server_name_ctx[self.name] = nil
	event.wakeup(self.monitor)
end

local server_channel = channel:inherit()
function server_channel:disconnect()
	_server_channel[self.id] = nil
	_server_name_ctx[self.name] = nil
	_event_listener:fire_event("SERVER_DOWN",self.name,self.id)
end

local function channel_accept()

end

function __init__(self)
	if env.name == "world" then
		_server_counter = 1
	end
end

function reserve_id(channel)
	assert(env.name == "world")
	local id = _server_counter
	_server_counter = _server_counter + 1
	return id
end

function register_server(channel,args)
	channel.name = args.name
	channel.id = args.id
	_server_channel[args.id] = channel
	_server_name_ctx[args.name] = args.id
	_event_listener:fire_event("SERVER_CONNECT",args.name,args.id)
end

function agent_amount()
	assert(env.name == "world")
	local amount = 0
	for _,channel in pairs(_server_channel) do
		if channel.name == "agent" then
			amount = amount + 1
		end
	end
	return amount
end

function scene_amount()
	assert(env.name == "world")
	local amount = 0
	for _,channel in pairs(_server_channel) do
		if channel.name == "scene" then
			amount = amount + 1
		end
	end
	return amount
end

function find_server(self,name)
	local result = {}
	for id,channel in pairs(_server_channel) do
		if channel.name == name then
			result[id] = true
		end
	end
	return result
end

function listen_server(self,name)
	local listener,reason = event.listen(env[name],4,channel_accept,server_channel)
	if not listener then
		return listener,reason
	end
	return listener
end

function listen_scene(self)
	local addr
	if env.scene == "ipc" then
		addr = string.format("ipc://scene%02d.ipc",env.dist_id)
	else
		addr = "tcp://0.0.0.0:0"
	end
	local listener,reason = event.listen(addr,4,channel_accept,server_channel)
	if not listener then
		return listener,reason
	end
	return listener
end

function connect_server(self,name,try)
	local function channel_init(channel,name)
		channel.name = name
		channel.monitor = event.gen_session()

		channel:call("module.server_manager","register_server",{id = env.dist_id,name = env.name})
	
		channel.id = env.dist_id

		_server_channel[channel.id] = channel
		_server_name_ctx[channel.name] = channel.id
		_event_listener:fire_event("SERVER_CONNECT",name,channel.id)
	end

	local function channel_connect(name,try)
		local channel,reason
		local count = 0
		while not channel do
			channel,reason = event.connect(env[name],4,false,client_channel)
			if not channel then
				event.error(string.format("connect server:%s %s failed:%s",name,env[name],reason))
				event.sleep(1)
				count = count + 1
				if try and count >= try then
					os.exit(1)
				end
			end
		end
		channel_init(channel,name)
		return channel
	end

	
	local channel = channel_connect(name,try)

	event.fork(function ()
		while true do
			event.wait(channel.monitor)
			channel_connect(name)
		end
	end)
end

function register_event(ev,obj,method)
	_event_listener:register_event(ev,obj,method)
end

function deregister_event(ev,obj)
	_event_listener:deregister_event(obj,ev)
end 

-------------------------------------------------
function send_agent(self,srv_id,file,method,args,callback)
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= "agent" then
		return
	end
	channel:send(file,method,args,callback)
end

function call_agent(self,srv_id,file,method,args)
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= "agent" then
		return
	end
	return channel:call(file,method,args)
end

function send_scene(self,srv_id,file,method,args,callback)
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= "scene" then
		return
	end
	channel:send(file,method,args,callback)
end

function call_scene(self,srv_id,file,method,args)
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= "scene" then
		return
	end
	return channel:call(file,method,args)
end

function send_login(self,file,method,args,callback)
	local srv_id = _server_name_ctx.login
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= srv_id then
		return
	end
	channel:send(file,method,args,callback)
end

function call_login(self,file,method,args)
	local srv_id = _server_name_ctx.login
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= srv_id then
		return
	end
	return channel:call(file,method,args)
end

function send_world(self,file,method,args,callback)
	local srv_id = _server_name_ctx.world
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= srv_id then
		return
	end
	channel:send(file,method,args,callback)
end

function call_world(self,file,method,args)
	local srv_id = _server_name_ctx.world
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= srv_id then
		return
	end
	return channel:call(file,method,args)
end

function send_log(self,file,method,args,callback)
	local srv_id = _server_name_ctx.logger
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= "logger" then
		return
	end
	channel:send(file,method,args,callback)
end

function call_log(self,file,method,args)
	local srv_id = _server_name_ctx.log
	local channel = _server_channel[srv_id]
	if not channel or channel.name ~= srv_id then
		return
	end
	return channel:call(file,method,args)
end
