local util = require "util"

-- print(util.rsa_generate_key("test.pub","test.pri"))

-- local ok,err = util.rsa_encrypt("mrq","test.pub")
-- if not ok then
-- 	print(err)
-- end

-- local ok,err = util.rsa_decrypt(ok,"test.pri")
-- if not ok then
-- 	print(err)
-- end

-- print(ok)

local ok,err = util.authcode("mrq","hx",os.time()-1, 1)
if not ok then
	print("authcode encode error",err)
end
print(ok)
local ok,err = util.authcode(ok,"hx",os.time(),0)

if not ok then
	print("authcode decode error",err)
end

-- print(ok)