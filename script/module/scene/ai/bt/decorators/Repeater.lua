local event = require "event"
local BT_CONST = import "module.scene.ai.bt.bt_const"

cBtRepeater = import("module.scene.ai.bt.core.Decorator").cBtDecorator:inherit("btRepeater")

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
		return BT_CONST.ERROR
	end

	local i = tick.blackboard:get("i", tick.tree.id , self.id)
	local status = BT_CONST.SUCCESS

	while(self.maxLoop < 0 or i < self.maxLoop)
	do
		local status = self.child:_execute(tick)
		if status == BT_CONST.SUCCESS or status == BT_CONST.FAILURE then
			i = i + 1
		else
			break
		end
	end

	i = tick.blackboard:set("i", i, tick.tree.id, self.id)
	return status
end
