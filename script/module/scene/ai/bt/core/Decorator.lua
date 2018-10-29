local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtDecorator = baseNode.cBtBaseNode:inherit("btDecorator")

function cBtDecorator:ctor(params)
	super(cBtDecorator).ctor(self, params)

	self.category = b3.DECORATOR
	if not params then
		params = {}
	end

	self.child = params.child or nil
end
