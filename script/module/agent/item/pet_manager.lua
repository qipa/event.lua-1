local idBuilder = import "module.id_builder"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_mgr"

cPetMgr = itemMgr.cItemMgr:inherit("petMgr")

function __init__(self)
end


function cPetMgr:create()

end

function cPetMgr:destroy()

end
