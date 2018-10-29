local event = require "event"
local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtWait = baseNode.cBtBaseNode:inherit("btWait")

function cBtWait:ctor(params)
	super(cBtWait).ctor(self, params)
	self.milliseconds = params.properties.milliseconds or 0
end

function cBtWait:tick(tick)
	local currTime = event.now()
	local startTime = tick.blackboard:get("startTime", tick.tree.id, self.id)

	if not startTime or startTime == 0 then
		startTime = currTime
		tick.blackboard:set("startTime", currTime, tick.tree.id, self.id)
	end
	print(currTime,startTime,currTime - startTime)
	if currTime - startTime > self.milliseconds then
		return b3.SUCCESS
	end

	return b3.RUNNING
end
