local event = require "event"
local model = require "model"

local serverMgr = import "module.server_manager"
local idBuilder = import "module.id_builder"

_sceneServerMgr = _sceneServerMgr or {}
_sceneMgr = _sceneMgr or {}
_sceneUid2Inst = _sceneUid2Inst or {}

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
	return sceneUid
end

function onServerDown(self,name,serverId)

end

function onAgentConnectScene(self,args)

end

function enterScene(self,fighter,sceneId,sceneUid)
	local sceneInfo = _sceneMgr[args.sceneId]
	if not sceneInfo then
		sceneInfo = {}
		_sceneMgr[args.sceneId] = sceneInfo
	end

	local needCreate = false
	if not sceneUid or not _sceneUid2Inst[sceneUid] then
		needCreate = true
	end
end

function leaveScene(self,args)

end