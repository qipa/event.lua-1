local b3 = import "module.scene.ai.bt.b3_const"
local decorator = import "module.scene.ai.bt.core.Decorator"

cBtLimiter = decorator.cBtDecorator:inherit("btLimiter")

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
		return b3.ERROR
	end

	local i = tick.blackboard:get("i", tick.tree.id, self.id)

	if i < self.maxLoop then
		local status = self.child:_execute(tick)

		if status == b3.SUCCESS or status == b3.FAILURE then
			tick.blackboard:set("i", i+1, tick.tree.id, self.id)
		end

		return status
	end

	return b3.FAILURE
end
