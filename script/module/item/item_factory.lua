


function __init__(self)

end

local category_creator = {
	equipment = import "moudle.item.equipment".cls_equipment,
	currency = import "moudle.item.currency".cls_currency,
	material = import "moudle.item.material".cls_material,
}

function create_item(cid,amount)
	local item_conf = config.item[cid]

	local creator = category_creator[item_conf.category]

	local result = {}

	local left = amount
	while left > 0 do
		local count = item_conf.overlap
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