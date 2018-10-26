local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtSucceeder = baseNode.cBtBaseNode:inherit("btSuccessder")

function cBtSucceeder:ctor()
	super(cBtSucceeder).ctor(self)

	self.name = "Succeeder"
end

function cBtSucceeder:tick(tick)
	return b3.SUCCESS
end