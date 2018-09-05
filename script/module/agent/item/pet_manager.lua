local idBuilder = import "module.id_builder"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_manager"

cPetMgr = itemMgr.cItemMgr:inherit("petMgr")

function __init__(self)
end


function cPetMgr:create()
	itemMgr.cItemMgr.create(self)
end

function cPetMgr:destroy()

end
