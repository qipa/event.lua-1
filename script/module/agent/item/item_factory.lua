


function __init__(self)

end

local categoryCreator = {
	item = import "module.agent.item.item".cItem,
	equipment = import "module.agent.item.equipment".cEquipment,
	currency = import "module.agent.item.currency".cCurrency,
	material = import "module.agent.item.material".cMaterial,
}

function createItem(cid,amount)
	local itemConf = config.item[cid]

	local creator = categoryCreator[itemConf.category]

	local result = {}

	local left = amount
	while left > 0 do
		local count = itemConf.overlap
		if count > left then
			count = count - left
		end
		left = left - count
		local item = creator:new(cid,count)
		item:init()
		table.insert(result,item)
	end
	return result
end
