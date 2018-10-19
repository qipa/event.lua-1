local util = require "util"
local event = require "event"

local aiState = import "module.scene.ai.ai_state"

cAIAttack = aiState.cAIState:inherit("aiAttack")


function cAIAttack:ctor(fsm,charactor,info)
	self.fsm = fsm
	self.charactor = charactor
	self.targetObjUid = info.targetObjUid
end

function cAIAttack:onEnter()
	self.time = event.now()
end

function cAIAttack:onUpdate(now)
	
	return true
end
