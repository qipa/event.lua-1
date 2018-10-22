local sceneConst = import "module.scene.scene_const"
local sceneobj = import "module.scene.sceneobj"
local idBuilder = import "module.id_builder"
local aiCharactor = import "module.scene.ai.ai_charactor"
local fsm = import "module.scene.ai.fsm"
local moveCtrl = import "module.scene.state_ctrl.move_ctrl"
local stateManager = import "module.scene.state_ctrl.state_manager"
cMonster = sceneobj.cSceneObj:inherit("monster")

function __init__(self)
	
end

function cMonster:onCreate(id,pos,face)
	self.id = id
	sceneobj.cSceneObj.onCreate(self,idBuilder:allocMonsterTid(),pos,nil,100)
	self.stateMgr = stateManager.cStateMgr:new(self)
	self.moveCtrl = moveCtrl.cMoveCtrl:new(self)

	self.aiCharactor = aiCharactor.cAICharactor:new(self)
	self.aiFsm = fsm.cFSM:new(self.aiCharactor,true)
	self.aiFsm:switchState("IDLE")

	self.range = 50

	self.bornPos = {pos[1],pos[2]}
	self.patrolRange = 50
end

function cMonster:onDestroy()
	sceneobj.cSceneObj.onDestroy(self)
end

function cMonster:sceneObjType()
	return sceneConst.eSCENEOBJ_TYPE.MONSTER
end

function cMonster:enterScene(scene,x,z)
	sceneobj.cSceneObj.enterScene(self,scene,x,z)
end

function cMonster:leaveScene()
	sceneobj.cSceneObj.leaveScene(self)
end

function cMonster:onEnterScene(scene)
	sceneobj.cSceneObj.onEnterScene(self,scene)
end

function cMonster:onLeaveScene()
	sceneobj.cSceneObj.onLeaveScene(self)
end

function cMonster:move(x,z)
	sceneobj.cSceneObj.move(self,x,z)
end

function cMonster:onObjEnter(objList)
	for _,sceneObj in pairs(objList) do
		if sceneobj:sceneObjType() == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
			self.aiCharactor:onUserEnter(sceneObj)
		end
	end
end

function cMonster:onObjLeave(objList)
	for _,sceneObj in pairs(objList) do
		if sceneobj:sceneObjType() == sceneConst.eSCENEOBJ_TYPE.FIGHTER then
			self.aiCharactor:onUserLeave(sceneObj)
		end
	end
end

function cMonster:onUpdate(now)
	self.aiFsm:onUpdate(now)
	self.stateMgr:onUpdate(now)
	sceneobj.cSceneObj.onUpdate(self,now)
end
