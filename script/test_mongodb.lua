local event = require "event"
local mongo = require "mongo"
local model = require "model"
local dbObject = import "module.database_object"



model.registerValue("db_channel")

local db_channel,reason = event.connect("tcp://127.0.0.1:10105",4,true,mongo)
if not db_channel then
	os.exit()
end
db_channel:init()

model.set_db_channel(db_channel)

local db = dbObject.cDatabaseCommon:new(10)

event.fork(function ()
	local data = db:load("role",{id = 1})
	table.print(data)

	data.name = "fuck.mrq"
	db:dirty_collection(data)
end)
