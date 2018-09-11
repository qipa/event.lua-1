local event = require "event"
local model = require "model"
local util = require "util"
local route = require "route"
local cjson = require "cjson"
local protocol = require "protocol"
local channel = require "channel"
local timer = require "timer"
local clientMgr = import "module.client_manager"
local serverMgr = import "module.server_manager"
local module_object = import "module.object"
local agentUser = import "module.agent.agent_user"
local common = import "common.common"

local kAUTH_TIME = 60

_tokenMgr = _tokenMgr or {}
_enterUserMgr = _enterUserMgr or {}
_server_stop = _server_stop or false

function __init__(self)
	serverMgr:registerEvent("SERVER_DOWN",self,"server_down")
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
			serverMgr:sendWorld("module.world_server","dispatch_client",{cid = cid,message_id = message_id,data = string.copy(data,size)})
		elseif forward == common.SERVER_TYPE.SCENE then
			local user = model.fetch_agent_user_with_cid(cid)
			if not user then
				event.error(string.format("forward scene error:no such user:%d",cid))
				return
			end

			serverMgr:sendScene(user.scene_server_id,"module.scene_server","dispatch_client",{cid = cid,message_id = message_id,data = string.copy(data,size)})
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
	local enterInfo = _enterUserMgr[cid]
	_enterUserMgr[cid] = nil
	if not enterInfo then
		return
	end

	local user = model.fetch_agent_user_with_uid(enterInfo.uid)
	if not user then
		return
	end
	user.cid = nil
	user.status = eUSER_STATUS.DEAD	
	if user.hookTime then
		return
	end
	event.fork(function ()
		enterInfo.mutex(userLeave,self,user)
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

	local enter_info = _enterUserMgr[user.cid]
	_enterUserMgr[user.cid] = nil
	if not enter_info then
		return false
	end
	clientMgr:close(user.cid)
	_enterUserMgr.mutex(user_leave,user)
	return true
end

function userAuth(self,cid,token)
	if not _tokenMgr[token] then
		clientMgr:close(cid)
		return
	end

	local tokenInfo = _tokenMgr[token]
	_tokenMgr[token] = nil

	local now = util.time()
	if now - tokenInfo.time >= 60 * 100 then
		clientMgr:close(cid)
		return
	end

	local enterInfo = {mutex = event.mutex(),uid = tokenInfo.uid}
	_enterUserMgr[cid] = enterInfo

	enterInfo.mutex(userEnter,self,cid,tokenInfo.uid,tokenInfo.account)
end

function userEnter(self,cid,uid,account)
	local user = agentUser.cAgentUser:new(cid,uid,account)
	user:onCreate(cid,uid,account)
	user:load()

	user:enterGame()

	local msg = {user_id = user.uid,agent_id = env.dist_id}
	serverMgr:sendWorld("handler.world_handler","enterWorld",msg)

	local msg = {user_uid = user.uid,agent_id = env.dist_id,location_info = user.location_info}
	serverMgr:sendWorld("module.world.scene_manager","enterScene",msg)
end

function userLeave(self,user)
	local ok,err = xpcall(user.leaveGame,debug.traceback,user)
	if not ok then
		event.error(err)
	end
	user:save()

	local dbChannel = model.get_dbChannel()
	local updater = {}
	updater["$inc"] = {version = 1}
	updater["$set"] = {time = os.time()}
	dbChannel:findAndModify("agentUser","saveVersion",{query = {uid = user.uid},update = updater,upsert = true})

	user:release()

	serverMgr:sendWorld("handler.world_handler","leaveWorld",{userUid = user.uid})
	serverMgr:sendWorld("module.world.scene_manager","leaveScene",{userUid = user.uid})
	serverMgr:sendLogin("handler.login_handler","leaveAgent",{account = user.account})
end

function get_all_enter_user(self)
	local result = {}
	for cid,info in pairs(_enterUserMgr) do
		local user = model.fetch_agent_user_with_uid(info.uid)
		result[user.account] = {uid = user.uid,agent_server = env.dist_id}
	end
	for _,info in pairs(_user_token) do
		result[info.account] = {uid = info.uid,agent_server = env.dist_id}
	end
	return result
end

function connectSceneServer(self,scene_server,scene_addr)
	local all_scene_server = serverMgr:findServer("scene")
	if all_scene_server[scene_server] then
		return true
	end

	local addr
	if scene_addr.file then
		addr = string.format("ipc://%s",scene_addr.file)
	else
		addr = string.format("tcp://%s:%d",scene_addr.ip,scene_addr.port)
	end

	local channel = serverMgr:connectServerWithAddr("scene",addr,false,1)
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
	clientMgr:stop()

	for cid,enter_info in pairs(_enterUserMgr) do
		clientMgr:close(cid)
		local user = model.fetch_agent_user_with_uid(enter_info.uid)
		if user then
			enter_info.mutex(user_leave,self,user)
		end
		_enterUserMgr[cid] = nil
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
	local result = serverMgr:sendWorld("module.scene_manager","scene_server_info")
	local list = serverMgr:findServer("scene")

	for _,info in pairs(result) do
		if not list[info.id] then

		end
	end
end
