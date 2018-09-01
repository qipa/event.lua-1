local event = require "event"
local fighter = import "module.scene.fighter"
local sceneServer = import "module.scene.scene_server"

sceneServer:createScene(1001,1)

local userData = table.tostring({uid = 1,pos = {1,1}})
sceneServer:enterScene(userData,1,{1,1},false) 
