local util = require "util"

local cd = util.iconv_open("UTF-8","GB2312")
-- table.print(cd:list())

print(cd:execute("我是木木木木木木木木木木"))