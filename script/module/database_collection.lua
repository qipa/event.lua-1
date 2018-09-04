local object = import "module.object"

--对应着mongodb中的文档集合(collection)概念
cls_collection = object.cls_base:inherit("database_collection")
cls_collection_set = object.cls_base:inherit("database_collection_set")

function __init__(self)
	self.cls_collection:save_field("__name")
end

function cls_collection:dirty_field(field)
	self.__dirty[field] = true
	self.__dirty["__name"] = true
	if self.__parent then
		self.__parent:dirty_field(self)
	end
end

function cls_collection:load(parent,db_channel,db,db_index)
	local name = self.__name
	local result = db_channel:findOne(db,name,{query = db_index})
	if result then
		assert(name == result.__name)
		local obj = class.instance_from(name,result)
		obj.__parent = parent
		return obj
	end
end

function cls_collection:save(db_channel,db,db_index)
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
		db_channel:update(db,self.__name,db_index,updater,true)
	end
end


function cls_collection_set:dirty_field(field)
	self.__dirty[field] = true
	self.__parent:dirty_field(self)
end

function cls_collection_set:load(parent,db_channel,db,db_index)
	local name = self.__name
	local result = db_channel:findAll(db,name,{query = db_index})
	if result then
		local instance = self:new()
		instance.slots = {}

		for _,tbl in pairs(result) do
			local obj = class.instance_from(tbl.__name,tbl)
			instance.slots[obj.uid] = obj
		end
		instance.__parent = parent
		return instance
	end
end

function cls_collection_set:save(db_channel,db,db_index)
	for field in pairs(self.__dirty) do
		local data = self.slots[field]
		if data then
			local updater = {}
			updater["$set"] = data
			db_channel:update(db,data.__name,db_index,updater,true)
		else
			db_channel:delete(db,data.__name,{uid = field})
		end
	end
	self.__dirty = {}
end
