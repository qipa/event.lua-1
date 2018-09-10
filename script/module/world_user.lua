local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local protocol = require "protocol"
local server_manager = import "module.server_manager"
local dbObject = import "module.database_object"

cWorldUser = dbObject.cDatabase:inherit("world_user","uid")

function __init__(self)
	self.cWorldUser:saveField("base_info")
	self.cWorldUser:saveField("world_user")
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
	model.bind_world_user_with_uid(self.userUid,self)
end

function cWorldUser:override(agentId)
	self.agentId = agentId
end

function cWorldUser:leave()
	event.error(string.format("user:%d leave world:%d",self.userUid,env.dist_id))
	model.unbind_world_user_with_uid(self.userUid)
end

