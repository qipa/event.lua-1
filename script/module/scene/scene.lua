local aoiCore = require "toweraoi.core"
local navCore= require "nav.core"
local cjson = require "cjson"
local timer = require "timer"
local object = import "module.object"
local sceneConst = import "module.scene.scene_const"

cScene = object.cls_base:inherit("scene")

local kUPDATE_INTERVAL = 0.1
local kCOMMON_UPDATE_INTERVAL = 1

function cScene:create(sceneId,sceneUid)
	self.sceneId = sceneId
	self.sceneUid = sceneUid

	self.objMgr = {}
	self.objTypeMgr = {}
	
	self.aoi = aoiCore.create(self.sceneId,1000,1000,4)

	local FILE = assert(io.open(string.format("./config/%d.mesh",sceneId),"r"))
	local meshInfo = FILE:read("*a")
	FILE:close()

	local FILE = assert(io.open(string.format("./config/%d.tile",sceneId),"r"))
	local tileInfo = FILE:read("*a")
	FILE:close()

	local nav = navCore.create(sceneId,cjson.decode(meshInfo))
	nav:load_tile(cjson.decode(tileInfo))

	self.nav = nav
	
	timer.callout(kUPDATE_INTERVAL,self,"update")
	timer.callout(kCOMMON_UPDATE_INTERVAL,self,"commonUpdate")
end

function cScene:destroy()
	timer.removeAll(self)
	self:cleanSceneObj()
end

function cScene:cleanSceneObj()
	for _,sceneObj in pairs(self.objMgr) do
		sceneObj:release()
	end 
end

function cScene:getObj(uid)
	return self.objMgr[uid]
end

function cScene:getAllObjByType(sceneObjType)
	local typeMgr = self.objTypeMgr[sceneObjType]
	return typeMgr
end

function cScene:enter(sceneObj,pos)
	self.objMgr[sceneObj.uid] = sceneObj
	
	local objType = sceneObj:sceneObjType()
	
	local typeMgr = self.objTypeMgr[objType]
	if not typeMgr then
		typeMgr = {}
		self.objTypeMgr[objType] = typeMgr
	end 
	typeMgr[sceneObj.uid] = sceneObj


	if objType == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
		self:onUserEnter(sceneObj)
	else
		self:onObjEnter(sceneobj)
	end

	sceneObj:onEnterScene(self)

end

function cScene:leave(sceneObj)
	self.objMgr[sceneObj.uid] = nil

	local objType = sceneObj:sceneObjType()
	local typeMgr = self.objTypeMgr[objType]
	typeMgr[sceneObj.uid] = nil

	if sceneObj:sceneObjType() == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
		self:onUserLeave(sceneObj)
	else
		self:onObjLeave(sceneobj)
	end
	
	sceneObj:onLeaveScene(self)

end

function cScene:onUserEnter(user)

end

function cScene:onUserLeave(user)

end

function cScene:onObjEnter(obj)

end

function cScene:onObjLeave(obj)

end

function cScene:findPath(fromX,fromZ,toX,toZ)
	return self.nav:find(fromX,fromZ,toX,toZ)
end

function cScene:raycast(fromX,fromZ,toX,toZ)
	return self.nav:raycast(fromX,fromZ,toX,toZ)
end

function cScene:posMovable(x,z)
	return self.nav:movable(x,z)
end

function cScene:posAroundMovable(x,z,depth)
	return self.nav:around_movable(x,z,depth)
end

function cScene:createAoiEntity(sceneObj)
	local entityId,aoiSet = self.aoi:create_entity(sceneObj.uid,sceneObj.pos[1],sceneObj.pos[2])

	for _,otherUid in pairs(aoiSet) do
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
		sceneObj.witnessCtx[otherUid] = true
	end

	return entityId
end

function cScene:removeAoiEntity(sceneObj)
	local aoiSet = self.aoi:remove_entity(sceneObj.entityId)

	for _,otherUid in pairs(aoiSet) do
		local other = self.objMgr[otherUid]
		other:onObjLeave({sceneObj})
		sceneObj.witnessCtx[otherUid] = nil
	end
end

function cScene:moveAoiEntity(sceneObj,x,z)
	local enterSet,LeaveSet = self.aoi:move_entity(sceneObj.entityId,x,z)

	for _,otherUid in pairs(enterSet) do
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
		sceneObj.witnessCtx[otherUid] = true
	end

	for _,otherUid in pairs(LeaveSet) do
		local other = self.objMgr[otherUid]
		other:onObjLeave({sceneObj})
		sceneObj.witnessCtx[otherUid] = nil
	end

end

function cScene:createAoiTrigger(sceneObj)
	local triggerId,aoiSet = self.aoi:create_trigger(sceneObj.uid,sceneObj.pos[1],sceneObj.pos[2],3)

	local enterList = {}
	for _,otherUid in pairs(aoiSet) do
		local other = self.objMgr[otherUid]
		table.insert(enterList,other)
		sceneObj.viewerCtx[otherUid] = true
	end

	sceneObj:onObjEnter({enterList})

	return triggerId
end

function cScene:removeAoiTrigger(sceneObj)
	self.aoi:remove_trigger(sceneObj.triggerId)
end

function cScene:moveAoiTrigger(sceneObj,x,z)
	local enterSet,LeaveSet = self.aoi:move_trigger(sceneObj.triggerId,x,z)

	local list = {}
	for _,otherUid in pairs(enterSet) do
		local other = self.objMgr[otherUid]
		table.insert(list,other)
		sceneObj.viewerCtx[otherUid] = true
	end

	sceneObj:onObjEnter(list)

	local list = {}
	for _,otherUid in pairs(LeaveSet) do
		local other = self.objMgr[otherUid]
		table.insert(list,other)
		sceneObj.viewerCtx[otherUid] = nil
	end

	sceneObj:onObjLeave(list)
end

function cScene:update(now)
	for _,sceneObj in pairs(self.objMgr) do
		sceneObj:onUpdate()
	end
end

function cScene:commonUpdate(now)
	for _,sceneObj in pairs(self.objMgr) do
		sceneObj:onCommonUpdate()
	end
end
