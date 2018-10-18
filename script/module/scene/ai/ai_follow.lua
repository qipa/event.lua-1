local util = require "util"
local model = require "model"
local vector2 = require "common.vector2"
local aiState = import "module.scene.ai.ai_state"

cAIStateFollow = aiState.cAIState:inherit("aiStateFollow")


function cAIStateFollow:ctor(fsm,charactor,...)
	self.fsm = fsm
	self.charactor = charactor
	self.time = event.now()
end

function cAIStateFollow:onEnter()
	local enemyUid = self.charactor:searchEnemy()
	if not enemyUid then
		self.fsm:switchState("IDLE")
		return false
	end

	self.lockEnemyUid = enemyUid
end

function cAIStateFollow:onUpdate(now)
	local enemyObj = model.fetch_fighter_with_uid(enemyUid)
	if not enemyObj then
		self.fsm:switchState("IDLE")
		return false
	end

	if self.following then

	end
	return true
end
