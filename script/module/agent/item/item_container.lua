local idBuilder = import "module.id_builder"
local database_collection = import "module.database_collection"
local item_factory = import "module.agent.item.item_factory"


cItemMgr = database_collection.cls_collection_set:inherit("item_mgr")

function __init__(self)
	
end


function cItemMgr:create()

end

function cItemMgr:init()
	self.helper = {}
	for uid,item in pairs(self.slots) do
		local info = self.helper[item.cid]
		if not info then
			info = {}
			self.helper[item.cid] = info
		end
		info[item.uid] = true
	end
end

function cItemMgr:destroy()

end

local function _addItem(self,item)
	if not item.uid then
		item.uid = idBuilder:alloc_item_uid()
	end
	self.slots[item.uid] = item
	local info = self.helper[item.cid]
	if not info then
		info = {}
		self.helper[item.cid] = info
	end
	info[item.uid] = true
	self:dirty_field(item.uid)
end

local function _delItem(self,item)
	self.slots[item.uid] = nil
	local helperInfo = self.helper[item.cid]
	helperInfo[item.uid] = nil
	item:destroy()
	self:dirty_field(item.uid)
end

function cItemMgr:insertItemByCid(cid,amount)

	local itemConf = config.item[cid]
	if not itemConf then
		error(string.format("no such item:%d",cid))
	end

	local left = amount
	local helperInfo = self.helper[cid]
	for uid in pairs(helperInfo) do
		local oItem = self.slots[uid]
		if itemConf.overlap > oItem.amount then
			local space = itemConf.overlap - oItem.amount
			if left < space then
				oItem.amount = oItem.amount + left
				self:dirty_field(oItem.uid)
				left = 0
				break
			else
				oItem.amount = itemConf.overlap
				self:dirty_field(oItem.uid)
				left = left - space
			end
		end
	end

	if left > 0 then
		local items = item_factory:create_item(cid,left)
		for _,item in pairs(items) do
			_addItem(self,item)
		end
	end
end

function cItemMgr:insertItem(item)
	local itemConf = config.item[item.cid]
	if itemConf.overlap > 1 then
		self:insertItemByCid(item.cid,item.amount)
		item:release()
		return
	end

	_addItem(self,item)
end

function cItemMgr:deleteItem(item)
	return self:deleteItemByUid(item.uid,item.amount)
end

function cItemMgr:deleteItemByCid(cid,amount)
	if not self:itemEnough(cid,amount) then
		return false
	end

	local helperInfo = self.helper[cid]

	local left = amount

	for uid in pairs(helperInfo) do
		if left == 0 then
			break
		end

		local oItem = self.slots[uid]
		if oItem.amount > left then
			oItem.amount = oItem.amount - left
			self:dirty_field(oItem.uid)
			left = 0
		else
			left = left - oItem.amount
			_delItem(self,oItem)
		end
	end
end

function cItemMgr:deleteItemByUid(uid,amount)
	local item = self.slots[uid]
	if item.amount > amount then
		item.amount = item.amount - amount
		self:dirty_field(uid)
	else
		_delItem(self,item)
	end
end

function cItemMgr:itemEnough(cid,amount)
	local helperInfo = self.helper[cid]
	local total = 0
	for uid in pairs(helperInfo) do
		local item = self.slots[uid]
		total = total + item.amount
	end
	return total >= amount
end
