local b3 = import "module.scene.ai.bt.bt_const"
local composite = import "module.scene.ai.bt.core.Composite"

cBtMemPriority = composite.cBtComposite:inherit("btMemPriority")

function cBtMemPriority:ctor()
	super(cBtMemPriority).ctor(self)

	self.name = "MemPriority"
end

function cBtMemPriority:open(tick)
	tick.blackboard:set("runningChild", 0, tick.tree.id, self.id)
	return super(cBtMemPriority).open(self,tick)
end

function cBtMemPriority:tick(tick)
	local child = tick.blackboard:get("runningChild", tick.tree.id, self.id)
	for i,v in pairs(self.children) do
		local status = v:_execute(tick)

		if status ~= b3.FAILURE then
			if status == b3.RUNNING then
				tick.blackboard:set("runningChild", i, tick.tree.id, self.id)
			end
			
			return status
		end
	end

	return b3.FAILURE
end