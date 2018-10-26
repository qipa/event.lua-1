local b3 = import "module.scene.ai.bt.bt_const"
local composite = import "module.scene.ai.bt.core.Composite"

cBtPriority = composite.cBtComposite:inherit("btPriority")

function cBtPriority:ctor()
	super(cBtPriority).ctor(self)

	self.name = "Priority"
end

function cBtPriority:tick(tick)
	for i,v in pairs(self.children) do
		local status = v:_execute(tick)

		if status ~= b3.FAILURE then
			return status
		end
	end

	return b3.FAILURE
end

