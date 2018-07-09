local model = require "model"
local object = import "module.object"

--对应着mongodb中的database概念
cls_database_common = object.cls_base:inherit("database_common")

local pairs = pairs
local type = type

function cls_database_common:save_field(field,index)
	self.__save_fields[field] = index
end


function cls_database_common:dirty_collection(field)
	self.__dirty[field] = true
end

function cls_database_common:load()
	local db_channel = model.get_db_channel()
	for field,index in pairs(self.__save_fields) do
		if not self.__alive then
			break
		end
		local result = db_channel:findOne("common","global",{query = index})
		if result then
			if result.__name then
				self[field] = class.instance_from(result.__name,result)
			else
				self[field] = result
			end
		end
	end
end

function cls_database_common:save()
	local db_channel = model.get_db_channel()

	for field in pairs(self.__dirty) do
		local db_index = self.__save_fields[field]
		if db_index ~= nil then
			local data = self[field]
			if data then
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
				db_channel:update("common","global",db_index,updater,true)
			end
		end
	end
	self.__dirty = {}
end
