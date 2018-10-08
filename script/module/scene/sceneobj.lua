local aoi_core = require "simpleaoi.core"
local sceneConst = import "module.scene.scene_const"
local dbObject = import "module.database_object"

cSceneObj = dbObject.cCollection:inherit("sceneobj")

function __init__(self)
	self.cSceneObj:packField("uid")
	self.cSceneObj:packField("pos")
end

function cSceneObj:onCreate(uid,x,z,face)
	print("cSceneObj:create")
	self.uid = uid
	self.pos = {x,z}
	self.face = face
	self.hp = hp
	self.maxHp = hp
	self.witnessCtx = {}
	self.viewerCtx = {}
end

function cSceneObj:onDestroy()

end

function cSceneObj:sceneObjType()
	assert(false)
end

function cSceneObj:getSeeInfo()
	return {}
end

function cSceneObj:enterScene(scene,x,z)
	self.pox[1] = x
	self.pox[2] = z
	scene:enter(self,x,z)
end

function cSceneObj:leaveScene()
	assert(self.scene ~= nil)
	self.scene:leave(self)
end

function cSceneObj:onEnterScene(scene)
	self.aoiEntityId = scene:createAoiEntity(self)
	self.scene = scene
end

function cSceneObj:onLeaveScene(scene)
	scene:removeEntity(self)
	self.aoiEntityId = nil
	self.scene = nil
end

function cSceneObj:move(x,z)
	self.scene:moveAoiEntity(self,x,z)

	local oPos = self.pos
	self.pos = {x,z}
	self.face = (self.pos[2] - oPos[2]) / (self.pos[1] - oPos[1])
end

function cSceneObj:onObjEnter(sceneObjList)

end

function cSceneObj:onObjLeave(sceneObjList)

end

function cSceneObj:onUpdate(now)
	print("cSceneObj:onUpdate")
end

function cSceneObj:onCommonUpdate(now)

end

function cSceneObj:getViewer(range)
	local result = {}
	local objMgr = self.scene.objMgr

	for sceneObjUid in pairs(self.viewerCtx) do
		local sceneObj = objMgr[sceneObjUid]
		table.insert(result,sceneObj)
	end

	return result
end

function cSceneObj:getWitness()

	local result = {}
	local sceneInst = self.scene

	for sceneObjUid in pairs(self.witnessCtx) do
		local sceneObj = sceneInst.objMgr[sceneObjUid]
		table.insert(result,sceneObj)
	end

	return result
end

function cSceneObj:getWitnessCid()
	local result = {}
	local sceneInst = self.scene

	for sceneObjUid in pairs(self.witnessCtx) do
		local sceneObj = sceneInst.objMgr[sceneObjUid]
		if sceneObj:sceneObjType() == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
			table.insert(result,sceneObj.cid)
		end
	end

	return result
end

function cSceneObj:getSceneObjInLine(range,findType)

end

function cSceneObj:getSceneObjInRectangle(range,findType)

end

function cSceneObj:getSceneObjInCircle(range,findType)
	local result = {}
	local allObjs = self:getWitness()
	for _,obj in pairs(allObjs) do

	end
end

function cSceneObj:getSceneObjInSector(range,findType)

end

