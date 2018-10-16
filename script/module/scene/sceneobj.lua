local util = require "util"
local sceneConst = import "module.scene.scene_const"
local dbObject = import "module.database_object"

local angle2dir = util.angle2dir
local dir2angle = util.dir2angle
local mathAbs = math.abs

local segmentIntersect = util.segment_intersect
local rectangleIntersect = util.rectangle_intersect
local sectorIntersect = util.sector_intersect
local capsuleIntersect = util.capsule_intersect

cSceneObj = dbObject.cCollection:inherit("sceneobj")

function __init__(self)
	self.cSceneObj:packField("uid")
	self.cSceneObj:packField("pos")
end

function cSceneObj:onCreate(uid,x,z,face,aoiRange)
	print("cSceneObj:create",uid)
	self.uid = uid
	self.aoiRange = aoiRange
	self.pos = {x,z}
	self.face = {0,0} or face
	self.angle = 0
	self.speed = 10
	self.isDead = false
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
	if self.scene == scene then
		self:goto(x,z)
		return
	end
	scene:enter(self,{x,z})
end

function cSceneObj:leaveScene()
	assert(self.scene ~= nil)
	self.scene:leave(self)
end

function cSceneObj:onEnterScene(scene)
	self.aoiEntityId = scene:createAoiEntity(self)
	if self.aoiRange then
		self.aoiTriggerId = scene:createAoiTrigger(self)
	end

	self.scene = scene
end

function cSceneObj:onLeaveScene(scene)
	scene:removeEntity(self)
	self.aoiEntityId = nil

	if self.aoiTriggerId then
		scene:removeTrigger(self)
		self.aoiTriggerId = nil
	end

	self.scene = nil
end

function cSceneObj:move(x,z)
	if not self.scene then
		return false
	end

	local x,z = self.scene:posAroundMovable(x,z,2)

	local ox = self.pos[1]
	local oz = self.pos[2]

	local dx = x - ox
	local dz = z - oz

	if mathAbs(dx) <= 0.1 and mathAbs(dz) <= 0.1 then
		return false
	end

	self.scene:moveAoiEntity(self,x,z)
	if self.aoiTriggerId then
		self.scene:moveAoiTrigger(self,x,z)
	end

	self.pos[1] = x
	self.pos[2] = z
	
	self.face[1] = dx
	self.face[2] = dz

	self.angle = dir2angle(self.face)
end

function cSceneObj:goto(x,z)
	self:move(x,z)

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

function cSceneObj:getWitnessCid(filterFunc,...)
	local result = {}
	local objMgr = self.scene.objMgr

	local fighterType = sceneConst.eSCENEOBJ_TYPE.FIGHTER

	for sceneObjUid in pairs(self.witnessCtx) do
		local sceneObj = objMgr[sceneObjUid]
		if sceneObj:sceneObjType() == fighterType then
			if filterFunc and filterFunc(...,sceneObj) then
				table.insert(result,sceneObj.cid)
			else
				table.insert(result,sceneObj.cid)
			end
		end
	end

	return result
end

function cSceneObj:getObjInLine(from,to,cmpFunc,...)
	local from = from or self.pos

	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if segmentIntersect(from[1],from[2],to[1],to[2],obj.pos[1],obj.pos[2],obj.range) then
			if cmpFunc and cmpFunc(...,obj) then
				table.insert(result,obj)
			else
				table.insert(result,obj)
			end
		end
	end

	return result
end

function cSceneObj:getObjInRectangle(pos,dir,length,width,cmpFunc,...)
	local angle = dir2angle(dir[1],dir[2])

	local pos = pos or self.pos

	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if rectangleIntersect(pos[1],pos[2],length,width,angle,obj.pos[1],obj.pos[2],obj.range) then
			if cmpFunc and cmpFunc(...,obj) then
				table.insert(result,obj)
			else
				table.insert(result,obj)
			end
		end
	end

	return result
end

function cSceneObj:getObjInCircle(pos,range,cmpFunc,...)
	local pos = pos or self.pos

	local result = {}
	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		local totalRange = range + obj.range
		if util.sqrt_distance(pos[1],pos[2],obj.pos[1],obj.pos[2]) <= totalRange * totalRange then
			if cmpFunc and cmpFunc(...,obj) then
				table.insert(result,obj)
			else
				table.insert(result,obj)
			end
		end
	end

	return result
end

function cSceneObj:getObjInSector(pos,dir,degree,range,cmpFunc,...)
	local angle = dir2angle(dir[1],dir[2])

	local pos = pos or self.pos

	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if sectorIntersect(pos[1],pos[2],angle,degree,range,obj.pos[1],obj.pos[2],obj.range) then
			if cmpFunc and cmpFunc(...,obj) then
				table.insert(result,obj)
			else
				table.insert(result,obj)
			end
		end
	end

	return result
end

function cSceneObj:getObjInCapsule(from,to,r,cmpFunc,...)
	local from = from or self.pos
	local result = {}

	local allObjs = self:getViewer()
	for _,obj in pairs(allObjs) do
		if capsuleIntersect(from[1],from[2],to[1],to[2],r,obj.pos[1],obj.pos[2],obj.range) then
			if cmpFunc and cmpFunc(...,obj) then
				table.insert(result,obj)
			else
				table.insert(result,obj)
			end
		end
	end

	return result
end