local aoi_core = require "simpleaoi.core"
local sceneConst = import "module.scene.scene_const"
local sceneobj = import "module.scene.sceneobj"

cMonster = sceneobj.cSceneObj:inherit("monster")

function __init__(self)
	
end

function cMonster:create(uid,x,z)
	sceneobj.cSceneObj.create(self,uid,x,z)
end

function cMonster:destroy()
	sceneobj.cSceneObj.destroy(self)
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
	self.aoiTriggerId = scene:createTrigger(self)
end

function cMonster:onLeaveScene()
	sceneobj.cSceneObj.onLeaveScene(self)
	self.scene:removeTrigger(self)
end

function cMonster:move(x,z)
	sceneobj.cSceneObj.onEnterScene(self,x,z)
	self.scene:moveAoiTrigger(self,x,z)
end

function cMonster:onObjEnter(objList)

end

function cMonster:onObjLeave(objList)

end

function cMonster:onUpdate(now)
	sceneobj.cSceneObj.onUpdate(self,now)
end
