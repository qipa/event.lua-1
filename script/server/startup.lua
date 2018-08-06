
local event = require "event"
local model = require "model"
local channel = require "channel"
local mongo = require "mongo"
local protocol = require "protocol"
local monitor = require "monitor"
local util = require "util"
local http = require "http"
local logger = require "module.logger"

local server_manager = import "module.server_manager"

local mongodb_channel = mongo:inherit()
function mongodb_channel:disconnect()
	model.set_db_channel(nil)
	os.exit(1)
end

function run(monitor_collect,db_addr,config_path,protocol_path)
	
	local runtime_logger = logger:create("runtime",5)
	event.error = function (...)
		runtime_logger:ERROR(...)
	end

	if monitor_collect then
		monitor.start()
	end

	if config_path then
		_G.config = {}

		local list = util.list_dir(config_path,true,"lua",true)

		for _,path in pairs(list) do

			local file = table.remove(path:split("/"))
			local name = file:match("%S[^%.]+")
			local data = loadfile(path)()
			_G.config[name] = data
		end
	end

	if protocol_path then
		local list = util.list_dir(protocol_path,true,"protocol",true)
		for _,file in pairs(list) do
			protocol.parse(file)
		end
	end

	if db_addr then
		model.register_value("db_channel")
		local db_channel,reason = event.connect(db_addr,4,true,mongodb_channel)
		if not db_channel then
			print(string.format("%s connect db:%s faield:%s",env.name,env.mongodb,reason))
			os.exit()
		end
		model.set_db_channel(db_channel)
		event.error(string.format("connect mongodb:%s success",db_addr))
	end
end

function reserve_id()
	local result,reason = http.post_world("/module/server_manager/reserve_id/")
	while not result do
		result,reason = http.post_world("/module/server_manager/reserve_id/")
		if not result then
			event.sleep(1)
		end
	end
	return tonumber(result)
end

function agent_amount()
	return server_manager:call_world("module.server_manager","agent_amount")
end

function scene_amount()
	return server_manager:call_world("module.server_manager","scene_amount")
end
