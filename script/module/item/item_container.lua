local id_builder = import "module.id_builder"
local database_collection = import "module.database_collection"
local item_factory = import "module.item.item_factory"


cls_item_container = database_collection.cls_collection_set:inherit("item_container")

function __init__(self)
	
end


function cls_item_container:create()

end

function cls_item_container:init()
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

function cls_item_container:destroy()

end

local function add_item(self,item)
	self.slots[item.uid] = item
	local info = self.helper[item.cid]
	if not info then
		info = {}
		self.helper[item.cid] = info
	end
	info[item.uid] = true
end

local function del_item(self,item)
	self.slots[item.uid] = nil
	helper_info[item.uid] = nil
	item:destroy()
end

function cls_item_container:insert_item_by_cid(cid,amount)

	local item_conf = config.item[cid]

	local left = amount
	local uid_list = self.helper[cid]
	for uid in pairs(uid_list) do
		local old_item = self.slots[uid]
		if item_conf.overlap > old_item.amount then
			local space = item_conf.overlap - old_item.amount
			if left < space then
				old_item.amount = old_item.amount + left
				left = 0
				break
			else
				old_item.amount = item_conf.overlap
				left = left - space
			end
		end
	end

	if left > 0 then
		local items = item_factory:create_item(cid,left)

		for _,item in pairs(items) do
			add_item(self,item)
		end
	end
end

function cls_item_container:insert_item(item)
	local item_conf = config.item[item.cid]
	if item_conf.overlap > 1 then
		self:insert_item_by_cid(item.cid,item.amount)
		item:destroy()
		return
	end

	add_item(self,item)
end

function cls_item_container:delete_item(item)
	return self:delete_item_by_uid(item.uid,item.amount)
end

function cls_item_container:delete_item_by_cid(cid,amount)
	if not self:item_enough(cid,amount) then
		return false
	end

	local helper_info = self.helper[cid]

	local left = amount

	for uid in pairs(helper_info) do
		if left == 0 then
			break
		end

		local old_item = self.slots[uid]
		if old_item.amount > left then
			old_item.amount = old_item.amount - left
			left = 0
		else
			left = left - old_item.amount
			del_item(self,old_item)
		end
	end
end

function cls_item_container:delete_item_by_uid(uid,amount)

end

function cls_item_container:item_enough(cid,amount)
	local helper_info = self.helper[cid]
	local total = 0
	for uid in pairs(helper_info) do
		local item = self.slots[uid]
		total = total + item.amount
	end
	return total >= amount
end