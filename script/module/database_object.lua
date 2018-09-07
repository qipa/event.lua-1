local model = require "model"
local object = import "module.object"

local pairs = pairs
local type = type


--对应着mongodb中的database概念
cDatabase = object.cObject:inherit("database_object")
cCollection = object.cObject:inherit("database_collection")
cDatabaseCommon = object.cObject:inherit("database_common")

function __init__(self)
	self.cCollection:saveField("__name")
end

------------------database-------------------
function cDatabase:dirtyField(field)
	self.__dirty[field] = true
end

--子类重写,返回保存数据库的索引
function cDatabase:dbIndex()
	return {id = self.__uid}
end

function cDatabase:init(obj,name)
	local name = obj.__name or name
	assert(name ~= nil)
	self[name] = obj
	obj:attachDb(self)
end

function cDatabase:load()
	local dbChannel = model.get_db_channel()
	local db = self:getType()
	local dbIndex = self:dbIndex()
	for field in pairs(self.__saveFields) do
		local result
		local cls = class.get(field)
		if cls then
			result = cls:load(self,dbChannel,db,dbIndex)
		else
			result = dbChannel:findOne(db,field,{query = dbIndex})
		end
		self[field] = result
	end
end

function cDatabase:save()
	local dbChannel = model.get_db_channel()
	local db = self:getType()
	for field in pairs(self.__dirty) do
		if self.__saveFields[field] ~= nil then
			local data = self[field]
			if data then
				if type(data) == "table" then
					if data.save then
						data:save(dbChannel,db,self:dbIndex())
					else
						local updater = {}
						updater["$set"] = data
						dbChannel:update(db,field,self:dbIndex(),updater,true)
					end
				end
			end
		end
	end
	self.__dirty = {}
end

---------------databaseCommon------------------------
function cDatabaseCommon:ctor(interval)
	self.dataMgr = setmetatable({},{__mode = "k"})
	assert(dbCommonInst == nil)
	dbCommonInst = self
	if interval < 1 then
		interval = 1
	end
end

function cDatabaseCommon:dirtyField(field)
	self.__dirty[field] = true
end

function cDatabaseCommon:init(obj,name,dbIndex)
	local name = obj.__name or name
	self.dataMgr[obj] = {name = name,dbIndex = dbIndex}
end

function cDatabaseCommon:load(name,dbIndex)
	local dbChannel = model.get_db_channel()

	local result
	local cls = class.get(name)
	if cls then
		result = cls:load(self,dbChannel,"common",dbIndex)
	else
		result = dbChannel:findOne("common",name,{query = dbIndex})
	end
	if result then
		self.dataMgr[result] = {name = name,dbIndex = dbIndex}
	end
	return result
end

function cDatabaseCommon:save()
	local dbChannel = model.get_db_channel()

	for data in pairs(self.__dirty) do
		local dataInfo = self.dataMgr[data]
		local updater = {}
		if type(data) == "table" then
			if data.save then
				data:save(dbChannel,"common",dataInfo.dbIndex)
			else
				local updater = {}
				updater["$set"] = data
				dbChannel:update("common",field,dataInfo.dbIndex,updater,true)
			end
		end
	end
	self.__dirty = {}
end

function cDatabaseCommon:saveRightnow(data)
	local dbChannel = model.get_db_channel()

	local dataInfo = self.dataMgr[data]
	self.__dirty[data] = nil
	local updater = {}
	if type(data) == "table" then
		if data.save then
			data:save(dbChannel,"common",dataInfo.dbIndex)
		else
			local updater = {}
			updater["$set"] = data
			dbChannel:update("common",field,dataInfo.dbIndex,updater,true)
		end
	end
end

function cDatabaseCommon:insert(name,data)
	local dbChannel = model.get_db_channel()
	dbChannel:insert("common",name,data)
end

---------------collection--------------

function cCollection:dirtyField(field)
	self.__dirty[field] = true
	self.__dirty["__name"] = true
	if self.__dbObject then
		self.__dbObject:dirtyField(self.__name)
	end
end

function cCollection:dirtyAll()
	local saveFields = self.__saveFields
	for field in pairs(saveFields) do
		self.__dirty[field] = true
	end
	self.__dirty["__name"] = true
	if self.__dbObject then
		self.__dbObject:dirtyField(self.__name)
	end
end

function cCollection:attachDb(dbObject)
	self.__dbObject = dbObject
end

function cCollection:load(parent,dbChannel,db,dbIndex)
	local name = self.__name
	local result = dbChannel:findOne(db,name,{query = dbIndex})
	if result then
		assert(name == result.__name)
		local obj = class.instanceFrom(name,result)
		obj.__dbObject = parent
		return obj
	end
end

function cCollection:save(dbChannel,db,dbIndex)
	local saveFields = self.__saveFields
	local set
	local unset
	for field in pairs(self.__dirty) do
		if saveFields[field] ~= nil then
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
