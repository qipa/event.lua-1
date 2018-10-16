local idBuilder = import "module.id_builder"
local item = import "module.agent.item.obj.item"


cEquipment = item.cItem:inherit("equipment")


function cEquipment:create(cid,amount)
	self.cid = cid
	self.amount = amount
	self.uid = idBuilder:allocItemUid()
end

function cEquipment:init()

end

function cEquipment:destroy()

end
--[[
itemAttr = {
	int key
	int value
}
itemExtraInfo = {
	itemAttr[] attrInfo
}
sItemInfo = {
	itemBaseInfo baseInfo
	itemExtraInfo extraInfo
}
]]
function cEquipment:getExtraInfo()

end
