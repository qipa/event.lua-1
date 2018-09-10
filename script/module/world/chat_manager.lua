local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local serverMgr = import "module.server_manager"
local dbObject = import "module.database_object"

cChatMgr = dbObject.cCollection:inherit("chat_manager")

function __init__(self)

end


function cChatMgr:onCreate()
	
end

function cChatMgr:onDestroy()
end


function cChatMgr:onEnter()

end

function cChatMgr:onOverride()

end

function cChatMgr:onLeave()

end

