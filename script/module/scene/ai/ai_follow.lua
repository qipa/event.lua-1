local util = require "util"
local model = require "model"

local aiState = import "module.scene.ai.ai_state"

cAIFollow = aiState.cAIState:inherit("aiFollow")


function cAIFollow:ctor(fsm,charactor,...)
	self.fsm = fsm
	self.charactor = charactor
end

function cAIFollow:onEnter()
	local enemyUid = self.charactor:searchEnemy()
	if not enemyUid then
		self.fsm:switchState("IDLE")
		return false
	end

	if not self.charactor:moveToTarget(enemyUid) then
		self.fsm:switchState("IDLE")
		return false
	end

	self.followTime = event.now()
	self.lockEnemyUid = enemyUid

	return true
end

function cAIFollow:onUpdate(now)
	local enemyObj = model.fetch_fighter_with_uid(self.lockEnemyUid)
	if not enemyObj or enemyObj.isDead then
		self.fsm:switchState("IDLE")
		return false
	end

	if self.charactor:canAttack(enemyObj) then
		self.fsm:switchState("ATTACK",{targetObjUid = self.lockEnemyUid})
		return false
	end

	if self.charactor:isOutOfRange() then
		self.fsm:switchState("GOHOME")
		return false
	end

	local dtTime = now - self.followTime
	if dtTime >= 1000 then
		self.followTime = now

		if not self.charactor:moveToTarget(self.lockEnemyUid) then
			self.fsm:switchState("IDLE")
			return false
		end 
	end

	return true
end
