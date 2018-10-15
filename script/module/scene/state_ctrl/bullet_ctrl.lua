local util = require "util"
local event = require "event"
local object = import "module.object"

cBulletCtrl = object.cObject:inherit("bulletCtrl")

local dtDot2Dot = util.dot2dot
local moveForward = util.move_forward

function cBulletCtrl:ctor(sceneObj)
	self.owner = sceneObj
end

function cBulletCtrl:onCreate()
end

function cBulletCtrl:onDestroy()

end

function cBulletCtrl:setTargetObj(targetObj)

end

function cBulletCtrl:setTargetPos(pos)

end

function cBulletCtrl:onUpdate(now)
	return self:doMove(now)
end

