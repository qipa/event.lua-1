local event = require "event"
local util = require "util"
local model = require "model"
local protocol = require "protocol"
local mongo = require "mongo"
local cjson = require "cjson"
local route = require "route"
local http = require "http"
local channel = require "channel"
local startup = import "server.startup"
local server_manager = import "module.server_manager"
local world_server = import "module.world.world_server"
local id_builder = import "module.id_builder"
local mongo_indexes = import "common.mongo_indexes"

event.fork(function ()
    local httpd,reason = http.listen(env.world_http,function (channel,method,url,header,body)
        event.fork(function ()
            local url = url:split("/")
            local func = url[#url]
            local file = table.concat(url,".",1,#url-1)
            if body ~= "" then
                body = cjson.decode(body)
            end
            local ok,info = pcall(route.dispatch,file,func,channel,body)
            local str = cjson.encode(info)
            if not ok then
                channel:reply(404,info)
            else
                channel:reply(200,str)
            end
        end)

    end)
    if not httpd then
        event.error(string.format("world http listen:%s failed:%s",env.world_http,reason))
        os.exit(1)
    end
    event.error(string.format("world http listen:%s success",env.world_http))
end)


event.fork(function ()
	env.distId = server_manager:reserveId()
	startup.run(env.serverId,env.distId,env.monitor,env.mongodb,env.config,env.protocol)


	local listener,reason = server_manager:listenServer("world")
	if not listener then
		event.breakout(reason)
		return
	end

	world_server:start()
end)
