local aoi_core = require "simpleaoi.core"
local sceneConst = import "module.scene.scene_const"
local sceneobj = import "module.scene.sceneobj"
local serverMgr = import "module.server_manager"
local clientMgr = import "module.client_manager"

cFighter = sceneobj.cSceneObj:inherit("fighter","uid")

function __init__(self)
	
end

function cFighter:onCreate(uid,x,z)
	print("cFighter:create")
	sceneobj.cSceneObj.create(self,uid,x,z)
end

function cFighter:onDestroy()
	sceneobj.cSceneObj.destroy(self)
end

function cFighter:sceneObjType()
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

	local msg = {sceneId = scene.sceneId,sceneUid = scene.sceneUid}
	serverMgr:sendAgent(self.agentId,"handler.agent_handler","onEnterScene",msg)
	clientMgr:sendClient(self.cid,"sEnterScene",msg)
end

function cFighter:onLeaveScene()
	sceneobj.cSceneObj.onLeaveScene(self)
end

function cFighter:move(x,z)
	sceneobj.cSceneObj.move(self,x,z)
end

function cFighter:onObjEnter(sceneObjList)
	sceneobj.cSceneObj.onObjEnter(self,sceneObjList)
	local list = {}
	for _,sceneObj in pairs(sceneObjList) do
		table.insert(list,sceneObj:getSeeInfo())
	end
	sendClient(self.cid,"s_sceneObj_create",msg)
end

function cFighter:onObjLeave(sceneObjList)
	sceneobj.cSceneObj.onObjLeave(self,sceneObjList)
	local list = {}
	for _,sceneObj in pairs(sceneObjList) do
		table.insert(list,sceneObj.uid)
	end 
	sendClient(self.cid,"s_sceneObj_delete",list)
end

function cFighter:onUpdate(now)
	print("cFighter:onUpdate")
	sceneobj.cSceneObj.onUpdate(self,now)
end
