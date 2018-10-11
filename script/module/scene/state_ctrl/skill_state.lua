local util = require "util"
local event = require "event"
local vector2 = require "common.vector2"
local stateBase = import "module.scene.state_ctrl.state_base"
local skillApi = import "module.scene.skill.skill_api"

cStateSkill = stateBase.cStateBase:inherit("stateSkill")

function cStateSkill:ctor(sceneObj,skillInfo)
	self.skillId = skillInfo.skillId
	self.skillInfo = skillInfo
	self.attacker = sceneObj
	skillApi:onSkillBegin(sceneObj,self.skillId,skillInfo)
end

function cStateSkill:onCreate()
end

function cStateSkill:onDestroy()
	skillApi:onSkillEnd(sceneObj,self.skillId,skillInfo)
end

function cStateSkill:onUpdate(now)

	local now = event.now()
	local timeLapse = now - self.skillInfo.beginTime

	local skillOver = true

	for i = self.skillInfo.hitIndex, #self.skillInfo.hitInfo do
		local info = self.skillInfo.hitInfo[i]
		
		if timeLapse >= info.time then
			skillApi:onSkillExecute(self.attacker,self.skillId,self.skillInfo,info)
		else
			skillOver = false
			self.skillInfo.hitIndex = i
			break
		end
	end

	if skillOver then
		return true
	end

	return false
end




