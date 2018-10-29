local b3 = import "module.scene.ai.bt.b3_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtSucceeder = baseNode.cBtBaseNode:inherit("btSuccessder")

function cBtSucceeder:ctor(params)
	super(cBtSucceeder).ctor(self,params)
end

function cBtSucceeder:tick(tick)
	return b3.SUCCESS
end