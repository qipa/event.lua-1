local event = require "event"


eATTACK_BOX = {
	["CIRCLE"] = 1,
	["SECTOR"] = 2,
	["RECTANGLE"] = 3,
}

eSKILL_EVENT = {
	["DAMAGE"] = 1,
	["HIT_FLY"] = 2,
	["HIT_BACK"] = 3,
}

function useSkill(self, attacker, skillId)

	local skillInfo = {
		skillId = skillId,
		hitIndex = 0,
		hitInfo = {
			[1] = {time = 1,event = 1},
			[2] = {time = 1.5,event = 2},
			[3] = {time = 2.5,event = 3},
		},
		interval = 2.5
	}
	skillInfo.beginTime = event.now()
	skillInfo.endTime = skillInfo.beginTime + skillInfo.interval

	local stateMgr = attacker.stateMgr
	stateMgr:addState("SKILL",skillInfo)
end

function onSkillBegin(self, attacker, skillInfo)

end

function onSkillEnd(self, attacker, skillInfo)

end

function onSkillExecute(self, attacker, skillInfo)


end