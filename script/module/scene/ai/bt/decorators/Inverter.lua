local b3 = import "module.scene.ai.bt.bt_const"
local decorator = import "module.scene.ai.bt.core.Decorator"

cBtInverter = decorator.cBtDecorator:inherit("btInverter")

function cBtInverter:ctor(params)
	super(cBtInverter).ctor(self,params)
end

function cBtInverter:tick(tick)
	if not self.child then
		return b3.ERROR
	end

	local status = self.child:_execute(tick)

	if status == b3.SUCCESS then
		status = b3.FAILURE
	elseif status == b3.FAILURE then
		status = b3.SUCCESS
	end

	return status
end
