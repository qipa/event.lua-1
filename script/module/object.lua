local event = require "event"
local util = require "util"
local model = require "model"
local timer = require "timer"

local pairs = pairs
local setmetatable = setmetatable
local type = type

objectId = objectId or 0 

classCtx = classCtx or {}

objectCtx = objectCtx or {}
objectMgr = objectMgr or setmetatable({},{__mode = "v"})

cObject = cObject or { __name = "root", __childs = {}}

classCtx[cObject.__name] = cObject

local function _cleanClsFunc(cls)
	for name in pairs(cls.__childs) do
		local childCls = classCtx[name]
		for method in pairs(childCls.__method) do
			childCls[method] = nil
		end
		childCls.__method = {}
		
		_cleanClsFunc(childCls)
	end
end

local function _resetObjectMeta(name)
	local cls = classCtx[name]
	local objectSet = objectCtx[name]
	if not objectSet then
		return
	end
	for object in pairs(objectSet) do
		setmetatable(object,{__index = cls})
	end
end

function cObject:inherit(name,...)
	local parent = classCtx[self.__name]

	local cls = {}
	cls.__name = name
	cls.__parent = parent.__name
	cls.__childs = {}
	cls.__method = {}
	cls.__saveFields = {}
	cls.__packFields = {}

	if parent.__saveFields then
		for f in pairs(parent.__saveFields) do
			cls.__saveFields[f] = true
		end
	end
	if parent.__packFields then
		for f in pairs(parent.__packFields) do
			cls.__packFields[f] = true
		end
	end

	cls.__packFields["__name"] = true

	assert(name ~= parent.__name)

	local meta = { __index = function (obj,method)
		local func = parent[method]
		cls.__method[method] = true
		cls[method] = func
		return func
	end}

	local oCls = classCtx[name]
	classCtx[name] = setmetatable(cls,meta)

	if oCls ~= nil then
		--热更
		_cleanClsFunc(oCls)

		for name in pairs(oCls.__childs) do
			local childCls = classCtx[name]
			local childCls = setmetatable(childCls,{ __index = function (obj,method)
				local func = cls[method]
				childCls.__method[method] = true
				childCls[method] = func
				return func
			end})
		end

		_resetObjectMeta(name)
	else
		if select("#",...) > 0 then
			model.registerBinder(name,...)
		end
	end
	parent.__childs[name] = true

	return cls
end

function cObject:getType()
	return self.__name
end

local function _allocObjectId()
	if objectId >= math.maxinteger then
		objectId = 0 
	end
	objectId = objectId + 1
	while objectMgr[objectId] do
		objectId = objectId + 1
	end
	return objectId
end

local function _newObject(self,object)
	object.__objectId = _allocObjectId() 
	object.__name = self.__name
	object.__dirty = {}

	setmetatable(object,{__index = self})

	local objectType = self.__name
	local objectSet = objectCtx[objectType]
	if objectSet == nil then
		objectSet = setmetatable({},{__mode = "k"})
		objectCtx[objectType] = objectSet
	end
	objectSet[object] = {createTime = os.time(),debugInfo = nil}
	objectMgr[object.__objectId] = object
end


function cObject:new(...)
	local object = {}
	local self = classCtx[self.__name]
	_newObject(self,object)

	object:ctor(...)

	return object
end

function cObject:instanceFrom(object)
	local objectType = self:getType()
	local class = classCtx[objectType]
	_newObject(class,object)
	return object
end

function cObject:release()
	timer.removeAll(self)
	self:onDestroy()
end

--子类重写
function cObject:ctor()

end

--子类重写
function cObject:onCreate(...)

end

--子类重写
function cObject:onDestroy()

end

function cObject:setDebugInfo(info)
	local objectSet = objectCtx[self.__name]
	objectSet[self].debugInfo = info
end

function cObject:packData()
	local cls = class.get(self.__name)
	local packFields = cls.__packFields
	local saveFields = cls.__saveFields
	local result = {}
	for k,v in pairs(self) do
		if packFields[k] or saveFields[k] then
			result[k] = v
		end
	end
	return result
end

function cObject:saveData()
	local cls = class.get(self.__name)
	local saveFields = cls.__saveFields
	local result = {}
	for k,v in pairs(self) do
		if saveFields[k] then
			result[k] = v
		end
	end
	return result
end

function cObject:saveField(field)
	self.__saveFields[field] = true
end

function cObject:packField(field)
	self.__packFields[field] = true
end

function cObject:registerEvent(ev,inst,method)
	if not self.__event then
		self.__event = {}
	end

	local evList = self.__event[ev]
	if not evList then
		evList = setmetatable({},{__mode = "k"})
		self.__event[ev] = evList 
	end
	evList[inst] = method
end

function cObject:deregisterEvent(inst,ev)
	local evList = self.__event[ev]
	if not evList then
		return
	end
	evList[inst] = nil
end

function cObject:fireEvent(ev,...)
	if not self.__event then
		return
	end
	local evList = self.__event[ev]
	if not evList then
		return
	end
	for inst,method in pairs(evList) do
		local func = inst[method]
		if not func then
			event.error(string.format("fire event error,no such method:%s",method))
		else
			local ok,err = xpcall(func,debug.traceback,inst,self,...)
			if not ok then
				event.error(err)
			end
		end
	end
end

class = {}

function class.new(name,...)
	local cls = class.get(name)
	return cls:new(...)
end

local function instanceSubobject(inst)
	for k,v in pairs(inst) do
		if type(v) == "table" then
			if v.__name then
				inst[k] = class.instanceFrom(v.__name,v)
			else
				instanceSubobject(v)
			end
		end
	end
end

function class.instanceFrom(name,data)
	local cls = class.get(name)
	assert(cls ~= nil,name)
	local inst = cls:instanceFrom(data)
	instanceSubobject(inst)
	return inst
end

function class.get(name)
	return classCtx[name]
end

function class.super(object)
	local cls = classCtx[object.__name]
	return classCtx[cls.__parent]
end

function class.objectInfo(name,objectId,...)
	local object = objectMgr[objectId]
	if not object then
		return
	end
	
	local result = object
	for i = 1, select('#',...) do
		local member = select(i,...)
		if not result[member] then
			result = result[tonumber(member)]
		end
	end
	return result
end

function class.countObject(name)
	collectgarbage("collect")

	if not name then
		for name,objectSet in pairs(objectCtx) do
			local count = 0
			for _,_ in pairs(objectSet) do
				count = count + 1
			end
			print(string.format("objectType=%s,amount=%d",name,count))
		end
	else
		local objectSet = objectCtx[name]
		if not objectSet then
			return
		end

		local count = 0
		for _,_ in pairs(objectSet) do
			count = count + 1
		end
		print(string.format("objectType=%s,amount=%d",name,count))
	end
end

function class.countObjectVerbose(name)
	local objectSet = objectCtx[name]
	if not objectSet then
		return
	end
	collectgarbage("collect")

	local count = 0
	for object,info in pairs(objectSet) do
		count = count + 1
		print(string.format("object:%s,createTime:%s,debugInfo:%s",object,os.date("%m-%d %H:%M:%S",math.floor(info.__createTime/100)),info.debugInfo or "unknown"))
	end
end

rawset(_G,"class",class)
rawset(_G,"super",class.super)
