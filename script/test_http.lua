local http = require "http"
local event = require "event"
local cjson = require "cjson"
local count = 0

event.fork(function ()
    local httpd,reason = http.listen("tcp://127.0.0.1:1989",function (channel,method,url,header,body)
        event.fork(function ()
        	print(method,url)
        	table.print(header)
        	print(body)
            local url = url:split("/")
   
              channel:reply(200,"ok")
        end)

    end)
    if not httpd then
        event.error(string.format("world http listen:%s failed:%s",env.world_http,reason))
        os.exit(1)
    end
    event.error(string.format("world http listen:%s success",env.world_http))
end)

local count = 0
for i = 1,1 do
	event.httpc_get("http://127.0.0.1:1989/mrq/a/b/c",function (header,content)
		print("rc header",header)
		print("rc content",content)
		count = count + 1
	end)

	event.httpc_post("http://127.0.0.1:1989/mrq/a/b/c","mrq",function (header,content)
		print("!!!!!!!!!!!!!!!")
		print("rc header",header)
		print("rc content",content)
		count = count + 1
	end)
end

