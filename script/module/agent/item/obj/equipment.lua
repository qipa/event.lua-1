local id_builder = import "module.id_builder"
local item = import "module.agent.item.obj.item"


cEquipment = item.cItem:inherit("equipment")


function cEquipment:create(cid,amount)
	self.cid = cid
	self.amount = amount
	self.uid = id_builder:alloc_item_uid()
end

function cEquipment:init()

end

function cEquipment:destroy()

end
