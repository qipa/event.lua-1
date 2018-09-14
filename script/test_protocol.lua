local event = require "event"
local util = require "util"
local protocol = require "protocol"

-- protocol.parse("./protocol/other.protocol")
protocol.parse("./protocol/new.protocol")

-- protocol.dumpfile("./tmp/")

-- local test_protocol = {
-- 	arg1 = 1,
-- 	arglist = {1,2,3},
-- 	cmds = {{id = 1,argnum = {6,6,6},cmd = "msg"}}
-- }

-- local count = 1024 * 1024

--  local id,str =protocol.encode.c2s_command(test_protocol)
--  print(id,string.len(str))
--  local name,message = protocol.decode[id](str)
--  table.print(message,name)
 -- local now = util.time()
 -- local str
 -- for i = 1,count do
 -- 	str =protocol.encode.c2s_command(test_protocol)
 -- end
 -- print("protocol encode",util.time() - now,string.len(str))

 -- local now = util.time()
 -- for i = 1,count do
 -- 	protocol.decode.c2s_command(str)
 -- end
 -- print("protocol decode",util.time() - now,string.len(str))

-- local inner = {
-- 	file = "test.tes1t",
-- 	fields = {
-- 		[1] = {type = 0,name = "test0",array = true},
-- 		[2] = {type = 3,name = "test1",array = false},
-- 	}
-- }
-- local pto = {
-- 	file = "test.test",
-- 	fields = {
-- 		[1] = {type = 0,name = "test0",array = true},
-- 		[2] = {type = 3,name = "test1",array = false},
-- 	}
-- }

-- protocol.import("c2s_pto",pto)

-- local id,str = protocol.encode.c2s_pto({test0 = {3,1},test1 = "mrq"})
--  print(id,string.len(str))
--   local name,message = protocol.decode[id](str)
--  table.print(message,name)

protocol.dump()

local id,str = protocol.encode.sAgentEnter({a = false,b = {false,true},c = 655,d = {},e = 1000,f = {1989,10,16},g = 1.16,h = {},i = 1.1,j = {},str = "abc"})
 print(id,string.len(str))
 local name,message = protocol.decode[id](str)
 table.print(message,name)