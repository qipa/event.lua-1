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

function cBulletCtrl:setTargetObj(targetObj)
	self.followObj = targetObj
end

function cBulletCtrl:setTargetPos(pos)
	self.followPos = pos
end

function cBulletCtrl:onUpdate(now)
	local now = now or event.now()
	local interval = (now - self.lastTime) / 1000

	local pos = self.owner.pos

	local followPos
	if self.followPos then
		followPos = self.followPos
	else
		followPos = self.followObj.pos
	end

	local dir = {followPos[1] - pos[1],followPos[2] - pos[2]}
	local angle = dir2angle(dir)

	local dtMove = interval * self.owner.speed
	local dt = dtDot2Dot(pos[1],pos[2],followPos[1],followPos[2])

	local isOver = false
	if dtMove >= dt then
		dtMove = dt
		isOver = true
	end

	local nx,nz = moveForward(pos[1],pos[2],angle,dtMove)

	self.owner.pos[1] = nx
	self.owner.pos[2] = nz

	self.owner:doCollision(pos,self.owner.pos)
	
	return isOver
end

