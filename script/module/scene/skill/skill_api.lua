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
		hitIndex = 1,
		hitInfo = {
			[1] = {time = 1,event = eSKILL_EVENT.DAMAGE,atkBox = {boxType = eATTACK_BOX.SECTOR,range = 100,degree = 60}},
			[2] = {time = 1.5,event = eSKILL_EVENT.HIT_FLY,atkBox = {boxType = eATTACK_BOX.RECTANGLE,length = 100,width = 20}},
			[3] = {time = 2.5,event = eSKILL_EVENT.HIT_BACK,atkBox = {boxType = eATTACK_BOX.CIRCLE,range = 100}},
		},
		interval = 2.5
	}

	local stateMgr = attacker.stateMgr
	stateMgr:addState("SKILL",skillInfo)
end

function onSkillBegin(self, attacker, skillInfo)
	print("onSkillBegin")
end

function onSkillEnd(self, attacker, skillInfo)
	print("onSkillEnd")
end

function onSkillExecute(self, attacker, skillId, skillInfo, hitInfo)
	print("onSkillExecute")

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
		resultObjs = attacker:getObjInCircle(attacker.pos,atkBoxInfo.range)
	elseif atkBoxInfo.boxType == eATTACK_BOX.SECTOR then
		resultObjs = attacker:getObjInSector(attacker.pos,attacker.face,atkBoxInfo.degree,atkBoxInfo.range)
	elseif atkBoxInfo.boxType == eATTACK_BOX.RECTANGLE then
		resultObjs = attacker:getObjInRectangle(attacker.pos,attacker.face,atkBoxInfo.length,atkBoxInfo.width)
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