
local event = require "event"
local channel = require "channel"
local cjson = require "cjson"
local http_parser = require "http.parser"

local http_status_msg = {
	[100] = "Continue",
	[101] = "Switching Protocols",
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	[307] = "Temporary Redirect",
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Time-out",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Large",
	[415] = "Unsupported Media Type",
	[416] = "Requested range not satisfiable",
	[417] = "Expectation Failed",
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Time-out",
	[505] = "HTTP Version not supported",
}

local function escape(s)
	return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
		return string.format("%%%02X", string.byte(c))
	end))
end

local function decode_func(c)
	return string.char(tonumber(c, 16))
end

local function decode(str)
	local str = str:gsub('+', ' ')
	return str:gsub("%%(..)", decode_func)
end

local function encode_func(c)
	return string.format("%%%02X",string.byte(c))
end

local function url_parse(u)
	local path,query = u:match "([^?]*)%??(.*)"
	if path then
		path = decode(path)
	end
	return path, query
end

local function url_parse_query(q)
	local r = {}
	for k,v in q:gmatch "(.-)=([^&]*)&?" do
		r[decode(k)] = decode(v)
	end
	return r
end

local function url_encode(t)
	local result = {}
	for k,v in pairs(t) do
		table.insert(result, string.format("%s=%s",escape(k),escape(v)))
	end
	return table.concat(result,"&")
end

local httpd_channel = channel:inherit()

function httpd_channel:init()
	self.parser = http_parser.new(0)
	self.response = {header = {}}
	self.cookie = {}
end

function httpd_channel:dispatch(method,url,header,body)
	self.callback(self,method,url,header,body)
end

function httpd_channel:data()
	local data = self:read()
	local ok,more,request = self.parser:execute(data)
	if not ok then
		event.error(string.format("httpd parser error:%s",more))
		self:close_immediately()
		return
	end
	
	if not more then
		self:dispatch(request.method,request.url,request.header,request.body)
		return
	end
end

function httpd_channel:set_header(k,v)
	self.response.header[k] = v
end

function httpd_channel:set_cookie(k,v)
	self.cookie[k] = v
end

function httpd_channel:session_expire(time)
	self.cookie["expire"] = time
end

function httpd_channel:reply(statuscode,info)
	local content = {}
	local statusline = string.format("HTTP/1.1 %03d %s\r\n", statuscode, http_status_msg[statuscode] or "")
	table.insert(content,statusline)
	if next(self.cookie) then
		local list = {}
		for k,v in pairs(self.cookie) do
			table.insert(list,string.format("%s=%s",k,v))
		end
		self.response.header["Set-Cookie"] = table.concat(list,";")
	end
	for k,v in pairs(self.response.header) do
		table.insert(content,string.format("%s: %s\r\n", k,v))
	end

	if info then
		table.insert(content,string.format("Content-Length: %d\r\n\r\n", #info))
		table.insert(content,info)
	else
		table.insert(content,"\r\n")
	end
	self.channel_buff:write(table.concat(content,""))
	self:close()
end

local httpc_channel = channel:inherit()

function httpc_channel:init()
	self.parser = http_parser.new(1)
end

function httpc_channel:disconnect()
end

function httpc_channel:dispatch(status,body)
	-- self:close_immediately()
	if self.callback then
		self.callback(self,status,body)
	else
		event.wakeup(self.session,body)
	end
end

function httpc_channel:data()
	local data = self:read()
	local ok,more,response = self.parser:execute(data)

	if not ok then
		event.error(string.format("httpd parser error:%s",more))
		self:close_immediately()
		return
	end
	
	if not more then
		self:dispatch(response.status,response.body)
		return
	end
end

local _M = {}


function _M.listen(addr,callback)
	return event.listen(addr,0,function (listener,channel)
		channel.callback = callback
	end,httpd_channel,true)
end

function _M.post(host,url,header,form,callback)
	local header_content = {}
	for k,v in pairs(header) do
		table.insert(header_content,k..":"..v)
	end

	event.httpc_post(string.format("http://%s%s",host,url),header_content,url_encode(form),callback)
end

function _M.get(host,url,header,form,callback)
	local header_content = {}
	for k,v in pairs(header) do
		table.insert(header_content,k..":"..v)
	end

	url = url..url_encode(form)

	event.httpc_get(string.format("http://%s%s",host,url),header_content,callback)
end

function _M.post_world(method,content)
	local url = method
	local header = header or {}
	header["Content-Type"] = "application/json"
	local channel,err = event.connect(env.world_http,0,false,httpc_channel)
	if not channel then
		return false,err
	end
	channel.session = event.gen_session()

	local header_content = ""
	for k,v in pairs(header) do
		header_content = string.format("%s%s:%s\r\n", header_content, k, v)
	end

	if content then
		content = cjson.encode(content)
		local data = string.format("%s %s HTTP/1.1\r\n%sContent-Length:%d\r\n\r\n", "POST", url, header_content, #content)
		channel.channel_buff:write(data)
		channel.channel_buff:write(content)
	else
		local data = string.format("%s %s HTTP/1.1\r\n%sContent-Length:0\r\n\r\n", "POST", url, header_content)
		channel.channel_buff:write(data)
	end

	local result = event.wait(channel.session)
	return cjson.decode(result)
end

_M.url_encode = url_encode
_M.url_parse = url_parse
_M.url_parse_query = url_parse_query
return _M