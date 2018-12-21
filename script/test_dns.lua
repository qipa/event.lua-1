local event = require "event"


event.dns_resolve("www.baidu.com",function (result,error)

	if result then
		table.print(result)
	else
		print(error)
	end
end)

