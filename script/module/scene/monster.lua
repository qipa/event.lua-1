local sceneConst = import "module.scene.scene_const"
local sceneobj = import "module.scene.sceneobj"
local idBuilder = import "module.id_builder"
local moveCtrl = import "module.scene.state_ctrl.move_ctrl"
local stateManager = import "module.scene.state_ctrl.state_manager"
cMonster = sceneobj.cSceneObj:inherit("monster")

function __init__(self)
	
end

function cMonster:onCreate(id,face,x,z)
	self.id = id
	self.uid = idBuilder:pop_monster_tid()
	sceneobj.cSceneObj.onCreate(self,self.uid,x,z)
	self.stateMgr = stateManager.cStateMgr:new(self)
	self.moveCtrl = moveCtrl.cMoveCtrl:new(self)
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

end

function cMonster:onObjLeave(objList)

end

function cMonster:onUpdate(now)
	self.stateMgr:onUpdate(now)
	sceneobj.cSceneObj.onUpdate(self,now)
end
