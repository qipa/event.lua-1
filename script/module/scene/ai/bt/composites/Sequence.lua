local b3 = import "module.scene.ai.bt.bt_const"
local composite = import "module.scene.ai.bt.core.Composite"

cBtSequence = composite.cBtComposite:inherit("btSequence")

function cBtSequence:ctor()
	super(cBtSequence).ctor(self)

	self.name = "Sequence"
end

function cBtSequence:tick(tick)
	for i = 1,table.getn(self.children) do
		local v = self.children[i]
		local status = v:_execute(tick)
		print(i,v)
		if status ~= b3.SUCCESS then
			return status
		end
	end
	return b3.SUCCESS
end
