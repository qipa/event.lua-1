local idBuilder = import "module.id_builder"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_mgr"

cBagMgr = itemMgr.cItemMgr:inherit("bagMgr")

function __init__(self)
	self.cBagMgr:save_field("gridCount")
end


function cBagMgr:create()

end

function cBagMgr:destroy()

end
