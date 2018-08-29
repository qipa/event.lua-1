local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local protocol = require "protocol"

local fighter = import "module.fighter"
local server_manager = import "module.server_manager"
local scene_server = import "module.scene_server"
local dbObject = import "module.database_object"

cSceneUser = dbObject.cls_database:inherit("scene_user","uid")

function __init__(self)
	self.cSceneUser:save_field("fighter")
	self.cSceneUser:save_field("buffMgr")
	self.cSceneUser:save_field("locationInfo")
end

function cSceneUser:create(uid)
	self.uid = uid
end

function cSceneUser:destroy()
	
end

function cSceneUser:db_index()
	return {uid = self.uid}
end

