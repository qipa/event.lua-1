local b3 = import "module.scene.ai.bt.b3_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtCondition = baseNode.cBtBaseNode:inherit("btCondition")

function cBtCondition:ctor(params)
	super(cBtCondition).ctor(self, params)
	self.category = b3.CONDITION
end