local event = require "event"
local util = require "util"

local strformat = string.format
local tostring = tostring
local os_time = os.time
local os_date = os.date

_logCtx = _logCtx or {}

function __init__(self)

end

function log(_,args)
	local logLevel = args.logLevel
	local logType = args.logType
	local logTag = args.logTag
	local source = args.source
	local line = args.line
	
	local log = args[3]
	local FILE = _logCtx[logType]
	if not FILE then
		if env.log_path then
			local file = string.format("%s/%s.log",env.log_path,logType)
			FILE = assert(io.open(file,"a+"))
			_logCtx[logType] = FILE
		end
	end

	local content
	if source then
		content = strformat("[%s:%s][%s %s %s:%d] %s\r\n",logTag,logType,os_date("%Y-%m-%d %H:%M:%S",args.time),args.serverName,source,line,args.log)
	else
		content = strformat("[%s:%s][%s %s] %s\r\n",logTag,logType,os_date("%Y-%m-%d %H:%M:%S",args.time),args.serverName,args.log)
	end
	if FILE then
		FILE:write(content)
		FILE:flush()
	else
		util.print(logLevel,content)
	end
end

