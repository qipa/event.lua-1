local event = require "event"
local cjson = require "cjson"
local model = require "model"

local util = require "util"
local protocol = require "protocol"

local serverMgr = import "module.server_manager"
local dbObject = import "module.database_object"


local eUSER_STATUS = {
	ALIVE = 1,
	DEAD = 2 }

cAgentUser = dbObject.cDatabase:inherit("agentUser","uid","cid")

function __init__(self)
	self.cAgentUser:saveField("base_info")
	self.cAgentUser:saveField("itemMgr")
	self.cAgentUser:saveField("task_mgr")
end


function cAgentUser:onCreate(cid,uid,account)
	self.cid = cid
	self.uid = uid
	self.status = eUSER_STATUS.ALIVE 
	self.hookTime = nil 

	self.account = account
end

function cAgentUser:onDestroy()

end

function cAgentUser:dbIndex()
	return {uid = self.uid}
end

function cAgentUser:enterGame()
	
	self.itemMgr:onEnterGame(self)

	self:fireEvent("ENTER_GAME")
	self:sendClient("s2c_agent_enter",{user_uid = self.uid})
	event.error(string.format("user:%d enter agent:%d",self.uid,env.dist_id))
end

function cAgentUser:leaveGame()
	self.itemMgr:onLeaveGame(self)
	self:fireEvent("LEAVE_GAME")
	event.error(string.format("user:%d leave agent:%d",self.uid,env.dist_id))
end

function cAgentUser:sendScene(file,method,args)
	local sceneInfo = self.sceneInfo
	if not sceneInfo then
		print(string.format("scene server:%d not connected",self.scene_server))
		return
	end
	serverMgr:sendScene(sceneInfo.serverId,file,method,args)
end

function cAgentUser:onEnterScene(serverId,sceneId,sceneUid)
	self.sceneInfo = {
		serverId = serverId,
		sceneId = sceneId,
		sceneUid = sceneUid
	}
end
