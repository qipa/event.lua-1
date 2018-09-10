local event = require "event"
local mongo = require "mongo"
local idBuilder = import "module.id_builder"
local startup = import "server.startup"
local clientMgr = import "module.client_manager"
local fighter = import "module.scene.fighter"
local monster = import "module.scene.monster"
local sceneServer = import "module.scene.scene_server"
local itemFactory = import "module.agent.item.item_factory"
local itemContainer = import "module.agent.item.item_container"
local worldServer = import "module.world.world_server"
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
	env.dist_id = 1
	startup.run(false,env.mongodb,env.config)
	idBuilder:init(env.uid,1)
	local container = itemContainer.cItemContainer:load(nil,db_channel,"user",{userUid = 5})
	if not container then
		container = itemContainer.cItemContainer:new()
	end

	-- container:insertItemByCid(100,1)
	-- container:deleteItemByCid(100,5)
	-- container:insertItemByCid(1000,1)
	-- container:insertItemByCid(2000,1)
	container:save(db_channel,"user",{userUid = 5})
	-- table.print(container)

	worldServer:enter(1,1)
	worldServer:leave(1)
end)

