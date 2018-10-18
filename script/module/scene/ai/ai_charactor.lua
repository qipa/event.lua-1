local util = require "util"
local vector2 = require "common.vector2"
local object = import "module.object"
local sceneConst = import "module.scene.scene_const"

cAICharactor = object.cObject:inherit("aiCharactor")


function cAICharactor:ctor(sceneObj)
	self.owner = sceneObj
end

function cAICharactor:onCreate()
end

function cAICharactor:onDestroy()

end

function cAICharactor:searchEnemy()
	local enemyList = self.owner:getViewer(sceneConst.eSCENEOBJ_TYPE.FIGHTER)
	if not next(enemyList) then
		return
	end

	local pos = self.owner.pos
	local minDt
	local enemyUid
	for _,enemy in pairs(enemyList) do
		local dt = util.dot2dot2(pos[1],pos[2],enemy.pos)
		if not minDt or minDt > dt then
			minDt = dt
			enemyUid.uid
		end
	end

	return enemyUid
end

function cAICharactor:haveEnemy()
	local enemyList = self.owner:getViewer(sceneConst.eSCENEOBJ_TYPE.FIGHTER)
	if not next(enemyList) then
		return
	end
	return true
end

