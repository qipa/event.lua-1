local event = require "event"
local model = require "model"
local route = require "route"
local timer = require "timer"
local login_user = import "module.login.login_user"
local serverMgr = import "module.server_manager"
local clientMgr = import "module.client_manager"

_loginCtx = _loginCtx or {}
_accountQueue = _accountQueue or {}
_agentUser = _agentUser or {}

_nameAccount = _nameAccount or {}
_uidAccount = _uidAccount or {}

function start(self)
	
	timer.callout(30,self,"flush")
	timer.callout(1,self,"timeout")
	local dbChannel = model.get_db_channel()
	local result = dbChannel:findAll("event","accountInfo")
	for _,info in pairs(result) do
		for _,detail in pairs(info.list) do
			_nameAccount[detail.name] = info.account
			_uidAccount[detail.uid] = info.account
		end
	end

	serverMgr:registerEvent("AGENT_DOWN",self,"agentDown")
	import "handler.login_handler"
	import "handler.cmd_handler"
end

function flush(self)
	local all = model.fetch_login_user()
	for _,user in pairs(all) do
		user:save()
	end
end

function timeout(self)
	table.print(self)
end

function userEnterAgent(self,account,userUid,agentId)
	local info = {userUid = userUid,agentId = agentId,time = os.time()}
	_agentUser[account] = info
end

function agentDown(self,listener,agentId)
	for account,info in pairs(_agentUser) do
		if info.agent_server == agentId then
			_agentUser[account] = nil
		end
	end
end

function enter(self,cid,addr)
	event.error(string.format("cid:%d addr:%s enter",cid,addr))
	local info = {cid = cid,addr = addr}
	_loginCtx[cid] = info
end

function leave(self,cid)
	event.error(string.format("cid:%d leave",cid))
	local info = _loginCtx[cid]
	if not info then
		return
	end
	_loginCtx[cid] = nil

	if info.account then
		local user = model.fetch_login_user_with_account(info.account)
		if user and user.cid == cid then
			user:leave()
		end
	end
end

function dispatch_client(self,cid,message_id,data,size)
	local user = model.fetch_login_user_with_cid(cid)
	if not user then
		route.dispatch_client(cid,message_id,data,size)
	else
		route.dispatch_client(user,message_id,data,size)
	end
end

local function _userDoAuth(self,cid,account)
	local info = _loginCtx[cid]
	info.account = account
	local user = model.fetch_login_user_with_account(info.account)
	if user then
		if _loginCtx[user.cid] then
			clientMgr:close(user.cid)
		end
		user:leave()
	end
	user = login_user.cls_login_user:new(cid,account)
	user:load()
	user:auth()
end

function userAuth(self,cid,account)
	local info = _loginCtx[cid]
	assert(info ~= nil,cid)
	assert(info.account == nil,info.account)

	local agentUserInfo = _agentUser[account]
	if agentUserInfo then
		local queue = _accountQueue[account]
		if not queue then
			queue = {}
			_accountQueue[account] = queue
		end
		table.insert(queue,cid)

		serverMgr:send_agent(agentUserInfo.agentId,"handler.agent_handler","userKick",{uid = agentUserInfo.uid},function (ok)
			_agentUser[account] = nil
			_accountQueue[account] = nil
			local count = #queue
			for i = 1,count-1 do
				local cid = queue[i]
				if _loginCtx[cid] then
					clientMgr:close(cid)
					_loginCtx[cid] = nil
				end
			end
			local lastCid = queue[count]
			if not _loginCtx[lastCid] then 
				return
			end
			event.fork(_userDoAuth,self,lastCid,account)
		end)
		return
	end

	event.fork(_userDoAuth,self,cid,account)
end


function server_stop(self)
	local client_manager = model.get_client_manager()
	client_manager:stop()

	local all = model.fetch_login_user()
	for _,user in pairs(all) do
		user:leave()
	end

	local db_channel = model.get_db_channel()
	
	local updater = {}
	updater["$inc"] = {version = 1}
	updater["$set"] = {time = os.time()}
	db_channel:findAndModify("common","login_version",{query = {uid = env.dist_id},update = updater,upsert = true})

	local agent_set = server_manager:how_many_agent()
	for _,agent_id in pairs(agent_set) do
		server_manager:send_agent(agent_id,"handler.agent_handler","server_stop")
	end
end
