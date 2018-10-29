local event = require "event"
local BT_CONST = import "module.scene.ai.bt.bt_const"

cBtRepeatUntilSuccess = import("module.scene.ai.bt.core.Decorator").cBtDecorator:inherit("btRepeatUntilSuccess")

function cBtRepeatUntilSuccess:ctor(params)
	super(cBtRepeatUntilSuccess).ctor(self,params)
	self.maxLoop = params.properties.maxLoop or -1
end

function cBtRepeatUntilSuccess:open(tick)
	tick.blackboard.set("i", 0, tick.tree.id, self.id)
	return super(cBtRepeatUntilSuccess).open(self,tick)
end

function cBtRepeatUntilSuccess:tick(tick)
	if not self.child then
		return BT_CONST.ERROR
	end

	local i = tick.blackboard.get("i", tick.tree.id , self.id)
	local status = BT_CONST.ERROR

	while(self.maxLoop < 0 or i < self.maxLoop)
	do
		local status = self.child:_execute(tick)

		if status == BT_CONST.FAILURE then
			i = i + 1
		else
			break
		end
	end

	i = tick.blackboard.set("i", i, tick.tree.id, self.id)
	return status
end
