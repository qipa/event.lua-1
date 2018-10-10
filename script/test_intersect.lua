local util = require "util"
local vector2 = require "common.vector2"

print(util.capsule_intersect(200,50,300,100,50,99,50,50))


print(util.rectangle_intersect(200,100,100,20,30,326,200,60))


print(util.sector_intersect(100,100,30,40,100,80,100,50))