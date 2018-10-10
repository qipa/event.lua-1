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
			[1] = {time = 1,event = 1,atkBox = {boxType = eATTACK_BOX.SECTOR,range = 100,degree = 60}},
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

function onSkillExecute(self, attacker, skillInfo, hitInfo)


	local hitterObjs = self:selectHitter(attacker,skillInfo,hitInfo.atkBox)
	if hitInfo.event == eSKILL_EVENT.DAMAGE then
		for _,hitterObj in pairs(hitterObjs) do
			self:onDamage(attacker,hitterObj,hitInfo)
		end
	elseif hitInfo.event == eSKILL_EVENT.HIT_FLY then
		for _,hitterObj in pairs(hitterObjs) do
			self:onHitFly(attacker,hitterObj,hitInfo)
		end
	elseif hitInfo.event == eSKILL_EVENT.HIT_BACK then
		for _,hitterObj in pairs(hitterObjs) do
			self:onHitBack(attacker,hitterObj,hitInfo)
		end
	end

end

function selectHitter(self,attacker,skillInfo,atkBoxInfo)

	local resultObjs
	if atkBoxInfo.boxType == eATTACK_BOX.CIRCLE then
		resultObjs = attacker:getSceneObjInCircle(atkBoxInfo.range)
	elseif atkBoxInfo.boxType == eATTACK_BOX.SECTOR then
		resultObjs = attacker:getSceneObjInRectangle(attacker.face,atkBoxInfo.length,atkBoxInfo.width)
	elseif atkBoxInfo.boxType == eATTACK_BOX.RECTANGLE then
		resultObjs = attacker:getSceneObjInSector(attacker.face,atkBoxInfo.degree,atkBoxInfo.range)
	end

	return resultObjs
end


function calcDamage(self,attacker,hitter)

end

function onDamage(self,attacker,hitter)
	local damage = self:calcDamage(attacker,hitter)
end

function onHitFly(self,attacker,hitter,hitInfo)
	local hitterStateMgr = hitter.stateMgr
	if hitterStateMgr:hasState("MOVE") then
		hitterStateMgr:delState("MOVE")
	end

	if hitterStateMgr:hasState("HIT_BACK") then
		return
	end

	if hitterStateMgr:hasState("HIT_FLY") then
		return
	end

	local flyInfo = {endTime = event.time() + hitInfo.flyInterval}

	hitterStateMgr:addState("HIT_FLY",flyInfo)
end

function onHitBack(self,attacker,hitter)
	local hitterStateMgr = hitter.stateMgr
	if hitterStateMgr:hasState("MOVE") then
		hitterStateMgr:delState("MOVE")
	end

	if hitterStateMgr:hasState("HIT_BACK") then
		return
	end

	if hitterStateMgr:hasState("HIT_FLY") then
		return
	end

	local interval = hitInfo.flyBackInterval
	local speed = hitInfo.flyBackSpeed
	local flyInfo = {endTime = event.time() + interval,interval = interval,speed}

	hitterStateMgr:addState("HIT_BACK",flyInfo)
end