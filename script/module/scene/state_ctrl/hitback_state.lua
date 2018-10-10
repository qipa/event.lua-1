local util = require "util"
local event = require "event"
local vector2 = require "common.vector2"
local stateBase = import "module.scene.state_ctrl.state_base"
local skillApi = import "module.scene.skill.skill_api"

cStateHitBack = stateBase.cStateBase:inherit("stateHitBack")

function cStateHitBack:ctor(sceneObj,hitBackInfo)
	local now = event.now()
	self.lastTime = now
	self.beginTime = event.now()
	self.endTime = hitBackInfo.endTime
	self.speed = hitBackInfo.speed
	self.angle = hitBackInfo.angle
	self.owner = sceneObj
end

function cStateHitBack:onCreate()
end

function cStateHitBack:onDestroy()
	
end

function cStateHitBack:onUpdate(now)

	local now = event.now()

	local interval

	local flyOver = false

	if now >= self.endTime then
		interval = self.endTime - self.lastTime
		flyOver = true
	else
		interval = now - self.lastTime
	end

	local opos = self.owner.pos

	local dtFly = self.speed * interval
	local dir = util.angle2dir(self.angle)
	local nx,nz = util.move_forward(opos[1],opos[2],dir,dtFly)

	self.owner:setPos(nx,nz)
	
	self.lastTime = now

	return flyOver
end




