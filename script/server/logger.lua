local event = require "event"
local util = require "util"

local server_manager = import "module.server_manager"
import "handler.logger_handler"

event.fork(function ()
	server_manager:listen_server("logger")
end)