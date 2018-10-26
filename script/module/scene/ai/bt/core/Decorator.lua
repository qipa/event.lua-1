local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtDecorator = baseNode.cBtBaseNode:inherit("btDecorator")

function cBtDecorator:ctor(params)
	super(cBtDecorator).ctor(self, params)

	if not params then
		params = {}
	end

	self.child = params.child or nil
end
