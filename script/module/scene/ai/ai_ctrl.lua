local sceneConst = import "module.scene.scene_const"


cAICtrl = sceneobj.cSceneObj:inherit("aiCtrl")


function cAICtrl:ctor(sceneObj)
	self.aiCharactor = sceneObj
end

function cAICtrl:onCreate()

end

function cAICtrl:onDestroy()

end

function cAICtrl:think(now)

end