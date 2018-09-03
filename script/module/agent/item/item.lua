local id_builder = import "module.id_builder"
local database_document = import "module.database_document"


cItem = database_document.cls_document:inherit("item_base")

function __init__(self)
	self.cItem:save_field("uid")
	self.cItem:save_field("cid")
	self.cItem:save_field("amount")
end

local id = 1
function cItem:create(cid,amount)
	self.cid = cid
	self.amount = amount
	self.uid = id
	id = id + 1
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
