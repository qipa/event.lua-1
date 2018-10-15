local util = require "util"
local event = require "event"
local object = import "module.object"

cMoveCtrl = object.cObject:inherit("moveCtrl")

local dtDot2Dot = util.dot2dot
local moveForward = util.move_forward

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

	local location = self.owner.pos
	local dt = dtDot2Dot(pos[1],pos[2],location[1],location[2])
	if dt <= 0.1 then
		self.owner:move(pos[1],pos[2])
	else
		protocol.writer.sObjFixPos(self.owner.cid,location)
	end

	local witness = self.owner:getWitnessCid()
	protocol.writer.sObjMoveStop(witness,location)
end

function cMoveCtrl:onServerMoveStart(path)
	return self:prepareMove(path)
end

function cMoveCtrl:prepareMove(path)
	local stateMgr = self.owner.stateMgr

	if stateMgr:hasState("MOVE") then
		self:doMove()
		stateMgr:delState("MOVE")
	end

	self.pathIndex = 1
	self.pathIndexMax = #path
	self.pathList = path
	
	self.lastTime = event.now()

	stateMgr:addState("MOVE")

	local witness = self.owner:getWitnessCid()

	-- protocol.writer.sObjMove(witness,self.pathList)
end

function cMoveCtrl:doMove(now)
	
	local now = now or event.now()

	local interval = (now - self.lastTime) / 1000

	local pathIndex = self.pathIndex
	local pathIndexMax = self.pathIndexMax
	local pathList = self.pathList

	local dtMove = self.owner.speed * interval
	
	local pathNode = pathList[pathIndex]

	local location = self.owner.pos
	local dtNext = dtDot2Dot(location[1],location[2],pathNode[1],pathNode[2])

	while dtMove - dtNext >= 0.1 do
		dtMove = dtMove - dtNext
		
		self.owner:move(pathNode[1],pathNode[2])

		pathIndex = pathIndex + 1
		if pathIndex > pathIndexMax then
			break
		end
		location = self.owner.pos
		pathNode = pathList[pathIndex]
		dtNext = dtDot2Dot(location[1],location[2],pathNode[1],pathNode[2])
	end

	self.pathIndex = pathIndex

	self.lastTime = now

	if pathIndex > pathIndexMax then
		return true
	end

	local nx,nz = moveForward(location[1],location[2],pathNode[1],pathNode[2],dtMove)
	self.owner:move(nx,nz)
	return false
end
