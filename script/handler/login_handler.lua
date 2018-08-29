local event = require "event"
local protocol = require "protocol"
local cjson = require "cjson"
local util = require "util"
local model = require "model"


local loginServer = import "module.login.login_server"

_server_status = _server_status or nil

function __init__()
	protocol.handler["c2s_login_auth"] = reqAuth 
	protocol.handler["c2s_login_enter"] = reqEnterGame 
	protocol.handler["c2s_create_role"] = reqCreateRole 
end

function reqAuth(cid,args)
	event.fork(function ()
		loginServer:userAuth(cid,args.account)
	end)
end

function reqCreateRole(loginUser,args)
	loginUser:createRole(args.career,args.name)
end

function reqEnterGame(loginUser,args)
	loginUser:enterAgent(args.uid)
end

function rpc_leave_agent(self,args)
	print("account 1",args.account)
	loginServer:user_leave_agent(args.account)
end

function rpc_kick_agent(self,args)
	print("account 2",args.account)
	loginServer:user_leave_agent(args.account)
end

function rpc_timeout_agent(self,args)
	print("account 3",args.account)
	loginServer:user_leave_agent(args.account)
end

function req_stop_server()
	loginServer:server_stop()
	if _server_status == "stop" then
		return false
	end
	_server_status = "stop"
	return true
end
