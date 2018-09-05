local object = import "module.object"

--对应着mongodb中的文档集合(collection)概念
cls_collection = object.cls_base:inherit("database_collection")


function __init__(self)
	self.cls_collection:save_field("__name")
end

function cls_collection:dirty_field(field)
	self.__dirty[field] = true
	self.__dirty["__name"] = true
	if self.__parentObj then
		self.__parentObj:dirty_field(self)
	end
end

function cls_collection:load(parent,dbChannel,db,dbIndex)
	local name = self.__name
	local result = dbChannel:findOne(db,name,{query = dbIndex})
	if result then
		assert(name == result.__name)
		local obj = class.instance_from(name,result)
		obj.__parentObj = parent
		return obj
	else
		local obj = class.new(name)
		obj.__parentObj = parent
		return obj
	end
end

function cls_collection:save(dbChannel,db,dbIndex)
	local save_fields = self.__save_fields
	local set
	local unset
	for field in pairs(self.__dirty) do
		if save_fields[field] ~= nil then
			local data = self[field]
			if data then
				if not set then
					set = {}
				end
				set[field] = data
			else
				if not unset then
					unset = {}
				end
				unset[field] = true
			end
		end
	end
	self.__dirty = {}
	local updater = {}
	local dirty = false
	if set then
		dirty = true
		updater["$set"] = set
	end
	if unset then
		dirty = true
		updater["$unset"] = unset
	end
	
	if dirty then
		dbChannel:update(db,self.__name,dbIndex,updater,true)
	end
end
