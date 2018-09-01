local aoi_core = require "simpleaoi.core"
local sceneConst = import "module.scene.scene_const"
local database_collection = import "module.database_collection"

cSceneObj = database_collection.cls_collection:inherit("sceneobj")

function __init__(self)
	self.cSceneObj:pack_field("uid")
	self.cSceneObj:pack_field("pos")
end

function cSceneObj:create(uid,x,z,face)
	print("cSceneObj:create")
	self.uid = uid
	self.pos = {x,z}
	self.face = face
	self.hp = hp
	self.maxHp = hp
	self.witnessCtx = {}
	self.viewerCtx = {}
end

function cSceneObj:destroy()

end

function cSceneObj:sceneObjType()
	assert(false)
end

function cSceneObj:getSeeInfo()


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
	self.pos[1] = x
	self.pos[2] = z
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
	local sceneInst = self.scene

	for aoiTriggerId in pairs(self.viewerCtx) do
		local sceneObjUid = sceneInst.viewerCtx[aoiTriggerId]
		local sceneObj = sceneInst.objMgr[sceneObjUid]
		table.insert(result,sceneObj)
	end

	return result
end

function cSceneObj:getWitness()

	local result = {}
	local sceneInst = self.scene

	for aoiEntityId in pairs(self.witnessCtx) do
		local sceneObjUid = sceneInst.witnessCtx[aoiEntityId]
		local sceneObj = sceneInst.objMgr[sceneObjUid]
		table.insert(result,sceneObj)
	end

	return result
end

function cSceneObj:getWitnessCid()
	local result = {}
	local sceneInst = self.scene

	for aoiEntityId in pairs(self.witnessCtx) do
		local sceneObjUid = sceneInst.witnessCtx[aoiEntityId]
		local sceneObj = sceneInst.objMgr[sceneObjUid]
		if sceneObj:sceneObjType() == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
			table.insert(result,sceneObj.cid)
		end
	end

	return result
end

function cSceneObj:getSceneObjInLine()

end

function cSceneObj:getSceneObjInRectangle()

end

function cSceneObj:getSceneObjInCircle()

end

function cSceneObj:getSceneObjInSector()

end

