


local util = require "util"

local FILE = io.open("./event","rb")
local content = FILE:read("*a")
FILE:close()

local out
local count = 100
util.time_diff("compress",function ()
	for i = 1,count do
		out = util.zlib_compress(content)
	end
end)

util.time_diff("uncompress",function ()
	for i = 1,count do
		content = util.zlib_decompress(out,content:len())
	end
end)

util.time_diff("lz4_compress",function ()
	for i = 1,count do
		out = util.lz4_compress(content)
	end
end)


util.time_diff("lz4_uncompress",function ()
	for i = 1,count do
		content = util.lz4_decompress(out,content:len())
	end
end)

