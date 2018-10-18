local util = require "util"
local vector2 = require "common.vector2"
local object = import "module.object"

cFSM = object.cObject:inherit("aiFSM")

local eAI_STATE = {
	["IDLE"] 	= import("module.scene.ai.ai_idle").cAIStateIdle,
	["PATROL"] 	= import("module.scene.ai.ai_patrol").cAIStatePatrol,
	["GOHOME"] 	= import("module.scene.ai.ai_gohome").cAIStateGohome,
	["FOLLOW"] 	= import("module.scene.ai.ai_follow").cAIStateFollow,
	["ATTACK"] 	= import("module.scene.ai.ai_attack").cAIStateAttack,
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

	local aiState = eAI_STATE[state]:new(self,self.charactor,info)
	aiState:onEnter(self.charactor,info)

	self.aiState = aiState
end

function cFSM:onUpdate(now)
	if self.aiState then
		self.aiState:onUpdate(now)
	end
end
