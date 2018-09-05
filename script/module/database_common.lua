local model = require "model"
local event = require "event"
local object = import "module.object"

--对应着mongodb中的database概念
cDatabaseCommon = object.cObject:inherit("database_common")

dbCommonInst = dbCommonInst or nil

local pairs = pairs
local type = type

function cDatabaseCommon:ctor(interval)
	self.dataMgr = setmetatable({},{__mode = "k"})
	assert(dbCommonInst == nil)
	dbCommonInst = self
	if interval < 1 then
		interval = 1
	end
end

function cDatabaseCommon:dirtyField(obj)
	self.__dirty[obj] = true
end

function cDatabaseCommon:load(name,index)
	local dbChannel = model.get_db_channel()

	local result = dbChannel:findOne("common",name,{query = index})
	if result then
		if result.__name then
			local obj = class.instanceFrom(result.__name,result)
			obj.__parentObj = self
			self.dataMgr[obj] = {name = name,index = index}
			return obj
		else
			self.dataMgr[result] = {name = name,index = index}
			return result
		end
	end
	return 
end

function cDatabaseCommon:save()
	local db_channel = model.get_db_channel()

	for data in pairs(self.__dirty) do
		local data_info = self.dataMgr[data]
		local updater = {}
		if type(data) == "table" then
			if data.save then
				data:save(db_channel,"common",data_info.index)
			else
				local updater = {}
				updater["$set"] = data
				db_channel:update("common",field,data_info.index,updater,true)
			end
		end
	end
	self.__dirty = {}
end

function cDatabaseCommon:save_rightnow(data)
	local db_channel = model.get_db_channel()

	local data_info = self.dataMgr[data]
	self.__dirty[data] = nil
	local updater = {}
	if type(data) == "table" then
		if data.save then
			data:save(db_channel,"common",data_info.index)
		else
			local updater = {}
			updater["$set"] = data
			db_channel:update("common",field,data_info.index,updater,true)
		end
	end
end

function cDatabaseCommon:insert(name,data)
	local db_channel = model.get_db_channel()
	db_channel:insert("common",name,data)
end