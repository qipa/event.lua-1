local aoiCore = require "toweraoi.core"
local navCore= require "nav.core"
local cjson = require "cjson"
local timer = require "timer"
local object = import "module.object"
local sceneConst = import "module.scene.scene_const"

cScene = object.cls_base:inherit("scene")

local kUPDATE_INTERVAL = 0.1
local kCOMMON_UPDATE_INTERVAL = 1
local kDESTROY_TIME = 10

function cScene:create(sceneId,sceneUid)
	self.sceneId = sceneId
	self.sceneUid = sceneUid

	self.objMgr = {}
	self.objTypeMgr = {}
	
	self.aoi = aoiCore.create(self.sceneId,1000,1000,4)

	local nav = navCore.create(string.format("./config/%d.nav",sceneId))
	nav:load_tile(string.format("./config/%d.nav.tile",sceneId))

	self.nav = nav
	
	timer.callout(kUPDATE_INTERVAL,self,"update")
	timer.callout(kCOMMON_UPDATE_INTERVAL,self,"commonUpdate")

	self.phase = sceneConst.eSCENE_PHASE.CREATE
	self.lifeTime = 0
	self.timeoutResult = false

	self.passEvent = {}
	self.failEvent = {}

	self.areaMgr = {}
	self.areaEnter = {}
	self.areaActive = {}
end

function cScene:destroy()
	timer.removeAll(self)
	self:cleanSceneObj()
end

function cScene:cleanSceneObj()
	for _,sceneObj in pairs(self.objMgr) do
		sceneObj:release()
	end 
end

function cScene:getObj(uid)
	return self.objMgr[uid]
end

function cScene:getAllObjByType(sceneObjType)
	local typeMgr = self.objTypeMgr[sceneObjType]
	return typeMgr
end

function cScene:enter(sceneObj,pos)
	self.objMgr[sceneObj.uid] = sceneObj
	
	local objType = sceneObj:sceneObjType()
	
	local typeMgr = self.objTypeMgr[objType]
	if not typeMgr then
		typeMgr = {}
		self.objTypeMgr[objType] = typeMgr
	end 
	typeMgr[sceneObj.uid] = sceneObj

	sceneObj:onEnterScene(self)

	if objType == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
		self:onUserEnter(sceneObj)
	else
		self:onObjEnter(sceneobj)
	end
end

function cScene:leave(sceneObj)
	self.objMgr[sceneObj.uid] = nil

	local objType = sceneObj:sceneObjType()
	local typeMgr = self.objTypeMgr[objType]
	typeMgr[sceneObj.uid] = nil

	sceneObj:onLeaveScene(self)

	if objType == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
		self:onUserLeave(sceneObj)
	else
		self:onObjLeave(sceneobj)
	end
end

function cScene:onUserEnter(user)
	local locationInfo = user.locationInfo
	locationInfo.enter = {
		sceneId = self.id,
		sceneUid = self.uid,
		face = user.face,
		pos = {user.pos[1],user.pos[2]}
	}
end

function cScene:onUserLeave(user)
	local locationInfo = user.locationInfo
	locationInfo.leave = {
		sceneId = self.id,
		sceneUid = self.uid,
		face = user.face,
		pos = {user.pos[1],user.pos[2]}
	}
end

function cScene:onObjEnter(obj)

end

function cScene:onObjLeave(obj)

end

function cScene:findPath(fromX,fromZ,toX,toZ)
	return self.nav:find(fromX,fromZ,toX,toZ)
end

function cScene:raycast(fromX,fromZ,toX,toZ)
	return self.nav:raycast(fromX,fromZ,toX,toZ)
end

function cScene:posMovable(x,z)
	return self.nav:movable(x,z)
end

function cScene:posAroundMovable(x,z,depth)
	return self.nav:around_movable(x,z,depth)
end

function cScene:createAoiEntity(sceneObj)
	local entityId,aoiSet = self.aoi:create_entity(sceneObj.uid,sceneObj.pos[1],sceneObj.pos[2])

	for _,otherUid in pairs(aoiSet) do
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
		sceneObj.witnessCtx[otherUid] = true
	end

	return entityId
end

function cScene:removeAoiEntity(sceneObj)
	local aoiSet = self.aoi:remove_entity(sceneObj.entityId)

	for _,otherUid in pairs(aoiSet) do
		local other = self.objMgr[otherUid]
		other:onObjLeave({sceneObj})
		sceneObj.witnessCtx[otherUid] = nil
	end
end

function cScene:moveAoiEntity(sceneObj,x,z)
	local enterSet,LeaveSet = self.aoi:move_entity(sceneObj.entityId,x,z)

	for _,otherUid in pairs(enterSet) do
		local other = self.objMgr[otherUid]
		other:onObjEnter({sceneObj})
		sceneObj.witnessCtx[otherUid] = true
	end

	for _,otherUid in pairs(LeaveSet) do
		local other = self.objMgr[otherUid]
		other:onObjLeave({sceneObj})
		sceneObj.witnessCtx[otherUid] = nil
	end

end

function cScene:createAoiTrigger(sceneObj)
	local triggerId,aoiSet = self.aoi:create_trigger(sceneObj.uid,sceneObj.pos[1],sceneObj.pos[2],3)

	local empty = true 
	local enterList = {}
	for _,otherUid in pairs(aoiSet) do
		if otherUid ~= sceneObj.uid then
			empty = false
			local other = self.objMgr[otherUid]
			table.insert(enterList,other)
			sceneObj.viewerCtx[otherUid] = true
		end
	end
	
	if not empty then
		sceneObj:onObjEnter(enterList)
	end

	return triggerId
end

function cScene:removeAoiTrigger(sceneObj)
	self.aoi:remove_trigger(sceneObj.triggerId)
end

function cScene:moveAoiTrigger(sceneObj,x,z)
	local enterSet,LeaveSet = self.aoi:move_trigger(sceneObj.triggerId,x,z)

	local list = {}
	local empty = true
	for _,otherUid in pairs(enterSet) do
		if otherUid ~= sceneObj.uid then
			empty = false
			local other = self.objMgr[otherUid]
			table.insert(list,other)
			sceneObj.viewerCtx[otherUid] = true
		end
	end
	
	if not empty then
		sceneObj:onObjEnter(list)
	end

	local list = {}
	local empty = true
	for _,otherUid in pairs(LeaveSet) do
		empty = false
		local other = self.objMgr[otherUid]
		table.insert(list,other)
		sceneObj.viewerCtx[otherUid] = nil
	end
	
	if not empty then
		sceneObj:onObjLeave(list)
	end
end

function cScene:addPassEvent(ev,...)
	if ev == eSCEHE_PASS_EVENT.TIMEOUT then
		local time = ...
		self.timeoutResult = true
		self.lifeTime = time
	elseif ev == eSCEHE_PASS_EVENT.MONSTER_DIE then
		local monsterId = ...
		local evInfo = self.passEvent[ev]
		if not evInfo then
			evInfo = {}
			self.passEvent[ev] = evInfo
		end
		evInfo[monsterId] = true
	elseif ev == eSCEHE_PASS_EVENT.MONSTER_AREA_DONE then
		local areaId = ...
		local evInfo = self.passEvent[ev]
		if not evInfo then
			evInfo = {}
			self.passEvent[ev] = evInfo
		end
		evInfo[areaId] = true
	end
end

function cScene:addFailEvent(ev,...)
	if ev == eSCEHE_PASS_EVENT.TIMEOUT then
		local time = ...
		self.timeoutResult = false
		self.lifeTime = time
	elseif ev == eSCEHE_PASS_EVENT.USER_DIE then
		self.failEvent[ev] = true
	elseif ev == eSCEHE_PASS_EVENT.USER_ACE then
		self.failEvent[ev] = true
	elseif ev == eSCEHE_PASS_EVENT.MONSTER_DIE then
		local monsterId = ...
		local evInfo = self.failEvent[ev]
		if not evInfo then
			evInfo = {}
			self.failEvent[ev] = evInfo
		end
		evInfo[monsterId] = true
	end
end

function cScene:spawnMonster(id,pos,face,...)

end

function cScene:spawnMonsterArea(areaId)

end

function cScene:initArea(areaId)
	local areaInfo = {areaId = areaId,fired = false}
	self.areaMgr[areaId] = areaInfo
end

function cScene:enterArea(areaId)
	self.areaEnter[areaId] = true
	local areaInfo = self.areaMgr[areaId]
	if not areaInfo then
		return
	end

	if areaInfo.fired then
		return
	end
	areaInfo.fired = true
end

function cScene:leaveArea(areaId)
	self.areaEnter[areaId] = nil
	local areaInfo = self.areaMgr[areaId]
	if not areaInfo then
		return
	end
end

function cScene:fireAreaEvent(areaId,...)

end

function cScene:onMonsterAreaDone(areaId)
	if self.phase ~= sceneConst.eSCENE_PHASE.START then
		return
	end
	local evInfo = self.passEvent[eSCEHE_PASS_EVENT.MONSTER_AREA_DONE]
	if not evInfo then
		return
	end
	if not evInfo[areaId] then
		return
	end
	self:over()
	self.onWin()
end

function cScene:onMonsterCreate(monster)

end

function cScene:onMonsterDead(monster,killer)
	if self.phase ~= sceneConst.eSCENE_PHASE.START then
		return
	end
	local evInfo = self.passEvent[eSCEHE_PASS_EVENT.MONSTER_DIE]
	if evInfo then
		if evInfo[monster.id] then
			self:over()
			self.onWin()
			return
		end
	end
	
	local evInfo = self.failEvent[eSCEHE_PASS_EVENT.MONSTER_DIE]
	if evInfo then
		if evInfo[monster.id] then
			self:over()
			self.onFail()
			return
		end
	end
end

function cScene:onUserDead(user,killer)
	if self.phase ~= sceneConst.eSCENE_PHASE.START then
		return
	end

	if self.failEvent[eSCEHE_PASS_EVENT.USER_DIE] then
		self:over()
		self.onFail()
		return
	end

	if self.failEvent[eSCEHE_PASS_EVENT.USER_ACE] then
		local allUser = self:getAllObjByType(sceneConst.eSCENEOBJ_TYPE.FIGHTER)
		for _,user in pairs(allUser) do
			if not user:isDead() then
				return
			end
		end
		self:over()
		self.onFail()
		return
	end
end

function cScene:start()
	self.phase = sceneConst.eSCENE_PHASE.START
	self.startTime = os.time()
	self:onStart()
end

function cScene:over()
	self.phase = sceneConst.eSCENE_PHASE.OVER
	self.overTime = os.time()
	self:onOver()
end

function cScene:onStart()

end

function cScene:onOver()

end

function cScene:onWin()

end

function cScene:onFail()

end

function cScene:kickUser(user)

end

function cScene:update(now)
	for _,sceneObj in pairs(self.objMgr) do
		local ok,err = xpcall(sceneObj.onUpdate,debug.traceback,sceneObj,now)
		if not ok then
			event.error(err)
		end
	end
end

function cScene:commonUpdate(now)
	local phase = self.phase
	if phase == sceneConst.eSCENE_PHASE.START then
		if self.lifeTime ~= 0 then
			if now - self.startTime >= self.lifeTime then
				self:over()
				if self.timeoutResult then
					self:onWin()
				else
					self:onFail()
				end
			end
		end
	elseif phase == sceneConst.eSCENE_PHASE.OVER then
		if now - self.overTime >= kDESTROY_TIME then
			local allUser = self:getAllObjByType(sceneConst.eSCENEOBJ_TYPE.FIGHTER)
			if next(allUser) then
				for _,user in pairs(allUser) do
					self:kickUser(user)
				end
			else
				self:release()
			end
		end
	end

	for _,sceneObj in pairs(self.objMgr) do
		local ok,err = xpcall(sceneObj.onCommonUpdate,debug.traceback,sceneObj,now)
		if not ok then
			event.error(err)
		end
	end
end
