local event = require "event"
local model = require "model"

local server_manager = import "module.server_manager"
local scene_manager = import "module.scene_manager"
local dbObject = import "module.database_object"
local worldUser = import "module.worldUser"
import "handler.world_handler"

_agent_server_status = _agent_server_status or {}

function __init__(self)
	self.timer = event.timer(30,function ()
		local all = model.fetch_world_user()
		for _,user in pairs(all) do
			user:save()
		end
	end)

	self.db_common = dbObject.cDatabaseCommon:new(30)

	server_manager:registerEvent("SERVER_DOWN",self,"server_down")
end

function start(self)
	import "module.scene_manager"
	import "handler.cmd_handler"
	local db_channel = model.get_db_channel()
	local guild_info = db_channel:findAll("common","guild")
	for _,info in pairs(guild_info) do

	end
end

function flush(self)
	self.db_common:flush()
	local all = model.fetch_world_user()
	for _,user in pairs(all) do
		user:save()
	end
end

function dispatch_client(self,args)
	local user = model.fetch_world_user_with_cid(args.cid)
	if not user then
		route.dispatch_client(args.cid,args.message_id,args.data)
	else
		route.dispatch_client(user,args.message_id,args.data)
	end
end

function agent_down(self,listener,server_id)
	local all = model.fetch_world_user()
	for _,user in pairs(all) do
		if user.agent_id == server_id then
			self:leave(user.uid)
		end
	end
end

function scene_down(self,listener,server_id)
	local all = model.fetch_world_user()
	for _,user in pairs(all) do
		if user.scene_server == server_id then
			user.scene_server = nil
			user.scene_id = nil
			user.scene_uid = nil
			user.scene_channel = nil
		end
	end
end

function server_down(self,name,srv_id)

end

function enter(self,userUid,agentId)
	local user = model.fetch_world_user_with_uid(userUid)
	if user then
		user:override(agentId)
	else
		user = worldUser.cWorldUser:new(userUid,agentId)
		user:load()
		user:enter()
	end
end

function leave(self,userUid)
	local user = model.fetch_world_user_with_uid(userUid)
	if not user then
		return false
	end
	
	if user.loading then
		user:release()
		return
	end

	user:leave()
	user:save()
	user:release()
	return true
end

function server_stop(self,agent_id)
	_agent_server_status[agent_id] = true
	local agent_set = server_manager:how_many_agent()

	local all_agent_done = true
	for _,id in pairs(agent_set) do
		if not _agent_server_status[id] then
			all_agent_done = false
			break
		end
	end

	if all_agent_done then
		local db_channel = model.get_db_channel()

		local updater = {}
		updater["$inc"] = {version = 1}
		updater["$set"] = {time = os.time()}
		db_channel:findAndModify("common","world_version",{query = {uid = env.dist_id},update = updater,upsert = true})

		event.fork(function ()
			while scene_manager:all_user_leave() == false do
				event.error(string.format("waiting for all scene user leave"))
				event.sleep(1)
			end
			event.breakout()
		end)
	end
	return all_agent_done
end
