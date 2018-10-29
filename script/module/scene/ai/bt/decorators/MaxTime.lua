local event = require "event"
local b3 = import "module.scene.ai.bt.bt_const"
local decorator = import "module.scene.ai.bt.core.Decorator"

cBtMaxTime = decorator.cBtDecorator:inherit("btMaxTime")

function cBtMaxTime:ctor(params)
	super(cBtMaxTime).ctor(self,params)

	if not params or not params.properties.maxTime then
		print("maxTime parameter in MaxTime decorator is an obligatory parameter")
		return
	end
	self.maxTime = params.properties.maxTime
end

function cBtMaxTime:open(tick)
	tick.blackboard.set("startTime", event.now(), tick.tree.id, self.id)
	return super(cBtMaxTime).open(self,tick)
end

function cBtMaxTime:tick(tick)
	if not self.child then
		return b3.ERROR
	end

	local currTime = event.now()
	local startTime = tick.blackboard.get("startTime", tick.tree.id, self.id)

	local status = self.child:_execute(tick)
	if currTime - startTime > self.maxTime then
		return b3.FAILURE
	end

	return status
end
