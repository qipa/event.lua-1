local model = require "model"
local object = import "module.object"

--对应着mongodb中的database概念
cls_database = object.cls_base:inherit("database_object")

local pairs = pairs
local type = type

function cls_database:dirty_field(obj)
	self.__dirty[obj.__name] = true
end

--子类重写,返回保存数据库的索引
function cls_database:db_index()
	return {id = self.__uid}
end

function cls_database:load()
	local db_channel = model.get_db_channel()
	local db = self:get_type()
	local db_index = self:db_index()
	for field in pairs(self.__save_fields) do
		if not self.__alive then
			break
		end
		local result
		local cls = class.get(field)
		if cls then
			result = cls:load(db_channel,db,db_index)
		else
			result = db_channel:findOne(db,field,{query = db_index})
		end
		self[field] = result
	end
end

function cls_database:save()
	local db_channel = model.get_db_channel()
	local db = self:get_type()
	for field in pairs(self.__dirty) do
		if self.__save_fields[field] ~= nil then
			local data = self[field]
			if data then
				if type(data) == "table" then
					if data.save then
						data:save(db_channel,db,self:db_index())
					else
						local updater = {}
						updater["$set"] = data
						db_channel:update(db,field,self:db_index(),updater,true)
					end
				end
			end
		end
	end
	self.__dirty = {}
end
