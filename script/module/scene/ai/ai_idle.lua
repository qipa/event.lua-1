local util = require "util"
local vector2 = require "common.vector2"
local aiState = import "module.scene.ai.ai_state"

cAIStateIdle = aiState.cAIState:inherit("aiStateIdle")


function cAIState:ctor(fsm,charactor,...)
	self.fsm = fsm
	self.charactor = charactor
	self.time = event.now()
end

function cAIState:onUpdate(now)
	if self.charactor:haveEnemy() then
		self.fsm:switchState("FOLLOW")
		return false
	else
		if now - self.time > 2 then
			self.fsm:switchState("PATROL")
			return false
		end
	end
	return true
end
