local util = require "util"
local vector2 = require "common.vector2"
local object = import "module.object"

cMoveCtrl = object.cObject:inherit("moveCtrl")


function cMoveCtrl:ctor(sceneObj,pathList)
	self.sceneObj = sceneObj
	self.time = util.time()
	self.pathList = pathList
	self.pathIndex = 1
	self.pathMax = #pathList
end

function cMoveCtrl:onCreate()
end

function cMoveCtrl:onDestroy()

end

function cMoveCtrl:onUpdate(now)
	if self.pathIndex > self.pathMax then
		return
	end

	local pathPos = self.pathList[self.pathIndex]

	local now = now or util.time()
	local interval = now - self.time

	local sceneObj = self.sceneObj
	
	local pos = sceneObj.pos
	local dtPass = (interval * sceneObj.speed) / 100

	local x,z = vector2.move_forward(pos[1],pos[2],self.x,self.z,pass)

	fighter.scene:fighter_move(fighter,x,z)
	
	pos.x = x
	pos.z = z

	self.time = now

	if vector2.distance(x,z,self.x,self.z) < 0.1 then
		fighter.move_ctrl = nil
		return false
	end
	return true
end
