local event = require "event"
local util = require "util"

local strFm = string.format
local tostring = tostring
local osTime = os.time
local osData = os.date

_logCtx = _logCtx or {}

function __init__(self)

end

function log(_,args)
	local logLevel = args.logLevel
	local logName = args.logName
	local logTag = args.logTag
	local source = args.source
	local line = args.line
	
	local log
	local fm = args.fm
	if fm then
		log = strFm(fm,table.unpack(args.log))
	else
		log = table.concat(args.log,"\t")
	end

	local content
	if source then
		content = strFm("[%s][%s %s%s:%d] %s\r\n",logTag,osData("%Y-%m-%d %H:%M:%S",args.time),args.server,source,line,log)
	else
		content = strFm("[%s][%s %s] %s\r\n",logTag,osData("%Y-%m-%d %H:%M:%S",args.time),args.server,log)
	end

	local FILE = _logCtx[logName]
	if env.logPath and not FILE then
		local file = string.format("%s/%s.log",env.logPath,logName)
		FILE = assert(io.open(file,"a+"))
		_logCtx[logName] = FILE
	end

	if FILE then
		FILE:write(content)
		FILE:flush()
	else
		util.print(logLevel,content)
	end
end

