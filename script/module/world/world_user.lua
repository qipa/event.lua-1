local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local protocol = require "protocol"
local server_manager = import "module.server_manager"
local dbObject = import "module.database_object"
local chatMgr = import "module.world.chat_manager"
local teamMgr = import "module.world.team_manager"

cWorldUser = dbObject.cDatabase:inherit("world_user","uid")

function __init__(self)
	self.cWorldUser:saveField("chatMgr")
	self.cWorldUser:saveField("teamMgr")
end


function cWorldUser:onCreate(userUid,agentId)
	self.userUid = userUid
	self.agentId = agentId
end

function cWorldUser:onDestroy()
end

function cWorldUser:dbIndex()
	return {userUid = self.userUid}
end

function cWorldUser:enter()
	event.error(string.format("user:%d enter world:%d",self.userUid,env.dist_id))
	if not self.chatMgr then
		self.chatMgr = chatMgr.cChatMgr:new()
		self.chatMgr:onCreate(self)
	end
	self.chatMgr:onEnter()

	if not self.teamMgr then
		self.teamMgr = teamMgr.cTeamMgr:new()
		self.teamMgr:onCreate(self)
	end
	self.teamMgr:onEnter()
end

function cWorldUser:override(agentId)
	self.agentId = agentId
	self.chatMgr:onOverride()
	self.teamMgr:onOverride()
end

function cWorldUser:leave()
	event.error(string.format("user:%d leave world:%d",self.userUid,env.dist_id))

	self.chatMgr:onLeave()
	self.teamMgr:onLeave()
end

