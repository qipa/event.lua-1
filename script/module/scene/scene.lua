local toweraoi = require "toweraoi.core"
local nav_core = require "nav.core"
local cjson = require "cjson"
local object = import "module.object"

cScene = object.cls_base:inherit("scene")

function cScene:create(sceneId,sceneUid)
	self.sceneId = sceneId
	self.sceneUid = sceneUid

	self.objMgr = {}

	self.aoi = aoi_core.new(self.sceneId,1000,1000,4)
	self.aoiEntityMgr = {}
	self.aoiTriggerMgr = {}

	local FILE = io.open(string.format("./config/%d.mesh",scene_id),"r")
	local mesh_info = FILE:read("*a")
	FILE:close()

	local FILE = io.open(string.format("./config/%d.tile",scene_id),"r")
	local tile_info = FILE:read("*a")
	FILE:close()

	local nav = nav_core.create(scene_id,cjson.decode(mesh_info))
	nav:load_tile(cjson.decode(tile_info))

	self.nav = nav
end

function cScene:enter(sceneObj,pos)
	
	local aoiId,aoiSet = self.aoi:create_entity(sceneObj.uid,pos[1],pos[2])
	self.aoiMgr[aoiId] = sceneObj.uid

	for _,otherAoiId in pairs(aoiSet) do
		local otherUid = self.aoiMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
	end

	sceneObj:onEnterScene(self)

	self.objMgr[sceneObj.uid] = sceneObj
end

function cScene:leave(fighter)
	fighter:do_leave()
	local set = self.aoi:leave(fighter.aoi_id)
	for _,aoi_id in pairs(set) do
		local uid = self.aoi_ctx[aoi_id]
		local other = self.objMgr[uid]
		other:object_leave({fighter})
	end

	self.objMgr[fighter.uid] = nil
end

function cScene:findPath(from_x,from_z,to_x,to_z)
	return self.nav:find(from_x,from_z,to_x,to_z)
end

function cScene:raycast(from_x,from_z,to_x,to_z)
	return self.nav:raycast(from_x,from_z,to_x,to_z)
end

function cScene:posMovable(x,z)
	return self.nav:movable(x,z)
end

function cScene:posAroundMovable(x,z,depth)
	return self.nav:around_movable(x,z,depth)
end

function cScene:createAoiEntity(sceneObj)
	local entityId,aoiSet = self.aoi:create_entity(sceneObj.uid,sceneObj.pos[1],sceneObj.pos[2])

	for _,otherAoiId in pairs(aoiSet) do
		local otherUid = self.aoiTriggerMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
		sceneObj.witnessCtx[otherUid] = true
	end

	self.aoiEntityMgr[entityId] = sceneObj.uid

	return entityId
end

function cScene:removeAoiEntity(sceneObj)
	local aoiSet = self.aoi:remove_entity(sceneObj.entityId)

	for _,otherAoiId in pairs(aoiSet) do
		local otherUid = self.aoiTriggerMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		other:onObjLeave({sceneObj})
		sceneObj.witnessCtx[otherUid] = nil
	end

	self.aoiEntityMgr[sceneObj.entityId] = nil
end

function cScene:moveAoiEntity(sceneObj,x,z)
	local enterSet,LeaveSet = self.aoi:move_entity(sceneObj.entityId,x,z)

	for _,otherAoiId in pairs(enterSet) do
		local otherUid = self.aoiTriggerMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
		sceneObj.witnessCtx[otherUid] = true
	end

	for _,otherAoiId in pairs(LeaveSet) do
		local otherUid = self.aoiTriggerMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		other:onObjLeave({sceneObj})
		sceneObj.witnessCtx[otherUid] = nil
	end

end

function cScene:createAoiTrigger(sceneObj)
	local triggerId,aoiSet = self.aoi:create_trigger(sceneObj.uid,sceneObj.pos[1],sceneObj.pos[2],3)

	local enterList = {}
	for _,otherAoiId in pairs(aoiSet) do
		local otherUid = self.aoiEntityMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		table.insert(enterList,other)
		sceneObj.viewerCtx[otherUid] = true
	end

	sceneObj:onObjEnter({enterList})

	self.aoiTriggerMgr[triggerId] = sceneObj.uid

	return triggerId
end

function cScene:removeAoiTrigger(sceneObj)
	self.aoi:remove_trigger(sceneObj.triggerId)
	self.aoiTriggerMgr[sceneObj.triggerId] = nil
end

function cScene:moveAoiTrigger(sceneObj,x,z)
	local enterSet,LeaveSet = self.aoi:move_entity(sceneObj.triggerId,x,z)

	local list = {}
	for _,otherAoiId in pairs(enterSet) do
		local otherUid = self.aoiEntityMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		table.insert(list,other)
		sceneObj.viewerCtx[otherUid] = true
	end

	sceneObj:onObjEnter(list)

	local list = {}
	for _,otherAoiId in pairs(LeaveSet) do
		local otherUid = self.aoiEntityMgr[otherAoiId]
		local other = self.objMgr[otherUid]
		table.insert(list,other)
		sceneObj.viewerCtx[otherUid] = nil
	end

	sceneObj:onObjLeave(list)
end

function cScene:update(now)
	for _,fighter in pairs(self.objMgr) do
		fighter:update()
	end

end