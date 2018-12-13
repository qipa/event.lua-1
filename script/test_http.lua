local http = require "http"
local event = require "event"
local cjson = require "cjson"
local helper = require "helper"
local count = 0

event.fork(function ()
    local httpd,reason = http.listen(env.world_http,function (channel,method,url,header,body)
        event.fork(function ()
            print(method,url,body)
            channel:reply(200,"ok")
        end)

    end)
    if not httpd then
        event.error(string.format("world http listen:%s failed:%s",env.world_http,reason))
        os.exit(1)
    end
    event.error(string.format("world http listen:%s success",env.world_http))

    local get_count = 0
local post_count = 0
local count = 1
local ti = event.now()
for i = 1,count do
    http.get("localhost","/mrq/a/b/c",{},{},"./world_http.ipc",function (header,content)
        get_count = get_count + 1
        if get_count == count then
            print("get diff",event.now() - ti)
        end
    end)

    -- http.post("127.0.0.1:1989","/mrq/a/b/c",{},{"mrq"},function (header,content)
    --      post_count = post_count + 1
    --     if post_count == count then
    --         print("post diff",event.now() - ti)
    --     end
    -- end)
end
end)



event.fork(function ()
    while true do
        event.sleep(1)
        print(collectgarbage("count"),(helper.allocated()/1024))
    end
end)
