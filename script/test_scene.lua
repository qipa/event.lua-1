local event = require "event"

local sceneServer = import "module.scene.scene_server"

sceneServer:createScene(1,1)

sceneServer:enterScene("{}",1,{1,1},false) 