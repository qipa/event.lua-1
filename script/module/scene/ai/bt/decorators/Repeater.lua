local event = require "event"
local b3 = import "module.scene.ai.bt.b3_const"
local decorator = import "module.scene.ai.bt.core.Decorator"

cBtRepeater = decorator.cBtDecorator:inherit("btRepeater")

function cBtRepeater:ctor(params)
	super(cBtRepeater).ctor(self,params)
	self.maxLoop = params.properties.maxLoop or -1
end

function cBtRepeater:open(tick)
	tick.blackboard:set("i", 0, tick.tree.id, self.id)
	return super(cBtRepeater).open(self,tick)
end

function cBtRepeater:tick(tick)
	if not self.child then
		return b3.ERROR
	end

	local i = tick.blackboard:get("i", tick.tree.id , self.id)
	local status = b3.SUCCESS

	while(self.maxLoop < 0 or i < self.maxLoop)
	do
		local status = self.child:_execute(tick)
		if status == b3.SUCCESS or status == b3.FAILURE then
			i = i + 1
		else
			break
		end
	end

	i = tick.blackboard:set("i", i, tick.tree.id, self.id)
	return status
end
