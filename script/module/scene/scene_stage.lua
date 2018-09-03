local sceneConst = import "module.scene.scene_const"
local scene = import "module.scene.scene"

cSceneStage = scene.cScene:inherit("scene_stage")

function cSceneStage:create(stageId,sceneId,sceneUid)
	scene.cScene.create(self,sceneId,sceneUid)
	self.stageId = stageId
end 

function cSceneStage:onUserEnter(user)
	scene.cScene.onUserEnter(self,user)
end

function cSceneStage:onUserLeave(user)
	scene.cScene.onUserLeave(self,user)
end

function cSceneStage:onObjEnter(obj)

end

function cSceneStage:onObjLeave(obj)

end

function cSceneStage:update(now)
	scene.cScene.update(self,now)
end 

function cSceneStage:commonUpdate(now)
	scene.cScene.commonUpdate(self,now)
end
