local util = require "util"

-- util.time_diff("rsa",function ()

-- 	for i = 1,1024 do
-- 		util.rsa_generate_key("test.pub","test.pri")
-- 	end
-- end)
print(util.rsa_generate_key("test.pub","test.pri"))

local ok,err
local str
--0.03s
util.time_diff("rsa encrypt",function ()
	for i = 1,1 do
		ok,err = util.rsa_encrypt("mrq","test.pub")
		if not ok then
			print(err)
		else
			str = ok
		end
	end
end)

--0.37s
util.time_diff("rsa decrypt",function ()
	for i = 1,1 do
		local ok,err = util.rsa_decrypt(str,"test.pri")
		if not ok then
			print(err)
		end
	end
end)



local ok,err = util.authcode("mrq","hx",os.time(), 1)
-- if not ok then
-- 	print("authcode encode error",err)
-- end
-- print(ok)
local ok,err = util.authcode(ok,"hx",os.time(),0)

-- if not ok then
-- 	print("authcode decode error",err)
-- end

-- print(ok)