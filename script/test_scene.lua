local event = require "event"
local mongo = require "mongo"
local idBuilder = import "module.id_builder"
local startup = import "server.startup"
local clientMgr = import "module.client_manager"
local fighter = import "module.scene.fighter"
local monster = import "module.scene.monster"
local sceneServer = import "module.scene.scene_server"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_container"
-- sceneServer:createScene(1001,1)

-- local userData = table.tostring({uid = 1,pos = {1,1}})
-- sceneServer:enterScene(userData,1,{1,1},false) 

-- local scene = sceneServer:getScene(1)

-- for i = 1,1 do
-- 	local inst = monster.cMonster:new(2,1,1)
-- 	scene:enter(inst,1,1)
-- end
--

local mongodb_channel = mongo:inherit()
function mongodb_channel:disconnect()
	os.exit(1)
end

local db_channel,reason = event.connect(env.mongodb,4,true,mongodb_channel)
if not db_channel then
	print(string.format("%s connect db:%s faield:%s",env.name,env.mongodb,reason))
	os.exit()
end

event.fork(function ()
	startup.run(false,env.mongodb,env.config)
	idBuilder:init(1)
local itemMgrInst = itemMgr.cItemMgr:load(nil,db_channel,"user",{userUid = 5})
if not itemMgrInst then
	itemMgrInst = itemMgr.cItemMgr:new()
end

itemMgrInst:insertItemByCid(100,1)
itemMgrInst:save(db_channel,"user",{userUid = 5})
table.print(itemMgr)

end)

