local event = require "event"
local model = require "model"

local scene = import "module.scene.scene"
local scene_user = import "module.scene_user"
local id_builder = import "module.id_builder"
import "handler.cmd_handler"


_sceneCtx = _sceneCtx or {}

_sceneMap = _sceneMap or {}

function __init__(self)
	self.timer = event.timer(0.1,function ()
		self:update()
	end)
	
	self.db_timer = event.timer(30,function ()
		local all = model.fetch_scene_user()
		for _,fighter in pairs(all) do
			fighter:save()
		end
	end)

end

function flush()
	local all = model.fetch_scene_user()
	for _,fighter in pairs(all) do
		fighter:save()
	end
end

function dispatch_client(_,args)
	local user = model.fetch_scene_user_with_cid(args.cid)

	if not user then
		route.dispatch_client(args.cid,args.message_id,args.data)
	else
		route.dispatch_client(user,args.message_id,args.data)
	end

end

function createScene(self,sceneId,sceneUid)
	local sceneInfo = _sceneCtx[sceneId]
	if not sceneInfo then
		sceneInfo = {}
		_sceneCtx[sceneId] = sceneInfo 
	end

	local scene = scene.cScene:new(sceneId,sceneUid)
	sceneInfo[sceneUid] = scene
	_sceneCtx[sceneUid] = scene	
end

function deleteScene(self,sceneUid)
	local scene = _sceneMap[sceneUid]
	scene:release()
	_sceneMap[sceneUid] = nil	

	local sceneInfo = _sceneCtx[scene.sceneId]
	sceneInfo[sceneUid] = nil
end

function getScene(self,sceneUid)
	return _sceneMap[sceneUid]	
end

function enterScene(self,userData,sceneUid,pos,switch)
	local sceneUser = class.instance_from("scene_user",table.decode(userData))
	sceneUser:init()
	if not switch then
		sceneUser:load()
	end

	model.bind_scene_user_with_uid(fighter.uid,fighter)

	local scene = self:getScene(sceneUid)
	assert(scene ~= nil,sceneUid)

	local fighter = fighter.cFighter:new(sceneUser.Uid,sceneUser.pos[1],sceneUid.pos[2])
	fighter.sceneUser = sceneUser
	scene:enter(fighter,pos)
end

function leaveScene(self,userUid,switch)
	local sceneUser = model.fetch_scene_user_with_uid(userUid)
	model.unbind_scene_user_with_uid(sceneUser)

	local fighter = sceneUid.fighter
	local scene = self:getScene(fighter.sceneUid)
	scene:leave(fighter)
	sceneUser:save()
	
	local dbChannel = model.get_db_channel()
	local updater = {}
	updater["$inc"] = {version = 1}
	updater["$set"] = {time = os.time()}
	dbChannel:findAndModify("scene_user","save_version",{query = {uid = sceneUid.uid},update = updater,upsert = true})

	local sceneUserData 
	if switch then
		sceneUserData = sceneUser:pack()
	end


	fighter:release()
	sceneUser:release()

	return sceneUserData 
end

function transferInside(self,userUid,sceneUid,pos)
	local sceneUser = model.fetch_scene_user_with_uid(userUid)

	local scene = self:getScene(sceneUser.fighter.sceneUid)
	scene:leave(sceneUser.fighter)

	local scene = self:getScene(sceneUid)
	scene:enter(sceneUser.fighter,pos)
end

function launch_transfer_scene(self,fighter,scene_id,scene_uid,x,z)
	local world_channel = model.get_world_channel()
	world_channel:send("module.scene_manager","transfer_scene",{scene_id = scene_id,scene_uid = scene_uid,pos = {x = x,z = z},fighter = fighter:pack()})
end

function update()
	for _,scene_info in pairs(_sceneCtx) do
		for _,scene in pairs(scene_info) do
			scene:update()
		end
	end
end
