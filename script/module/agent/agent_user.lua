local event = require "event"
local cjson = require "cjson"
local model = require "model"

local util = require "util"
local protocol = require "protocol"

local agent_server = import "module.agent.agent_server"
local database_object = import "module.database_object"


local eUSER_STATUS = {
	ALIVE = 1,
	DEAD = 2 }

cAgentUser = database_object.cDatabase:inherit("agent_user","uid","cid")


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
	model.bind_agent_user_with_uid(uid,self)
	model.bind_agent_user_with_cid(cid,self)
end

function cAgentUser:onDestroy()
	model.unbind_agent_user_with_uid(self.uid)
	model.unbind_agent_user_with_cid(self.cid)
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
	local scene_channel = self.scene_channel
	if not scene_channel then
		print(string.format("scene server:%d not connected",self.scene_server))
		return
	end
	scene_channel:send(file,method,args)
end

function cAgentUser:sync_scene_info(scene_id,scene_uid,scene_server)
	self.scene_id = scene_id
	self.scene_uid = scene_uid
	self.scene_server = scene_server
	self.scene_channel = agent_server:get_scene_channel(scene_server)
end

function cAgentUser:scene_down()
	self.scene_id = nil
	self.scene_uid = nil
	self.scene_server = nil
	self.scene_channel = nil
end
