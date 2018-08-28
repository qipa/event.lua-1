local event = require "event"
local protocol = require "protocol"
local cjson = require "cjson"
local util = require "util"
local model = require "model"


local login_server = import "module.login_server"

_server_status = _server_status or nil

function __init__()
	protocol.handler["c2s_login_auth"] = reqAuth 
	protocol.handler["c2s_login_enter"] = reqEnterGame 
	protocol.handler["c2s_create_role"] = reqCreateRole 
end

function reqAuth(cid,args)
	event.fork(function ()
		login_server:user_auth(cid,args.account)
	end)
end

function reqCreateRole(cid,args)
	login_server:user_create_role(cid,args.career)
end

function reqEnterGame(cid,args)
	login_server:user_enter_agent(cid,args.uid)
end

function rpc_leave_agent(self,args)
	print("account 1",args.account)
	login_server:user_leave_agent(args.account)
end

function rpc_kick_agent(self,args)
	print("account 2",args.account)
	login_server:user_leave_agent(args.account)
end

function rpc_timeout_agent(self,args)
	print("account 3",args.account)
	login_server:user_leave_agent(args.account)
end

function req_stop_server()
	login_server:server_stop()
	if _server_status == "stop" then
		return false
	end
	_server_status = "stop"
	return true
end
