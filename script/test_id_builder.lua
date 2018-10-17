local util = require "util"
local event = require "event"
local mongo = require "mongo"
local model = require "model"

model.registerValue("dbChannel")
local dbChannel,reason = event.connect(env.mongodb,4,true,mongo)
if not dbChannel then
	print(string.format("%s connect db:%s faield:%s",env.name,env.mongodb,reason))
	os.exit()
end

model.set_dbChannel(dbChannel)

event.fork(function ()
	local buidler = import "module.id_builder"
	buidler:init(env.serverId,1)
	table.print(buidler)

	util.time_diff("alloc id",function ()
		for i = 1,1024 * 1024 do
			buidler:allocUserUid()
		end
	end)
	-- for i = 1,1024 do
	-- 	print(buidler:allocUserUid())
	-- 	print(buidler:allocItemUid())
	-- 	print(buidler:allocSceneUid())
	-- 	local monsterTid = buidler:allocMonsterTid()
	-- 	print(monsterTid)
	-- 	buidler:reclaimMonsterTid(monsterTid)
	-- end
end)
