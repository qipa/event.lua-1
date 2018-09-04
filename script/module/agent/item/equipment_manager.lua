local idBuilder = import "module.id_builder"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_mgr"

cEquipmentMgr = itemMgr.cItemMgr:inherit("equipmentMgr")

function __init__(self)
end


function cEquipmentMgr:create()

end

function cEquipmentMgr:destroy()

end
