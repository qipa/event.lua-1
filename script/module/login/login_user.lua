local event = require "event"
local cjson = require "cjson"
local model = require "model"
local util = require "util"
local protocol = require "protocol"

local id_builder = import "module.id_builder"
local database_object = import "module.database_object"
local serverMgr = import "module.server_manager"
local agentMgr = import "module.login.agent_manager"
local clientMgr = import "module.client_manager"

cLoginUser = database_object.cls_database:inherit("login_user","account","cid")

function __init__(self)
	self.cLoginUser:save_field("accountInfo")
	self.cLoginUser:save_field("forbidInfo")
end

function cLoginUser:create(cid,account)
	self.cid = cid
	self.account = account
	
end

function cLoginUser:db_index()
	return {account = self.account}
end

function cLoginUser:auth()
	self:load()

	local user = model.fetch_login_user_with_account(self.account)
	if not user or user ~= self then
		return
	end

	if not self.accountInfo then
		self.accountInfo = {list = {}}
		self:dirty_field("accountInfo")
	end

	local result = {}
	for _,role in pairs(self.accountInfo.list) do
		table.insert(result,{uid = role.uid,name = role.name})
	end

	send_client(self.cid,"s2c_login_auth",{list = result})

	model.bind_login_user_with_account(self.account,self)
	model.bind_login_user_with_cid(self.cid,self)
end

function cLoginUser:createRole(career,name)
	local role = {career = career,name = "mrq",uid = id_builder:alloc_user_uid()}
	table.insert(self.accountInfo.list,role)
	self:dirty_field("accountInfo")

	local result = {}
	for _,role in pairs(self.accountInfo.list) do
		table.insert(result,{uid = role.uid,name = role.name})
	end

	send_client(self.cid,"s2c_create_role",{list = result})
end

function cLoginUser:delete_role(uid)

end

function cLoginUser:create_name(name)

end

function cLoginUser:random_name()

end

function cLoginUser:destroy()
	model.unbind_login_user_with_account(self.account)
	model.unbind_login_user_with_cid(self.cid)
end

function cLoginUser:leave()
	self:save()
	self:release()
end

function cLoginUser:enterAgent(uid)
	local agentId,agentAddr = agentMgr:selectAgent()
	local time = util.time()
	local json = cjson.encode({account = self.account,uid = uid})
	local token = util.authcode(json,tostring(time),1)

	serverMgr:send_agent(agentId,"handler.agent_handler","user_register",{token = token,time = time,uid = uid,account = self.account},function ()
		local user = model.fetch_login_user_with_cid(info.cid)
		if not user then
			return
		end
		send_client(user.cid,"s2c_login_enter",{token = token,ip = agent_addr.ip,port = agent_addr.port})
		clientMgr:close(user.cid)
	end)

end

