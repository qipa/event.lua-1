local event = require "event"
local mongo = require "mongo"
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


for i = 1,1000 do
	local item = {cid = 100,amount = 1000,uid = i,userUid = 2,__name = "item"}
	db_channel:insert("user","item_mgr",item)
end


local itemMgr = itemMgr.cItemMgr:new()

event.fork(function ()


itemMgr:load(nil,db_channel,"user",{userUid = 2})
itemMgr:insertItemByCid(100,100)
end)
