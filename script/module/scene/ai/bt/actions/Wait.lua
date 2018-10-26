local event = require "event"
local b3 = import "module.scene.ai.bt.bt_const"
local baseNode = import "module.scene.ai.bt.core.BaseNode"

cBtWait = baseNode.cBtBaseNode:inherit("btWait")

function cBtWait:ctor(settings)
	b3.Action.ctor(self, settings)

	self.name = "Wait"
	self.title = "Wait <milliseconds>ms"
	self.parameters = {milliseconds = 0,}

	settings = settings or {}
end

function cBtWait:tick(tick)
	local currTime = event.now()
	local startTime = tick.blackboard:get("startTime", tick.tree.id, self.id)

	if not startTime or startTime == 0 then
		startTime = currTime
		tick.blackboard:set("startTime", currTime, tick.tree.id, self.id)
	end

	if currTime - startTime > self.endTime then
		return b3.SUCCESS
	end

	return b3.RUNNING
end
