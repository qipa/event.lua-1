local sceneConst = import "module.scene.scene_const"
local scene = import "module.scene.scene"

cStageScene = scene.cScene:inherit("stage_scene")

function cStageScene:create(stageId,sceneId,sceneUid)
	scene.cScene.create(self,sceneId,sceneUid)
	self.stageId = stageId
end 

function cStageScene:onUserEnter(user)

end

function cStageScene:onUserLeave(user)

end

function cStageScene:onObjEnter(obj)

end

function cStageScene:onObjLeave(obj)

end

function cStageScene:update(now)
	scene.cScene.update(self,now)
end 

function cStageScene:commonUpdate(now)
	scene.cScene.commonUpdate(self,now)
end
