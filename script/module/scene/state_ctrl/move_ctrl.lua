local util = require "util"
local event = require "event"
local vector2 = require "common.vector2"
local object = import "module.object"

cMoveCtrl = object.cObject:inherit("moveCtrl")


function cMoveCtrl:ctor(sceneObj)
	self.owner = sceneObj
end

function cMoveCtrl:onCreate()
end

function cMoveCtrl:onDestroy()

end

function cMoveCtrl:onUpdate(now)
	return self:doMove(now)
end

function cMoveCtrl:onClientMoveStart(path)
	local stateMgr = self.owner.stateMgr

	if not stateMgr:canAddState("MOVE") then
		return false
	end
	return self:prepareMove(path)
end

function cMoveCtrl:onClientMoveStop(pos,angle)
	local stateMgr = self.owner.stateMgr
	if stateMgr:hasState("MOVE") then
		self:doMove()
		stateMgr:delState("MOVE")
	end

	local ownerPos = self.owner.pos
	local dt = util.distance(pos[1],pos[2],ownerPos[1],ownerPos[2])
	if dt <= 5 then
		self.owner:setPos(pos[1],pos[2])
	else
		protocol.writer.sObjFixPos(self.owner.cid,ownerPos)
	end

	local witness = self.owner:getWitnessCid()
	protocol.writer.sObjMoveStop(witness,ownerPos)
end

function cMoveCtrl:onServerMoveStart(path)
	return self:prepareMove(path)
end

function cMoveCtrl:prepareMove(path)
	local stateMgr = self.owner.stateMgr

	if stateMgr:hasState("MOVE") then
		self:doMove()
	end

	self.pathIndex = 1
	self.pathIndexMax = #path
	self.pathList = path
	
	self.lastTime = event.now()

	stateMgr:addState("MOVE")

	local witness = self.owner:getWitnessCid()

	protocol.writer.sObjMove(witness,self.pathList)
end

function cMoveCtrl:doMove(now)
	local now = now or event.now()

	local interval = now - self.lastTime

	local pathIndex = self.pathIndex
	local pathIndexMax = self.pathIndexMax
	local pathList = self.pathList

	local dtMove = self.owner.speed * interval
	
	local pathNode = pathList[pathIndex]
	local location = self.owner.pos
	local dtNext = util.distance(location[1],location[2],pathNode[1],pathNode[2])

	while dtMove - dtNext >= 0.1 do
		dtMove = dtMove - dtNext
		
		self.owner:setPos(pathNode[1],pathNode[2])

		pathIndex = pathIndex + 1
		if pathIndex > pathIndexMax then
			break
		end
		location = self.owner.pos
		pathNode = pathList[pathIndex]
		dtNext = util.distance(location[1],location[2],pathNode[1],pathNode[2])
	end

	self.pathIndex = pathIndex

	self.lastTime = now

	if pathIndex > pathIndexMax then
		return true
	else
		location = util.move_forward(location[1],location[2],pathNode[1],pathNode[2],dtMove)
		self.owner:setPos(location[1],location[2])
	end

	return false
end
