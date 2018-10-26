local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtRunner = baseNode.cBtBaseNode:inherit("btRunner")

function cBtRunner:ctor()
	super(cBtRunner).ctor(self)

	self.name = "Runner"
end

function cBtRunner:tick(tick)
	if self.operation then
		return tick.target[self.operation](tick.target)
	end
	return b3.SUCCESS
end
