local util = require "util"
local event = require "event"
local mongo = require "mongo"
local model = require "model"

model.registerValue("db_channel")
local db_channel,reason = event.connect(env.mongodb,4,true,mongo)
if not db_channel then
	print(string.format("%s connect db:%s faield:%s",env.name,env.mongodb,reason))
	os.exit()
end

model.set_db_channel(db_channel)

event.fork(function ()
	local buidler = import "module.id_builder"
buidler:init(env.serverId,1)

	print(buidler.alloc_user_uid())
	print(buidler.alloc_item_uid())
	print(buidler.alloc_scene_uid())
	print(buidler.pop_monster_tid())
end)
