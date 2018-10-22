local util = require "util"
local event = require "event"

local aiState = import "module.scene.ai.ai_state"

cAIAttack = aiState.cAIState:inherit("aiAttack")

function cAIAttack:onCreate(targetObjUid)
	self.targetObjUid = targetObjUid
end

function cAIAttack:onEnter()
	self.time = event.now()
end

function cAIAttack:onExecute(now)
	
	return true
end
