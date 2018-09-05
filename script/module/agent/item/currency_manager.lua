local idBuilder = import "module.id_builder"
local itemFactory = import "module.agent.item.item_factory"
local itemMgr = import "module.agent.item.item_manager"

cCurrencyMgr = itemMgr.cItemMgr:inherit("currencyMgr")

function __init__(self)
end


function cCurrencyMgr:create()
	itemMgr.cItemMgr:create()
end

function cCurrencyMgr:destroy()

end
