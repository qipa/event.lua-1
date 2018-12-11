local http = require "http"
local event = require "event"
local cjson = require "cjson"
local count = 0
-- for i = 1,1100 do
-- 	event.fork(function ()
-- 		local form = {
-- 			data = http.url_encode({user_name = "test"}),
-- 			time = 1,
-- 			sign = "!1"
-- 		}
-- 		http.get("127.0.0.1:8082","/ApiServer/getPfSrvList/g/2?",{},form,function (_,status,body)
-- 			count = count + 1
-- 			print(status,count)

-- 		end)
-- 	end)
	
-- end


event.httpc_get("www.baidu.com",function (header,content)
	print(header)
	print(content)
end)


event.fork(function ()
	while true do
		event.sleep(10)
	end
end)
print("!!!!")