local util = require "util"
local model = require "model"
local event = require "event"
local aiState = import "module.scene.ai.ai_state"

cAIPatrol = aiState.cAIState:inherit("aiPatrol")


function cAIPatrol:ctor(fsm,charactor,...)
	self.fsm = fsm
	self.charactor = charactor
	self.time = event.now()
end

function cAIPatrol:onEnter()
	local x,z = self.charactor:randomPatrolPos()
	self.patrolPos = {x,z}

	local ownerObj = self.charactor.owner
	local moveCtrl = ownerObj.moveCtrl

	moveCtrl:onServerMoveStart({{ownerObj.pos[1],ownerObj.pos[2]}, self.patrolPos})
end

function cAIPatrol:onUpdate(now)
	print("PATROL")
	if self.charactor:haveEnemy() then
		self.fsm:switchState("FOLLOW")
		return false
	end

	local ownerObj = self.charactor.owner
	local stateMgr = ownerObj.stateMgr

	if not stateMgr:hasState("MOVE") then
		self.fsm:switchState("IDLE")
		return false
	end
	return true
end
