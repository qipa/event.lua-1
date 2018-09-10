local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local chatMgr = import "module.world.chat_manager"
local serverMgr = import "module.server_manager"
local dbObject = import "module.database_object"
local sceneMgr = import "module.world.scene_manager"

cFighterProxy = dbObject.cCollection:inherit("fighter")

function __init__(self)
	self.cFighterProxy:saveField("locationInfo")
end


function cFighterProxy:onCreate(agentFighterInfo)
	self.__user = user
end

function cFighterProxy:onDestroy()
end

function cFighterProxy:enterScene(sceneId,sceneUid)
	sceneMgr:enterScene(self,sceneId,sceneUid)
end

function cFighterProxy:leaveScene()
	sceneMgr:leaveScene(self)
end


