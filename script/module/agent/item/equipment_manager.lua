local idBuilder = import "module.id_builder"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_manager"

cEquipmentMgr = itemMgr.cItemMgr:inherit("equipmentMgr")

function __init__(self)
end



function cEquipmentMgr:onCreate(...)
	itemMgr.cItemMgr.onCreate(self)
end

function cEquipmentMgr:onDestroy()
	itemMgr.cItemMgr.onDestroy(self)
end

