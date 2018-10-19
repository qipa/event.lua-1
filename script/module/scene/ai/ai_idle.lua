local util = require "util"
local event = require "event"

local aiState = import "module.scene.ai.ai_state"

cAIIdle = aiState.cAIState:inherit("aiIdle")


function cAIIdle:ctor(fsm,charactor,...)
	self.fsm = fsm
	self.charactor = charactor
end

function cAIIdle:onEnter()
	self.time = event.now()
end

function cAIIdle:onUpdate(now)
	print("IDLE")
	if self.charactor:haveEnemy() then
		self.fsm:switchState("FOLLOW")
		return false
	else
		if now - self.time > 2000 then
			self.fsm:switchState("PATROL")
			return false
		end
	end
	return true
end
