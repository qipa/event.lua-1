local event = require "event"
local BT_CONST = import "module.scene.ai.bt.bt_const"

cBtWait = import("module.scene.ai.bt.core.Action").cBtAction:inherit("btWait")

function cBtWait:ctor(params)
	super(cBtWait).ctor(self, params)
	self.milliseconds = params.properties.milliseconds or 0
end

function cBtWait:open(tick)
	local status = super(cBtWait).open(self,tick)
	if status == BT_CONST.SUCCESS then
		tick.blackboard:set("startTime", event.now(), tick.tree.id, self.id)
	end
	return status
end

function cBtWait:tick(tick)
	local currTime = event.now()
	local startTime = tick.blackboard:get("startTime", tick.tree.id, self.id)
	if currTime - startTime > self.milliseconds then
		return BT_CONST.SUCCESS
	end

	return BT_CONST.RUNNING
end
