local helper = require "helper"
local event = require "event"
local persistence = require "persistence"
local mysqlCore = require "luasql.mysql"
local util = require "util"


local tohex = util.hex_encode
local fromhex = util.hex_decode
local MD5 = util.md5

_persistence_ctx = _persistence_ctx or {}
_cached_data = _cached_data or {}
_data_in_log = _data_in_log or {}

_mysqlSession = _mysqlSession or nil

local LOG_MAX_TO_DIST = 16 * 1024 * 1024
local LOG_PATH = "./data"
local LOG_FILE = nil

local OP = {UPDATE = 1,SET = 2}
local lru = {}


function lru:new(name,max,unload)
	local ctx = setmetatable({},{__index = self})
	ctx.head = nil
	ctx.tail = nil
	ctx.node_ctx = {}
	ctx.count = 0
	ctx.max = max or 100
	ctx.unload = unload
	ctx.name = name
	return ctx
end

function lru:insert(id)
	local node = self.node_ctx[id]
	if not node then
		self.count = self.count + 1
		node = {pre = nil,nxt = nil,id = id}
		if self.head == nil then
			self.head = node
			self.tail = node
		else
			self.head.pre = node
			node.nxt = self.head
			self.head = node
		end

		self.node_ctx[id] = node

		if self.count > self.max then
			local node = self.tail
			self.unload(self.name,node.id)
			self.tail = node.pre
			self.tail.nxt = nil
			self.count = self.count - 1
		end
	else
		if not node.pre then
			return
		end
		local pre_node = node.pre
		local nxt_node = node.nxt
		pre_node.nxt = nxt_node
		if nxt_node then
			nxt_node.pre = pre_node
		end
		node.pre = nil
		node.nxt = self.head
		self.head = node
	end
end

local function get_persistence(name)
	if not _persistence_ctx[name] then
		_persistence_ctx[name] = persistence:open(name)
	end
	return _persistence_ctx[name]
end

local function unload(name,id)
	local cached_ctx = _cached_data[name]
	cached_ctx.ctx[id] = nil
end

local function update_cached(name,id,data)
	local cached_ctx = _cached_data[name]
	if not cached_ctx then
		cached_ctx = {ctx = {},lru = lru:new(name,100,unload)}
		_cached_data[name] = cached_ctx
	end
	cached_ctx.ctx[id] = {time = os.time(), data = data}
	cached_ctx.lru:insert(id)
end

local function set_cached(name,id,setter)
	local cached_ctx = _cached_data[name]
	assert(cached_ctx ~= nil)
	local info = cached_ctx.ctx[id]
	info.time = os.time()
	for k,v in pairs(setter) do
		info.data[k] = v
	end
	cached_ctx.lru:insert(id)
end

local function find_cached(name,id)
	local cached_ctx = _cached_data[name]
	if not cached_ctx then
		return
	end
	if not cached_ctx.ctx[id] then
		return
	end
	return cached_ctx.ctx[id].data
end

--把所有从日志文件的数据，写到各自的文件中
--尽量减少磁盘的随机写，收集数据，一次性写入
local function log_recover(validate)
	local FILE = io.open(string.format("%s/data.log",LOG_PATH),"r")
	if not FILE then
		return
	end

	if FILE:seek("end") == 0 then
		FILE:close()
		os.remove(string.format("%s/data.log",LOG_PATH))
		return
	end

	FILE:seek("set")

	local need_dump_disk = {}

	while true do
		local name = FILE:read()
		if not name then
			break
		end
		local id = tonumber(FILE:read())
		local op = tonumber(FILE:read())
		local md5_origin = FILE:read()
		local size = tonumber(FILE:read())
		local content = FILE:read(size)
		FILE:read()

		if validate then
			local md5_current = tohex(MD5(content))
			if md5_origin ~= md5_current then
				util.abort("log recover failed")
			end
		end

		if op == OP.UPDATE then
			local info = need_dump_disk[name]
			if not info then
				info = {}
				need_dump_disk[name] = info
			end
			info[id] = table.decode(content)
		else
			local info = need_dump_disk[name]
			if not info then
				info = {}
				need_dump_disk[name] = info
			end

			local data = info[id]
			if data then
				data = find_cached(name,id)
				if not data then
					local fs = get_persistence(name)
					data = fs:load(id)
				end
				if data then
					info[id] = data
				end
			end
			assert(data ~= nil,id)
			local setter = table.decode(content)
			for k,v in pairs(setter) do
				data[k] = v
			end
		end
	end

	FILE:close()

	os.remove(string.format("%s/data.log",LOG_PATH))

	for name,info in pairs(need_dump_disk) do
		local fs = get_persistence(name)
		for id,data in pairs(info) do
			fs:save(id,data)
		end
	end
	_data_in_log = {}
end

local function log_flush()
	if not LOG_FILE then
		return
	end
	LOG_FILE:close()

	log_recover(false)

	LOG_FILE = assert(io.open(string.format("%s/data.log",LOG_PATH),"a+"))
end

local function log_data(name,id,data,op)
	local info = _data_in_log[name]
	if not info then
		info = {}
		_data_in_log[name] = info
	end
	info[id] = true

	if not LOG_FILE then
		LOG_FILE = assert(io.open(string.format("%s/data.log",LOG_PATH),"a+"))
	end

	local content = table.tostring(data)
	local content_size = #content
	local md5 = tohex(MD5(content))
	
	local data = {}
	table.insert(data,name)
	table.insert(data,id)
	table.insert(data,op)
	table.insert(data,md5)
	table.insert(data,content_size)
	table.insert(data,content)

	LOG_FILE:write(table.concat(data,"\n"))
	LOG_FILE:write("\n")
	LOG_FILE:flush()
end

function timeout()
	log_flush()
end

function load(args)
	local name = args.name
	local id = args.id
	local field = args.field
	
	local data = find_cached(name,id)
	if not data then
		--缓存没有数据，看看是否在最近的log里
		local info = _data_in_log[name]
		if info and info[id] then
			log_flush()
		end
		
		--从磁盘里load出来
		local fs = get_persistence(name)
		data = fs:load(id)
		if data then
			update_cached(name,id,data)
		end
	end

	if not field or next(field) == nil then
		return data
	end

	local result = {}
	for f in pairs(field) do
		result[f] = data[f]
	end

	return result
end

function update(_,args)
	local name = args.name
	local id = args.id
	local data = args.data
	update_cached(name,id,data)
	log_data(name,id,data,OP.UPDATE)
end

function set(_,args)
	local name = args.name
	local id = args.id
	local setter = args.setter
	set_cached(name,id,setter)
	log_data(name,id,setter,OP.SET)
end

function stop()
	LOG_FILE:close()
	log_recover(false)
end

function loadUser(args)
	local userUid = args.userUid

	local cursor = _mysqlSession:execute("select * from test2_tbl")

	local result = {}
	local row = cursor:fetch ({}, "a")
	table.insert(result, row)
	while row do
		row = cursor:fetch ({}, "a")
		table.insert(result, row)
	end
	return result
end

function saveUser(...)
	print(...)
end

function __init__(self)
	--启动的时候先从日志文件里恢复
	log_recover(true)
	self.timer = event.timer(10,timeout)
	_mysqlSession = mysqlCore.mysql():connect("test","root","2444cc818a3bbc06","127.0.0.1",3306)
end
