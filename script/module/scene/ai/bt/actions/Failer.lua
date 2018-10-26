local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtFail = baseNode.cBtBaseNode:inherit("btFail")

function cBtFail:ctor()
	super(cBtFail).ctor(self)
	
	self.name = "Failer"
end

function cBtFail:tick()
	return b3.FAILURE
end
