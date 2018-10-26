local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtAction = baseNode.cBtBaseNode:inherit("btAction")

function cBtAction:ctor()
	super(cBtAction).ctor(self)
	self.category = b3.ACTION
end

