local model = require "model"
local event = require "event"
local object = import "module.object"

--对应着mongodb中的database概念
cls_database_common = object.cls_base:inherit("database_common")

db_common_inst = db_common_inst or nil

local pairs = pairs
local type = type

function cls_database_common:create(interval)
	self.data_ctx = setmetatable({},{__mode = "k"})
	assert(db_common_inst == nil)
	db_common_inst = self
	if interval < 1 then
		interval = 1
	end
end

function cls_database_common:dirty_collection(obj)
	self.__dirty[obj] = true
end

function cls_database_common:load(name,index)
	local db_channel = model.get_db_channel()

	local result = db_channel:findOne("common",name,{query = index})
	if result then
		if result.__name then
			local obj = class.instance_from(result.__name,result)
			self.data_ctx[obj] = {name = name,index = index}
			return obj
		else
			self.data_ctx[result] = {name = name,index = index}
			return result
		end
	end
	return 
end

function cls_database_common:save()
	local db_channel = model.get_db_channel()

	for data in pairs(self.__dirty) do
		local data_info = self.data_ctx[data]
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

function cls_database_common:save_rightnow(data)
	local db_channel = model.get_db_channel()

	local data_info = self.data_ctx[data]
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

function cls_database_common:insert(name,data)
	local db_channel = model.get_db_channel()
	db_channel:insert("common",name,data)
end