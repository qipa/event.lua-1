local model = require "model"
local object = import "module.object"

--对应着mongodb中的database概念
cDatabase = object.cls_base:inherit("database_object")

local pairs = pairs
local type = type

function cDatabase:dirtyField(obj)
	self.__dirty[obj.__name] = true
end

--子类重写,返回保存数据库的索引
function cDatabase:dbIndex()
	return {id = self.__uid}
end

function cDatabase:load()
	local db_channel = model.get_db_channel()
	local db = self:get_type()
	local dbIndex = self:dbIndex()
	for field in pairs(self.__save_fields) do
		if not self.__alive then
			break
		end
		local result
		local cls = class.get(field)
		if cls then
			result = cls:load(db_channel,db,dbIndex)
		else
			result = db_channel:findOne(db,field,{query = dbIndex})
		end
		self[field] = result
	end
end

function cDatabase:save()
	local db_channel = model.get_db_channel()
	local db = self:get_type()
	for field in pairs(self.__dirty) do
		if self.__save_fields[field] ~= nil then
			local data = self[field]
			if data then
				if type(data) == "table" then
					if data.save then
						data:save(db_channel,db,self:dbIndex())
					else
						local updater = {}
						updater["$set"] = data
						db_channel:update(db,field,self:dbIndex(),updater,true)
					end
				end
			end
		end
	end
	self.__dirty = {}
end
