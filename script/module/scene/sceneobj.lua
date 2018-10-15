
local util = require "util"
local sceneConst = import "module.scene.scene_const"
local dbObject = import "module.database_object"

cSceneObj = dbObject.cCollection:inherit("sceneobj")

local angle2dir = util.angle2dir
local dir2angle = util.dir2angle

function __init__(self)
	self.cSceneObj:packField("uid")
	self.cSceneObj:packField("pos")
end

function cSceneObj:onCreate(uid,x,z,face)
	print("cSceneObj:create",uid)
	self.uid = uid
	self.pos = {x,z}
	self.face = {0,0} or face
	self.speed = 10
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
	self.pos[1] = x
	self.pos[2] = z
	scene:enter(self,{x,z})
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

	local ox = self.pos[1]
	local oz = self.pos[2]

	self.pos[1] = x
	self.pos[2] = z
	
	self.face[1] = x - ox
	self.face[2] = z - oz
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

function cSceneObj:getViewer()
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

function cSceneObj:getObjInLine(from,to)
	local from = from or self.pos

	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if util.segment_intersect(from[1],from[2],to[1],to[2],obj.pos[1],obj.pos[2],obj.range) then
			table.insert(result,obj)
		end
	end

	return result
end

function cSceneObj:getObjInRectangle(pos,dir,length,width)
	local angle = dir2angle(dir[1],dir[2])

	print("getObjInRectangle",pos[1],pos[2],angle,length,width)
	local pos = pos or self.pos

	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if util.rectangle_intersect(pos[1],pos[2],length,width,angle,obj.pos[1],obj.pos[2],obj.range) then
			table.insert(result,obj)
		end
	end

	return result
end

function cSceneObj:getObjInCircle(pos,range)
	print("getObjInCircle",pos[1],pos[2],range)
	local pos = pos or self.pos

	local result = {}
	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		local totalRange = range + obj.range
		if util.sqrt_distance(pos[1],pos[2],obj.pos[1],obj.pos[2]) <= totalRange * totalRange then
			table.insert(result,obj)
		end
	end

	return result
end

function cSceneObj:getObjInSector(pos,dir,degree,range)
	local angle = dir2angle(dir[1],dir[2])
	print("getObjInSector",pos[1],pos[2],angle,degree,range)
	local pos = pos or self.pos

	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if util.sector_intersect(pos[1],pos[2],angle,degree,range,obj.pos[1],obj.pos[2],obj.range) then
			table.insert(result,obj)
		end
	end

	return result
end

function cSceneObj:getObjInCapsule(from,to,r)
	local from = from or self.pos
	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if util.capsule_intersect(from[1],from[2],to[1],to[2],r,obj.pos[1],obj.pos[2],obj.range) then
			table.insert(result,obj)
		end
	end

	return result
end