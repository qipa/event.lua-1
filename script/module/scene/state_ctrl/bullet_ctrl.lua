local util = require "util"
local event = require "event"
local object = import "module.object"

cBulletCtrl = object.cObject:inherit("bulletCtrl")

local dtDot2Dot = util.dot2dot
local moveTorward = util.move_torward

function cBulletCtrl:ctor(sceneObj)
	self.owner = sceneObj
	self.lastTime = event.now()
end

function cBulletCtrl:onCreate()
end

function cBulletCtrl:onDestroy()

end

function cBulletCtrl:onUpdate(now)
	local now = now or event.now()
	local interval = (now - self.lastTime) / 1000

	local pos = self.owner.pos

	local endPos = self.owner:getEndPos()

	local dir = {endPos[1] - pos[1],endPos[2] - pos[2]}
	local angle = dir2angle(dir)

	local dtMove = interval * self.owner.speed
	local dt = dtDot2Dot(pos[1],pos[2],endPos[1],endPos[2])

	local isFlyOver = false
	if dtMove >= dt then
		dtMove = dt
		isFlyOver = true
	end

	local nx,nz = moveForward(pos[1],pos[2],angle,dtMove)

	self.owner.pos[1] = nx
	self.owner.pos[2] = nz

	local isOver = self.owner:doCollision(pos,self.owner.pos)
	if isFlyOver or isOver then
		self.owner:release()
	end
	
	return isFlyOver or isOver
end

