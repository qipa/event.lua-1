local util = require "util"

local object = import "module.object"

cFSM = object.cObject:inherit("aiFSM")

local eAI_STATE = {
	["IDLE"] 	= import("module.scene.ai.ai_idle").cAIIdle,
	["PATROL"] 	= import("module.scene.ai.ai_patrol").cAIPatrol,
	["GOHOME"] 	= import("module.scene.ai.ai_gohome").cAIGohome,
	["FOLLOW"] 	= import("module.scene.ai.ai_follow").cAIFollow,
	["ATTACK"] 	= import("module.scene.ai.ai_attack").cAIAttack,
}

function cFSM:ctor(charactor)
	self.charactor = charactor

	self.aiState = nil
end

function cFSM:onCreate()
end

function cFSM:onDestroy()

end

function cFSM:switchState(state,info)
	if self.aiState then
		self.aiState:onLeave()
		self.aiState:release()
	end

	self.aiState = eAI_STATE[state]:new(self,self.charactor,info)
	self.aiState:onEnter(self.charactor,info)
end

function cFSM:onUpdate(now)
	if self.aiState then
		self.aiState:onUpdate(now)
	end
end
