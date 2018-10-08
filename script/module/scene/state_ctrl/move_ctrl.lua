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
	return self:updatePos(now)
end

function cMoveCtrl:onClientMoveStart(path)
	local stateMgr = self.owner.stateMgr

	if not stateMgr:canAddState("MOVE") then
		return false
	end

	if stateMgr:hasState("MOVE") then
		self:updatePos()
	end


	self.pathList = path
	self.pathIndex = 1
	self.pathIndexMax = #path
	self.lastTime = event.now()

	stateMgr:addState("MOVE")
end

function cMoveCtrl:onClientMoveStop(pos,angle)

end

function cMoveCtrl:onServerMoveStart(path)
	self.pathIndex = 1
	self.pathList = path
	self.lastTime = event.now()
end

function cMoveCtrl:updatePos(now)
	local now = now or event.now()

	local interval = now - self.lastTime

	local pathIndex = self.pathIndex
	local pathIndexMax = self.pathIndexMax
	local pathList = self.pathList

	local dtMove = self.owner.speed * interval
	
	local pathNode = pathList[pathIndex]
	local ownerPos = self.owner.pos
	local dtNext = util.distance(ownerPos[1],ownerPos[2],pathNode[1],pathNode[2])

	while dtMove - dtNext >= 0.1 do
		dtMove = dtMove - dtNext
		
		self.owner:setPos(pathNode[1],pathNode[2])

		pathIndex = pathIndex + 1
		if pathIndex > pathIndexMax then
			break
		end
		ownerPos = self.owner.pos
		pathNode = pathList[pathIndex]
		dtNext = util.distance(ownerPos[1],ownerPos[2],pathNode[1],pathNode[2])
	end

	self.pathIndex = pathIndex

	self.lastTime = now

	if pathIndex > pathIndexMax then
		return true
	else
		ownerPos = util.move_forward(ownerPos[1],ownerPos[2],pathNode[1],pathNode[2],dtMove)
		self.owner:setPos(ownerPos[1],ownerPos[2])
	end

	return false
end
