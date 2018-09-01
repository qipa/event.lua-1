local event = require "event"
local clientMgr = import "module.client_manager"
local fighter = import "module.scene.fighter"
local monster = import "module.scene.monster"
local sceneServer = import "module.scene.scene_server"

sceneServer:createScene(1001,1)

local userData = table.tostring({uid = 1,pos = {1,1}})
sceneServer:enterScene(userData,1,{1,1},false) 

local scene = sceneServer:getScene(1)

for i = 1,1 do
	local inst = monster.cMonster:new(2,1,1)
	scene:enter(inst,1,1)
end
