local idBuilder = import "module.id_builder"
local dbCollection = import "module.database_collection"
local itemFactory = import "module.agent.item.item_factory"


cItemMgr = dbCollection.cls_collection:inherit("item_mgr")

function __init__(self)
	self.cItemMgr:save_field("gridCount")
	self.cItemMgr:save_field("itemSlot")
end


function cItemMgr:create()

end

function cItemMgr:destroy()

end

function cItemMgr:dirtyItem(itemUid)
	if not self.__dirtyItem then
		self.__dirtyItem = {}
	end
	self.__dirtyItem[itemUid] = true
	self:dirty_field("itemSlot")
end

function cItemMgr:load(parent,dbChannel,db,dbIndex)
	dbCollection.cls_collection.load(self,parent,dbChannel,db,dbIndex)
	local itemSlot = {}
	self.helper = {}
	if self.itemSlot then
		for itemUid,item in pairs(self.itemSlot) do
			itemSlot[tonumber(itemUid)] = item
			local info = self.helper[item.cid]
			if not info then
				info = {}
				self.helper[item.cid] = info
			end
			info[item.uid] = true
		end
	end
	self.itemSlot = itemSlot
end

function cItemMgr:save(dbChannel,db,dbIndex)
	if self.__dirty["itemSlot"] then
		self.__dirty["itemSlot"] = nil
	end
	dbCollection.cls_collection.save(self,dbChannel,db,dbIndex)

	local set
	local unset 
	for itemUid in pairs(self.__dirtyItem) do
		if self.itemSlot[itemUid] then
			if not set then
				set = {}
			end
			set[string.format("itemSlot.%d",itemUid)] = self.itemSlot[itemUid]
		else
			if not unset then
				unset = {}
			end
			unset[string.format("itemSlot.%d",itemUid)] = true
		end
	end
	self.__dirtyItem = {}

	local updater = {}
	local dirty = false
	if set then
		dirty = true
		updater["$set"] = set
	end
	if unset then
		dirty = true
		updater["$unset"] = unset
	end
	
	if dirty then
		dbChannel:update(db,self.__name,dbIndex,updater,true)
	end
end

function cItemMgr:onEnterGame(user)

end

function cItemMgr:onLeaveGame()

end

function cItemMgr:onOverride(user)

end

function cItemMgr:onSyncInfo()

end

local function _addItem(self,item)
	if not item.uid then
		item.uid = idBuilder:alloc_item_uid()
	end
	self.itemSlot[item.uid] = item
	local info = self.helper[item.cid]
	if not info then
		info = {}
		self.helper[item.cid] = info
	end
	info[item.uid] = true
	self:dirtyItem(item.uid)
end

local function _delItem(self,item)
	self.itemSlot[item.uid] = nil
	local helperInfo = self.helper[item.cid]
	helperInfo[item.uid] = nil
	item:destroy()
	self:dirtyItem(item.uid)
end

function cItemMgr:getItem(itemUid)
	return self.itemSlot[itemUid]
end

function cItemMgr:insertItemByCid(cid,amount)
	self:dirty_field("itemSlot")
	local itemConf = config.item[cid]
	if not itemConf then
		error(string.format("no such item:%d",cid))
	end
	if itemConf.attr then
		self.__user:addAttr(itemConf.attr,amount)
		return
	end

	local items = itemFactory:createItem(cid,amount)

	for _,item in pairs(items) do
		self:insertItem(item)
	end
end

function cItemMgr:insertItem(item)
	local itemConf = config.item[item.cid]
	if itemConf.useRightnow then
		item:use()
		item:release()
		return
	end

	if itemConf.overlap > 1 then

		local helperInfo = self.helper[cid]
		if helperInfo then
			for uid in pairs(helperInfo) do
				local oItem = self.itemSlot[uid]
				if oItem:canOverlapBy(item) then
					oItem:overlapBy(item)
					self:dirtyItem(oItem.uid)
					if item.amount == 0 then
						break
					end
				end
			end
		end

		if item.amount > 0 then
			_addItem(self,item)
		else
			item:release()
		end
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

		local oItem = self.itemSlot[uid]
		if oItem.amount > left then
			oItem.amount = oItem.amount - left
			self:dirtyItem(oItem.uid)
			left = 0
		else
			left = left - oItem.amount
			_delItem(self,oItem)
		end
	end
end

function cItemMgr:deleteItemByUid(uid,amount)
	local item = self.itemSlot[uid]
	if item.amount > amount then
		item.amount = item.amount - amount
		self:dirtyItem(uid)
	else
		_delItem(self,item)
	end
end

function cItemMgr:itemEnough(cid,amount)
	local helperInfo = self.helper[cid]
	local total = 0
	for uid in pairs(helperInfo) do
		local item = self.itemSlot[uid]
		total = total + item.amount
	end
	return total >= amount
end

function cItemMgr:useItem(itemUid,amount)

end