local b3 = import "module.scene.ai.bt.bt_const"
local composite = import "module.scene.ai.bt.core.Composite"

cBtMemPriority = composite.cBtComposite:inherit("btMemPriority")

function cBtMemPriority:ctor(params)
	super(cBtMemPriority).ctor(self,params)
end

function cBtMemPriority:open(tick)
	tick.blackboard:set("runningChild", 1, tick.tree.id, self.id)
	return super(cBtMemPriority).open(self,tick)
end

function cBtMemPriority:tick(tick)
	local child = tick.blackboard:get("runningChild", tick.tree.id, self.id)
	
	for i = child,#self.children do
		local node = self.children[i]
		local status = node:_execute(tick)

		if status ~= b3.FAILURE then
			if status == b3.RUNNING then
				tick.blackboard:set("runningChild", i, tick.tree.id, self.id)
			end
			
			return status
		end
	end

	return b3.FAILURE
end