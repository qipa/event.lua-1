local id_builder = import "module.id_builder"
local object = import "module.object"


cItem = object.cls_object:inherit("item")

function __init__(self)
	self.cItem:save_field("uid")
	self.cItem:save_field("cid")
	self.cItem:save_field("amount")
end

function cItem:create(cid,amount)
	self.cid = cid
	self.amount = amount
end

function cItem:init()

end

function cItem:destroy()

end

function cItem:getBaseInfo()
	return {cid = self.cid,uid = self.uid,amount = self.amount}
end

function cItem:getExtraInfo()

end
