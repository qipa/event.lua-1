local model = require "model"
local idBuilder = import "module.id_builder"
local dbCollection = import "module.database_collection"
local itemFactory = import "module.agent.item.item_factory"


cItemMgr = dbCollection.cls_collection:inherit("item_mgr")

function __init__(self)
	self.cItemMgr:save_field("itemSlot")
end


function cItemMgr:create()
	self.helper = {}
	self.itemSlot = {}
	self.gridCount = 0
end

function cItemMgr:destroy()
	for _,item in pairs(self.itemSlot) do
		item:release()
		model.unbind_item_with_uid(item.uid)
	end
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
	self.gridCount = 0
	if self.itemSlot then
		for itemUid,item in pairs(self.itemSlot) do
			itemSlot[tonumber(itemUid)] = item
			model.bind_item_with_uid(itemUid,item)
			local info = self.helper[item.cid]
			if not info then
				info = {}
				self.helper[item.cid] = info
			end
			info[item.uid] = true
			self.gridCount = self.gridCount + 1
		end
	end
	self.itemSlot = itemSlot
end

function cItemMgr:save(dbChannel,db,dbIndex)
	print("save item mgr")
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
	model.bind_item_with_uid(item.uid,item)

	local info = self.helper[item.cid]
	if not info then
		info = {}
		self.helper[item.cid] = info
	end
	info[item.uid] = true
	self.gridCount = self.gridCount + 1
	self:dirtyItem(item.uid)
end

local function _delItem(self,item)
	self.itemSlot[item.uid] = nil
	model.unbind_item_with_uid(item.uid)

	local helperInfo = self.helper[item.cid]
	helperInfo[item.uid] = nil
	self.gridCount = self.gridCount - 1
	item:destroy()
	self:dirtyItem(item.uid)
end

local function _calcGridCount(cid,amount,cfg)
	if not cfg then
		cfg = config.item[cid]
	end
	local cfg = config.item[cid]
	if not cfg.overlap or cfg.overlap == 0 then
		return 1
	end
	return math.ceil(amount / cfg.overlap)
end

function cItemMgr:getItem(itemUid)
	return self.itemSlot[itemUid]
end

function cItemMgr:getGridCount()
	return self.gridCount
end

function cItemMgr:needGridCount(cid,amount)
	local cfg = config.item[cid]
	local info = self.helper[cid]
	if not info then
		return _calcGridCount(cid,amount,cfg)
	end

	local gridCount = 0
	for itemUid in pairs(info) do
		local item = self.itemSlot[itemUid]
		local ok,left = item:canOverlapByCid(cid,amount)
		if not ok then
			gridCount = gridCount + 1
			amount = left
		end
	end
	gridCount = gridCount + _calcGridCount(cid,amount,cfg)
	return gridCount
end

function cItemMgr:insertItemByCidList(list)
	local insertMap = {}
	for _,info in pairs(list) do
		insertMap[info.cid] = (insertMap[info.cid] or 0) + info.amount
	end

	if not self:canInsertList(insertMap) then
		return false
	end

	local insertLog = {}
	for cid,amount in pairs(insertMap) do
		self:insertItemByCid(cid,amount,insertLog)
	end
end

function cItemMgr:insertItemByCid(cid,amount,insertLog)
	if not insertLog then
		insertLog = {}
	end
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
		self:insertItem(item,insertLog)
	end
end

function cItemMgr:insertItem(item,insertLog)
	if not insertLog then
		insertLog = {}
	end
	local itemConf = config.item[item.cid]
	if itemConf.useRightnow then
		item:use()
		item:release()
		return
	end
	if not self:canInsert(item.cid,item.amount) then
		return false
	end
	
	self:dirty_field("itemSlot")

	local helperInfo = self.helper[cid]
	if helperInfo then
		for uid in pairs(helperInfo) do
			local oItem = self.itemSlot[uid]
			if oItem:canOverlapBy(item) then
				oItem:overlapBy(item)
				insertLog[oItem.uid] = oItem.amount
				self:dirtyItem(oItem.uid)
				if item.amount == 0 then
					break
				end
			end
		end
	end
	if item.amount > 0 then
		_addItem(self,item)
		insertLog[item.uid] = item.amount
	else
		item:release()
	end

	insertLog[item.uid] = item.amount
end

function cItemMgr:deleteItemByCidList(list)
	local ok,cid = self:itemEnoughList(list)
	if not ok then
		return false,cid
	end

	local deleteMap = {}
	for _,info in pairs(list) do
		deleteMap[info.cid] = (deleteMap[info.cid] or 0) + info.amount
	end

	local deleteLog = {}
	for cid,amount in pairs(deleteMap) do
		self:deleteItemByCid(cid,amount,deleteLog)
	end
end

function cItemMgr:deleteItemByCid(cid,amount,deleteLog)
	if not self:itemEnough(cid,amount) then
		return false
	end

	self:dirty_field("itemSlot")

	local helperInfo = self.helper[cid]

	local left = amount

	for uid in pairs(helperInfo) do
		if left == 0 then
			break
		end

		local oItem = self.itemSlot[uid]
		if oItem.amount > left then
			oItem.amount = oItem.amount - left
			deleteLog[oItem.uid] = oItem.amount
			self:dirtyItem(oItem.uid)
			left = 0
		else
			left = left - oItem.amount
			deleteLog[oItem.uid] = 0
			_delItem(self,oItem)
		end
	end
end

function cItemMgr:deleteItemByUid(uid,amount)
	self:dirty_field("itemSlot")
	local item = self.itemSlot[uid]
	if item.amount > amount then
		item.amount = item.amount - amount
		self:dirtyItem(uid)
	else
		_delItem(self,item)
	end
end

function cItemMgr:deleteItem(item,amount)
	return self:deleteItemByUid(item.uid,amount or item.amount)
end

function cItemMgr:itemEnoughList(list)
	local map = {}
	for _,info in pairs(list) do
		map[info.cid] = (map[info.cid] or 0) + info.amount
	end

	for cid,amount in pairs(map) do
		if not self:itemEnough(cid,amount) then
			return false,cid
		end
	end
	return true
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

function cItemMgr:canInsertList(list)
	return true
end

function cItemMgr:canInsert(cid,amount)
	return true
end

function cItemMgr:useItem(itemUid,amount)

end
