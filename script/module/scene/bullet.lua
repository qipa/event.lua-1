local sceneConst = import "module.scene.scene_const"
local sceneobj = import "module.scene.sceneobj"
local idBuilder = import "module.id_builder"
local bulletCtrl = import "module.scene.state_ctrl.bullet_ctrl"


cBullet = sceneobj.cSceneObj:inherit("bullet")

function __init__(self)
	
end

function cBullet:onCreate(id,face,x,z)
	self.id = id
	self.uid = idBuilder:pop_monster_tid()
	sceneobj.cSceneObj.onCreate(self,self.uid,x,z)
	self.bulletCtrl = bulletCtrl.cBulletCtrl:new(self)
end

function cBullet:onDestroy()
	sceneobj.cSceneObj.onDestroy(self)
end

function cBullet:sceneObjType()
	return sceneConst.eSCENEOBJ_TYPE.BULLET
end

function cBullet:onObjEnter(objList)

end

function cBullet:onObjLeave(objList)

end

function cBullet:setFollowTarget(targetObj)
	self.bulletCtrl:setTargetObj(targetObj)
end

function cBullet:setFollowPos(targetPos)
	self.bulletCtrl:setTargetPos(targetPos)
end

function cBullet:doCollision(from,to)

end

function cBullet:onUpdate(now)
	sceneobj.cSceneObj.onUpdate(self,now)

	self.bulletCtrl:onUpdate(now)
end
