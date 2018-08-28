local aoi_core = require "simpleaoi.core"
local sceneConst = import "module.scene.scene_const"
local sceneobj = import "module.scene.sceneobj"

cFighter = sceneobj.cSceneObj:inherit("fighter")

function __init__(self)
	
end

function cFighter:create(uid,x,z)
	sceneobj.cSceneObj.create(self,uid,x,z)
end

function cFighter:destroy()
	sceneobj.cSceneObj.destroy(self)
end

function cSceneObj:sceneObjType()
	return sceneConst.eSCENEOBJ_TYPE.FIGHTER
end

function cFighter:enterScene(scene,x,z)
	sceneobj.cSceneObj.enterScene(self,scene,x,z)
end

function cFighter:leaveScene()
	sceneobj.cSceneObj.leaveScene(self)
end

function cFighter:onEnterScene(scene)
	sceneobj.cSceneObj.onEnterScene(self,scene)
	self.aoiTriggerId = scene:createTrigger(self)
end

function cFighter:onLeaveScene()
	sceneobj.cSceneObj.onLeaveScene(self)
	self.scene:removeTrigger(self)
end

function cFighter:move(x,z)
	sceneobj.cSceneObj.onEnterScene(self,x,z)
	self.scene:moveAoiTrigger(x,z)
end

function cFighter:onObjEnter(sceneObjList)
	sceneobj.cSceneObj.onObjEnter(self,sceneObjList)
	local list = {}
	for _,sceneObj in pairs(sceneObjList) do
		table.insert(list,sceneObj:getSeeInfo())
	end
	send_client(self.cid,"s_sceneObj_create",msg)
end

function cFighter:onObjLeave(sceneObjList)
	sceneobj.cSceneObj.onObjLeave(self,sceneObjList)
	local list = {}
	for _,sceneObj in pairs(sceneObjList) do
		table.insert(list,sceneObj.uid)
	end 
	send_client(self.cid,"s_sceneObj_delete",list)
end

function cFighter:onUpdate(now)
	sceneobj.cSceneObj.onUpdate(self,now)
end
