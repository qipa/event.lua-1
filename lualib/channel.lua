local route = require "route"
local event = require "event"
local monitor = require "monitor"
local util = require "util"

local channel = {}

local xpcall = xpcall
local tinsert = table.insert
local tunpack = table.unpack
local tencode = table.encode
local tdecode = table.decode
local setmetatable = setmetatable
local pairs = pairs
local gen_session = event.gen_session

function channel:inherit()
	local children = setmetatable({},{__index = self})
	return children
end

function channel:new(buffer,addr)
	local ctx = setmetatable({},{__index = self})
	ctx.buffer = buffer
	ctx.addr = addr or "unknown"
	ctx.session_ctx = {}
	return ctx
end

function channel:init(...)

end

function channel:attach(buffer)
	self.buffer = buffer
end

function channel:disconnect()
	local list = {}
	for session,ctx in pairs(self.session_ctx) do
		if not ctx.callback then
			tinsert(list,session)
		end
	end

	table.sort(list,function (l,r)
		return l < r
	end)

	for _,session in pairs(list) do
		event.wakeup(session,false,"buffer closed")
	end
	self.session_ctx = {}
end

function channel:read(num)
	return self.buffer:read(num)
end

function channel:read_util(sep)
	return self.buffer:read_util(sep)
end

local function call_method(channel,session,file,method,args)
	local ok,result = xpcall(route.dispatch,debug.traceback,file,method,channel,args)
	if not ok then
		event.error(result)
	end
	if session ~= 0 then
		if not ok then
			channel:ret(session,false,result)
		else
			channel:ret(session,true,result)
		end
	end
end

function channel:dispatch(message,size)
	if message.ret then
		local call_ctx = self.session_ctx[message.session]
		if call_ctx.callback then
			call_ctx.callback(message.args)
		else
			event.wakeup(message.session,tunpack(message.args))
		end
		self.session_ctx[message.session] = nil
	else
		-- monitor.report_input(message.file,message.method,size)
		event.fork(call_method,self,message.session,message.file,message.method,message.args)
	end
end

function channel:data(data,size)
	local message = tdecode(data,size)
	self:dispatch(message,size)
end

function channel:send(file,method,args,callback)
	local session = 0
	if callback then
		session = gen_session()
		self.session_ctx[session] = {callback = callback}
	end

	local ptr,size = tencode({file = file,method = method,session = 0,args = args})
	self.buffer:write(ptr,size)
	
	-- monitor.report_output(file,method,size)
end

function channel:call(file,method,args)
	local session = gen_session()
	self.session_ctx[session] = {}

	local ptr,size = tencode({file = file,method = method,session = session,args = args})
	self.buffer:write(ptr,size)

	-- monitor.report_output(file,method,size)

	local ok,value = event.wait(session)
	if not ok then
		error(value)
	end
	return value
end

function channel:ret(session,...)
	local ptr,size = tencode({ret = true,session = session,args = {...}})
	self.buffer:write(ptr,size)
end

function channel:close()
	self.buffer:close(false)
end

function channel:close_immediately()
	self.buffer:close(true)
	self:disconnect()
end

return channel
