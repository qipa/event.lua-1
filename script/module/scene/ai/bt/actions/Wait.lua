local event = require "event"
local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtWait = baseNode.cBtBaseNode:inherit("btWait")

function cBtWait:ctor(params)
	super(cBtWait).ctor(self, params)
	self.milliseconds = params.properties.milliseconds or 0
end

function cBtWait:open(tick)
	local status = super(cBtWait).open(self,tick)
	if status == b3.SUCCESS then
		tick.blackboard:set("startTime", event.now(), tick.tree.id, self.id)
	end
	return status
end

function cBtWait:tick(tick)
	local currTime = event.now()
	local startTime = tick.blackboard:get("startTime", tick.tree.id, self.id)
	if currTime - startTime > self.milliseconds then
		return b3.SUCCESS
	end

	return b3.RUNNING
end
