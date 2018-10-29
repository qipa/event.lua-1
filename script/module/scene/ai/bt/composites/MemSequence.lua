local b3 = import "module.scene.ai.bt.bt_const"
local composite = import "module.scene.ai.bt.core.Composite"

cBtMemSequence = composite.cBtComposite:inherit("btMemSequence")

function cBtMemSequence:ctor(params)
	super(cBtMemSequence).ctor(self,params)
end

function cBtMemSequence:open(tick)
	tick.blackboard:set("runningChild", 1, tick.tree.id, self.id)
	return super(cBtMemSequence).open(self,tick)
end

function cBtMemSequence:tick(tick)
	local child = tick.blackboard:get("runningChild", tick.tree.id, self.id)

	for i = child,#self.children do
		local node = self.children[i]
		local status = node:_execute(tick)

		if status ~= b3.SUCCESS then
			if status == b3.RUNNING then
				tick.blackboard:set("runningChild", i, tick.tree.id, self.id)
			end

			return status
		end
	end

	return b3.SUCCESS
end