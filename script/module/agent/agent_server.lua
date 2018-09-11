local event = require "event"
local model = require "model"
local util = require "util"
local route = require "route"
local cjson = require "cjson"
local protocol = require "protocol"
local channel = require "channel"
local timer = require "timer"
local client_manager = import "module.client_manager"
local server_manager = import "module.server_manager"
local module_object = import "module.object"
local agent_user = import "module.agent_user"
local scene_user = import "module.scene_user"
local common = import "common.common"

local kAUTH_TIME = 60

_tokenMgr = _tokenMgr or {}
_enter_user = _enter_user or {}
_server_stop = _server_stop or false

function __init__(self)
	server_manager:registerEvent("SERVER_DOWN",self,"server_down")
end

function start(self)
	timer.callout(1,self,"authTimer")

	import "handler.agent_handler"
	import "handler.cmd_handler"
end



function authTimer(self)
	local now = util.time()
	for token,info in pairs(_tokenMgr) do
		if now - info.time >= kAUTH_TIME then
			_tokenMgr[token] = nil
			event.error(string.format("%s:%d auth timeout",info.account,info.uid))
		end

	end
end

function dispatch_client(self,cid,message_id,data,size)
	local pto_name = protocol.name[message_id]
	local forward = common.PROTOCOL_FORWARD[pto_name]
	if forward then
		if forward == common.SERVER_TYPE.WORLD then
			server_manager:sendWorld("module.world_server","dispatch_client",{cid = cid,message_id = message_id,data = string.copy(data,size)})
		elseif forward == common.SERVER_TYPE.SCENE then
			local user = model.fetch_agent_user_with_cid(cid)
			if not user then
				event.error(string.format("forward scene error:no such user:%d",cid))
				return
			end

			server_manager:sendScene(user.scene_server_id,"module.scene_server","dispatch_client",{cid = cid,message_id = message_id,data = string.copy(data,size)})
		end
		return
	end
	local user = model.fetch_agent_user_with_cid(cid)
	if not user then
		route.dispatch_client(cid,message_id,data,size)
	else
		route.dispatch_client(user,message_id,data,size)
	end
end


function enter(self,cid,addr)
	print(string.format("client enter:%d,%s",cid,addr))
end

function leave(self,cid)
	print(string.format("client leave:%d,%s",cid,addr))
	local enter_info = _enter_user[cid]
	_enter_user[cid] = nil
	if not enter_info then
		return
	end

	local user = model.fetch_agent_user_with_uid(enter_info.uid)
	if not user then
		return
	end
	user.cid = nil
	user.status = eUSER_STATUS.DEAD	
	if user.hookTime then
		return
	end
	event.fork(function ()
		enter_info.mutex(user_leave,self,user)
	end)
end

function userRegister(self,account,uid,token,time)
	_tokenMgr[token] = {time = time,uid = uid,account = account}
end

function userKick(self,uid)
	local user = model.fetch_agent_user_with_uid(uid)
	if not user then
		return false
	end

	local enter_info = _enter_user[user.cid]
	_enter_user[user.cid] = nil
	if not enter_info then
		return false
	end
	client_manager:close(user.cid)
	_enter_user.mutex(user_leave,user)
	return true
end

function user_auth(self,cid,token)
	if not _user_token[token] then
		client_manager:close(cid)
		return
	end

	local info = _user_token[token]
	_user_token[token] = nil

	local now = util.time()
	if now - info.time >= 60 * 100 then
		client_manager:close(cid)
		return
	end

	local token_info = util.authcode(token,info.time,0)
	token_info = cjson.decode(token_info)
	if token_info.uid ~= info.uid then
		client_manager:close(cid)
		return
	end

	local enter_info = {mutex = event.mutex(),uid = info.uid}
	_enter_user[cid] = enter_info

	enter_info.mutex(user_enter,self,cid,info.uid,info.account)
end

function user_enter(self,cid,uid,account)
	local agent_user = agent_user.cls_agent_user:new(cid,uid,account)
	agent_user:load()

	agent_user:enter_game()

	local msg = {user_id = agent_user.uid,agent_id = env.dist_id}
	server_manager:sendWorld("handler.world_handler","enter_world",msg)

	local msg = {user_uid = agent_user.uid,agent_id = env.dist_id,location_info = agent_user.location_info}
	server_manager:sendWorld("module.scene_manager","enter_scene",msg)
end

function user_leave(self,user)
	local ok,err = xpcall(user.leave_game,debug.traceback,user)
	if not ok then
		event.error(err)
	end

	local world_channel = model.get_world_channel()
	if world_channel then
		world_channel:send("handler.world_handler","leave_world",{user_uid = user.uid})
		world_channel:send("module.scene_manager","leave_scene",{uid = user.uid})
	end

	user:save()
	
	local db_channel = model.get_dbChannel()
	local updater = {}
	updater["$inc"] = {version = 1}
	updater["$set"] = {time = os.time()}
	db_channel:findAndModify("agent_user","save_version",{query = {uid = user.uid},update = updater,upsert = true})

	user:release()

	local login_channel = model.get_login_channel()

	login_channel:send("handler.login_handler","rpc_leave_agent",{account = user.account})
end

function get_all_enter_user(self)
	local result = {}
	for cid,info in pairs(_enter_user) do
		local user = model.fetch_agent_user_with_uid(info.uid)
		result[user.account] = {uid = user.uid,agent_server = env.dist_id}
	end
	for _,info in pairs(_user_token) do
		result[info.account] = {uid = info.uid,agent_server = env.dist_id}
	end
	return result
end

function connectSceneServer(self,scene_server,scene_addr)
	local all_scene_server = server_manager:findServer("scene")
	if all_scene_server[scene_server] then
		return true
	end

	local addr
	if scene_addr.file then
		addr = string.format("ipc://%s",scene_addr.file)
	else
		addr = string.format("tcp://%s:%d",scene_addr.ip,scene_addr.port)
	end

	local channel = server_manager:connectServerWithAddr("scene",addr,false,1)
	return channel ~= nil
end

function server_down(self,name,id)
	if name == "scene" then
		local all = model.fetch_agent_user()
		for _,user in pairs(all) do
			if user.scene_server == id then
				user:scene_down()
			end
		end
	end
end

function server_stop()
	_server_stop = true
	client_manager:stop()

	for cid,enter_info in pairs(_enter_user) do
		client_manager:close(cid)
		local user = model.fetch_agent_user_with_uid(enter_info.uid)
		if user then
			enter_info.mutex(user_leave,self,user)
		end
		_enter_user[cid] = nil
	end

	local db_channel = model.get_dbChannel()
	
	local updater = {}
	updater["$inc"] = {version = 1}
	updater["$set"] = {time = os.time()}
	db_channel:findAndModify("common","agent_version",{query = {uid = env.dist_id},update = updater,upsert = true})

	local world_channel = model.get_world_channel()
	world_channel:send("handler.world_handler","server_stop",{id = env.dist_id})
end

function scene_server_update()

end

function connect_scene_server()
	local result = server_manager:sendWorld("module.scene_manager","scene_server_info")
	local list = server_manager:findServer("scene")

	for _,info in pairs(result) do
		if not list[info.id] then

		end
	end
end
