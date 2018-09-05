local id_builder = import "module.id_builder"
local item = import "module.agent.item.obj.item"


cPet = item.cItem:inherit("pet")


function cPet:create(cid,amount)
	self.cid = cid
	self.amount = amount
	self.uid = id_builder:alloc_item_uid()
end

function cPet:init()

end

function cPet:destroy()

end
