local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"



function __init__(self)
	
end

function init(self,user)
	if not user.task_mgr then
		user.task_mgr = {uid = user.uid,task_info = {}}
		user:dirtyField("task_mgr")
	end
	
	user:registerEvent("ENTER_GAME",self,"enter_game")
	user:registerEvent("LEAVE_GAME",self,"leave_game")
end

function enter_game(self,user)

end

function leave_game(self,user)
	user:deregisterEvent("ENTER_GAME",self)
	user:deregisterEvent("LEAVE_GAME",self)
end

function accept(self,user)


end

function submit(self,user)

end

