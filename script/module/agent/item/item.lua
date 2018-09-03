local id_builder = import "module.id_builder"
local dbCollection = import "module.database_collection"


cItem = dbCollection.cls_collection:inherit("item_base")

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
