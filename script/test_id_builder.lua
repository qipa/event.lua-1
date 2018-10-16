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

	for i = 1,1024 do
		print(buidler.alloc_user_uid())
		print(buidler.alloc_item_uid())
		print(buidler.alloc_scene_uid())
		print(buidler.alloc_monster_tid())
	end
end)
