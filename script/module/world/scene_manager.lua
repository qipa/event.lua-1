local event = require "event"
local model = require "model"

local serverMgr = import "module.server_manager"
local idBuilder = import "module.id_builder"

_sceneServerMgr = _sceneServerMgr or {}
_sceneInfo = _sceneInfo or {}
_sceneMgr = _sceneMgr or {}
_fighterMgr = _fighterMgr or {}

_agentConnectMutex = _agentConnectMutex or {}
_agentConnectInfo = _agentConnectInfo or {}

function __init__(self)
	serverMgr:registerEvent("SERVER_DOWN",self,"onServerDown")
end

function createScene(self,sceneId,func)
	local minServer
	local minAmount
	for serverId,info in pairs(_sceneServerMgr) do
		if not minAmount or minAmount > info.amount then
			minAmount = info.amount
			minServer = serverId
		end
	end

	local sceneUid = idBuilder:alloc_scene_uid()
	serverMgr:sendScene(minServer,"module.scene.scene_server","createScene",{sceneId = sceneId,sceneUid = sceneUid},func)
	return minServer,sceneUid
end

function onServerDown(self,name,serverId)

end

function reportSceneAddr(self,args)
	_sceneServerMgr[args.serverId] = {
		addr = args.addr,
		amount = 0
	}
end

function onAgentConnectScene(self,args)

end

function agentConnectScene(self,agentServerId,sceneServerId)
	local connectInfo = _agentConnectInfo[agentServerId]
	if not connectInfo then
		connectInfo = {}
		_agentConnectInfo[agentServerId] = connectInfo
	end

	if connectInfo[sceneServerId] then
		return true
	end

	local sceneServerInfo = _sceneServerMgr[sceneServerId]
	if not sceneServerInfo then
		return false
	end

	local mutex = _agentConnectMutex[agentServerId]
	if not mutex then
		mutex = event.mutex()
		_agentConnectMutex[agentServerId] = mutex
	end

	return mutex(function ()
		if connectInfo[sceneServerId] then
			return true
		end

		local ok = serverMgr:callAgent(agentServerId,"module.agent.agent_server","connectSceneServer",{serverId = sceneServerId,addr = sceneServerInfo.addr})
		if ok then
			connectInfo[sceneServerId] = true
			return true
		else
			return false
		end
	end)
end

function enter(self,args)
	local dbChannel = model.get_db_channel()
	local location = dbChannel:findOne("event","fighter",{query = {userUid = args.agentUid,selector = {locationInfo = true}}})
	if not location then
		location = {

		}
	end

	self:enterScene(location.sceneId,location.sceneUid)
end

function leave(self,args)

end

function enterScene(self,userUid,agentId,sceneId,sceneUid)
	local fighterInfo
	local location = _fighterMgr[userUid]
	if location then
		if location.sceneUid ~= sceneUid then
			fighterInfo = serverMgr:callScene(location.serverId,"module.scene.scene_server","leaveScene",{userUid = userUid})
		else
			serverMgr:callScene(location.serverId,"module.scene.scene_server","enterScene",{userUid = userUid})
			return
		end
	end

	local sceneInfo = _sceneMgr[args.sceneId]
	if not sceneInfo then
		sceneInfo = {}
		_sceneMgr[args.sceneId] = sceneInfo
	end

	local serverId
	if not sceneUid then
		serverId,sceneUid = self:createScene(sceneId)
		sceneInfo[sceneUid] = {serverId = serverId}
	else
		local info = sceneInfo[sceneUid]
		if info then
			serverId = info.serverId
		else
			serverId,sceneUid = self:createScene(sceneId)
			sceneInfo[sceneUid] = {serverId = serverId}
		end
	end

	if not self:agentConnectScene(agentId,serverId) then
		return
	end

	serverMgr:callScene("module.scene.scene_server","enterScene",{userUid = userUid,fighterInfo = fighterInfo})

	_fighterMgr[userUid] = {serverId = serverId,sceneId = sceneId,sceneUid = sceneUid}
end

function leaveScene(self,args)

end