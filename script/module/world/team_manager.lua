local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local serverMgr = import "module.server_manager"
local dbObject = import "module.database_object"

cTeamMgr = dbObject.cCollection:inherit("team_manager")

function __init__(self)

end


function cTeamMgr:onCreate()
	
end

function cTeamMgr:onDestroy()
end


function cTeamMgr:onEnter()

end

function cTeamMgr:onOverride()

end

function cTeamMgr:onLeave()

end

