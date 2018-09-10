local event = require "event"
local model = require "model"

local serverMgr = import "module.server_manager"
local scene_manager = import "module.scene_manager"
local dbObject = import "module.database_object"
local worldUser = import "module.world.world_user"
import "handler.world_handler"

model.registerValue("dbCommon")

local eUSER_PHASE = {
	LOADING = 1,
	DONE = 2,
	LEAVE = 3
}

function __init__(self)
	local dbCommon = dbObject.cDatabaseCommon:new(30)
	model.set_dbCommon(dbCommon)
	serverMgr:registerEvent("SERVER_DOWN",self,"onServerDown")
end

function start(self)
	import "module.scene_manager"
	import "handler.cmd_handler"
end


function dispatch_client(self,args)
	local user = model.fetch_world_user_with_cid(args.cid)
	if not user then
		route.dispatch_client(args.cid,args.message_id,args.data)
	else
		route.dispatch_client(user,args.message_id,args.data)
	end
end

function onServerDown(self,name,serverId)
	if name == "agent" then
		local all = model.fetch_world_user()
		for _,user in pairs(all) do
			if user.agentId == serverId then
				self:leave(user.userUid)
			end
		end
	elseif name == "scene" then

	end
end

function enter(self,userUid,agentId)
	local user = model.fetch_world_user_with_uid(userUid)
	if user and user.phase == eUSER_PHASE.DONE then
		user:override(agentId)
	else
		user = worldUser.cWorldUser:new()
		model.bind_world_user_with_uid(userUid,user)
		user.phase = eUSER_PHASE.LOADING
		user:load()
		user:onCreate(userUid,agentId)
		if user.phase == eUSER_PHASE.LEAVE then
			user:release()
			model.unbind_world_user_with_uid(userUid)
			return
		end
		user.phase = eUSER_PHASE.DONE
		user:enter()
	end
end

function leave(self,userUid)
	local user = model.fetch_world_user_with_uid(userUid)
	if not user then
		return false
	end
	
	if user.phase == eUSER_PHASE.LOADING then
		user.phase = eUSER_PHASE.LEAVE
		return
	end

	user:leave()
	user:save()
	user:release()
	model.unbind_world_user_with_uid(userUid)
	return true
end

function serverStop(self)
	local dbCommon = model.get_dbCommon()
	dbCommon:save()
end
