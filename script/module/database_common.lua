local model = require "model"
local object = import "module.object"

--对应着mongodb中的database概念
cls_database_common = object.cls_base:inherit("database_common")

local pairs = pairs
local type = type

function cls_database_common:create()
	self.data_ctx = setmetatable({},{__mode = "k"})
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
			if data.save_data then
				local set,unset = data:save_data()
				if set then
					updater["$set"] = set
				end
				if unset then
					updater["$unset"] = unset
				end
			else
				updater["$set"] = data
			end
		end
		db_channel:update("common",data_info.name,data_info.index,updater,true)

	end
	self.__dirty = {}
end

function cls_database_common:save_rightnow(data)
	local data_info = self.data_ctx[data]
	self.__dirty[data] = nil
	local updater = {}
	if type(data) == "table" then
		if data.save_data then
			local set,unset = data:save_data()
			if set then
				updater["$set"] = set
			end
			if unset then
				updater["$unset"] = unset
			end
		else
			updater["$set"] = data
		end
	end
	db_channel:update("common",data_info.name,data_info.index,updater,true)
end
