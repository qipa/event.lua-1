local util = require "util"
local vector2 = require "common.vector2"
local object = import "module.object"

cAIState = object.cObject:inherit("aiState")


function cAIState:ctor(aiCharactor)
	self.aiCharactor = aiCharactor
end

function cAIState:onCreate()
end

function cAIState:onDestroy()

end

function cAIState:onEnter()

end

function cAIState:onLeave()

end

function cAIState:onUpdate(now)

end
