local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local chatMgr = import "module.world.chat_manager"
local serverMgr = import "module.server_manager"
local dbObject = import "module.database_object"

cChatUser = dbObject.cCollection:inherit("chat_user")

function __init__(self)

end


function cChatUser:onCreate(user)
	self.__user = user
end

function cChatUser:onDestroy()
end


function cChatUser:onEnter()
	chatMgr:enter(self)
end

function cChatUser:onOverride()
	chatMgr:override(self)
end

function cChatUser:onLeave()
	chatMgr:leave(self)
end

