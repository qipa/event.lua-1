local event = require "event"
local model = require "model"

local serverMgr = import "module.server_manager"
local idBuilder = import "module.id_builder"

_sceneServerMgr = _sceneServerMgr or {}
_sceneInfo = _sceneInfo or {}
_sceneMgr = _sceneMgr or {}

_agentConnectMutex = _agentConnectMutex or {}
_agentConnectInfo = _agentConnectInfo or {}

function __init__(self)
	serverMgr:registerEvent("SERVER_DOWN",self,"onServerDown")
end

function createScene(self,sceneId)
	local minServer
	local minAmount
	for serverId,info in pairs(_sceneServerMgr) do
		if not minAmount or minAmount > info.amount then
			minAmount = info.amount
			minServer = serverId
		end
	end

	local sceneUid = idBuilder:alloc_scene_uid()
	serverMgr:sendScene(minServer,"module.scene.scene_server","createScene",{sceneId = sceneId,sceneUid = sceneUid})
	local info = _sceneMgr[sceneId]
	if not info then
		info = {}
		_sceneMgr[sceneId] = info
	end

	info[sceneUid] = {amount = 0,serverId = minServer}
	_sceneInfo[sceneUid] = {amount = 0,serverId = minServer}

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
	local dbChannel = model.get_dbChannel()
	local location = dbChannel:findOne("event","fighter",{query = {userUid = args.agentUid,selector = {locationInfo = true}}})
	if not location then
		location = {

		}
	end

	self:enterScene(location.sceneId,location.sceneUid)
end

function leave(self,args)

end


function enterScene(self,fighterProxy,sceneId,sceneUid)
	local sceneInfo = _sceneInfo[sceneUid]

	local fighterInfo
	if fighterProxy.sceneUid == sceneUid then
		serverMgr:sendScene(sceneInfo.serverId,"module.scene.scene_server","enterScene",{userUid = userUid,fighterInfo = fighterProxy})
		fighterProxy:onEnterScene(sceneId,sceneUid)
		return
	else
		local oSceneInfo = _sceneInfo[fighterProxy.sceneUid]
		if oSceneInfo.serverId = sceneInfo.sceneId then
			serverMgr:sendScene(sceneInfo.serverId,"module.scene.scene_server","transferInside",{userUid = userUid,sceneUid = sceneUid})
			fighterProxy:onEnterScene(sceneId,sceneUid)
			return
		else
			fighterInfo = serverMgr:callScene(sceneInfo.serverId,"module.scene.scene_server","leaveScene",{userUid = userUid})
		end
	end

	if not self:agentConnectScene(fighterProxy.agentId,sceneInfo.serverId) then
		return
	end

	serverMgr:sendScene(sceneInfo.serverId,"module.scene.scene_server","enterScene",{userUid = userUid,fighterInfo = fighterInfo})
	fighterProxy:onEnterScene(sceneId,sceneUid)
end

function leaveScene(self,args)

end