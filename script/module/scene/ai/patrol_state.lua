local util = require "util"
local vector2 = require "common.vector2"
local AIState = import "module.scene.ai.ai_state"
local moveCtrl = import "module.scene.ctrl.move_ctrl"

cPatrolState = AIState.cAIState:inherit("patrolState")


function cPatrolState:ctor(sceneObj)
	self.owner = sceneObj
	self.center = {0,0}
	self.range = 100
	self.moveCtrl = moveCtrl.cMoveCtrl:new(sceneObj)
end

function cPatrolState:onUpdate(now)
	self.moveCtrl:onUpdate(now)
end
