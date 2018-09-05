


function __init__(self)

end

local categoryCreator = {
	[1] = import "module.agent.item.obj.item".cItem,
	[2] = import "module.agent.item.obj.equipment".cEquipment,
	[3] = import "module.agent.item.obj.currency".cCurrency,
	[4] = import "module.agent.item.obj.material".cMaterial,
	[5] = import "module.agent.item.obj.props".cProps,
	[6] = import "module.agent.item.obj.pet".cPet,
}


	
function createItem(self,cid,amount)
	local itemConf = config.item[cid]
	assert(itemConf ~= nil,cid)
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
