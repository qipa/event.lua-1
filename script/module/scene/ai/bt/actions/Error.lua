local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtError = baseNode.cBtBaseNode:inherit("btError")

function cBtError:ctor()
	b3.Action.ctor(self)
	
	self.name = "Error"
end

function cBtError:tick()
	return b3.ERROR
end
