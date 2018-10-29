local BT_CONST = import "module.scene.ai.bt.bt_const"

cBtMemSequence = import("module.scene.ai.bt.core.Composite").cBtComposite:inherit("btMemSequence")

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

		if status ~= BT_CONST.SUCCESS then
			if status == BT_CONST.RUNNING then
				tick.blackboard:set("runningChild", i, tick.tree.id, self.id)
			end

			return status
		end
	end

	return BT_CONST.SUCCESS
end