local event = require "event"
local b3 = import "module.scene.ai.bt.bt_const"
local decorator = import "module.scene.ai.bt.core.Decorator"

cBtRepeatUntilFailure = decorator.cBtDecorator:inherit("btRepeatUntilFailure")

function cBtRepeatUntilFailure:ctor(params)
	super(cBtRepeatUntilFailure).ctor(self,params)
	self.maxLoop = params.properties.maxLoop or -1
end

function cBtRepeatUntilFailure:open(tick)
	tick.blackboard.set("i", 0, tick.tree.id, self.id)
	return super(cBtRepeatUntilFailure).open(self,tick)
end

function cBtRepeatUntilFailure:tick(tick)
	if not self.child then
		return b3.ERROR
	end

	local i = tick.blackboard.get("i", tick.tree.id , self.id)
	local status = b3.ERROR

	while(self.maxLoop < 0 or i < self.maxLoop)
	do
		local status = self.child:_execute(tick)

		if status == b3.SUCCESS then
			i = i + 1
		else
			break
		end
	end

	i = tick.blackboard.set("i", i, tick.tree.id, self.id)
	return status
end
