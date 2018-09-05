local id_builder = import "module.id_builder"
local item = import "module.agent.item.obj.item"


cCurrency = item.cItem:inherit("currency")


function __init__(self)
end

function cCurrency:canUse()
	return false
end

function cCurrency:use()
	assert(false)
end

function cCurrency:canOverlapBy(item)
	if self.cid ~= item.cid then
		return false
	end
	return true
end

function cCurrency:overlapBy(item)
	if not self:canOverlapBy(item) then
		return
	end

	self.amount = self.amount + item.amount
	local more = self:overlapMore()
	if item.amount > more then
		self.amount = self.amount + more
		item.amount = item.amount - more
	else
		self.amount = self.amount + item.amount
		item.amount = 0
	end
end

function cCurrency:overlapMore()
	local cfg = config.item[self.cid]
	if cfg.overlap == 1 then
		return 0
	end
	return cfg.overlap - self.amount
end

function cCurrency:getExtraInfo()

end
