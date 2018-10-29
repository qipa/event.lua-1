local b3 = import "module.scene.ai.bt.b3_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtError = baseNode.cBtBaseNode:inherit("btError")

function cBtError:ctor(params)
	super(cBtError).ctor(self,params)
end

function cBtError:tick()
	return b3.ERROR
end
