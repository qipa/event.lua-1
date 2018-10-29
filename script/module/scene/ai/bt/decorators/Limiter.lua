local BT_CONST = import "module.scene.ai.bt.bt_const"

cBtLimiter = import("module.scene.ai.bt.core.Decorator").cBtDecorator:inherit("btLimiter")

function cBtLimiter:ctor(params)
	super(cBtLimiter).ctor(self,params)
	self.maxLoop = params.properties.maxLoop or 1
end

function cBtLimiter:open(tick)
	tick.blackboard.set("i", 0, tick.tree.id, self.id)
	return super(cBtLimiter).open(self,tick)
end

function cBtLimiter:tick(tick)
	if not self.child then
		return BT_CONST.ERROR
	end

	local i = tick.blackboard:get("i", tick.tree.id, self.id)

	if i < self.maxLoop then
		local status = self.child:_execute(tick)

		if status == BT_CONST.SUCCESS or status == BT_CONST.FAILURE then
			tick.blackboard:set("i", i+1, tick.tree.id, self.id)
		end

		return status
	end

	return BT_CONST.FAILURE
end
