local b3 = import "module.scene.ai.bt.b3_const"
local composite = import "module.scene.ai.bt.core.Composite"

cBtSequence = composite.cBtComposite:inherit("btSequence")

function cBtSequence:ctor(params)
	super(cBtSequence).ctor(self,params)
end

function cBtSequence:tick(tick)
	for _,v in pairs(self.children) do
		local status = v:_execute(tick)
		if status ~= b3.SUCCESS then
			return status
		end
	end
	return b3.SUCCESS
end
