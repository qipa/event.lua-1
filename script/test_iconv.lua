local util = require "util"

table.print(util.iconv_list())
local cd = util.iconv_open("UTF-8","GB2312")


print(cd:execute("我是木木木木木木木木木木"))