local util = require "util"



local words = {"q","quit","fuck","cai"}
while true do
	print(util.readline(nil,nil,words))
end