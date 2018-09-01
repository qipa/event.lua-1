local event = require "event"
local model = require "model"
local timer = require "timer"
local scene = import "module.scene.scene"
local id_builder = import "module.id_builder"
import "handler.cmd_handler"

local kFLUSH_TIME = 30

_sceneCtx = _sceneCtx or {}
_sceneMap = _sceneMap or {}

function __init__(self)
	self.flushTimer = timer.callout(kFLUSH_TIME,self,"flush")
end

function flush()
	local all = model.fetch_fighter()
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
	_sceneMap[sceneUid] = scene	
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
	local fighter = class.instance_from("fighter",table.decode(userData))
	fighter:create(fighter.uid,fighter.pos[1],fighter.pos[2])
	model.bind_fighter_with_uid(fighter.uid,fighter)

	local scene = self:getScene(sceneUid)
	assert(scene ~= nil,sceneUid)
	scene:enter(fighter,pos)
end

function leaveScene(self,userUid,switch)
	local fighter = model.fetch_fighter_with_uid(userUid)
	model.unbind_fighter_with_uid(fighter)

	local scene = self:getScene(fighter.sceneUid)
	scene:leave(fighter)
	sceneUser:save()
	
	local dbChannel = model.get_db_channel()
	local updater = {}
	updater["$inc"] = {version = 1}
	updater["$set"] = {time = os.time()}
	dbChannel:findAndModify("scene_user","save_version",{query = {uid = sceneUid.uid},update = updater,upsert = true})

	local fighterData 
	if switch then
		fighterData = fighter:pack()
	end

	fighter:release()

	return fighterData 
end

function transferInside(self,userUid,sceneUid,pos)
	local fighter = model.fetch_fighter_with_uid(userUid)

	local scene = self:getScene(fighter.sceneUid)
	scene:leave(fighter)

	local scene = self:getScene(sceneUid)
	scene:enter(fighter,pos)
end
