local b3 = import "module.scene.ai.bt.bt_const"
local object = import "module.object"
cBtBaseNode = object.cObject:inherit("btBaseNode")

function cBtBaseNode:ctor(params)
	self.id = self.__objectId

	self.name = params.name
	self.title = params.title
	self.description = params.description

	if params.properties.precondition ~= "" then
		self.precondition = params.properties.precondition
	end

	if params.properties.operation ~= "" then
		self.operation = params.properties.operation
	end
end

function cBtBaseNode:_execute(tick)
	--ENTER

	self:_enter(tick)

	local status = b3.SUCCESS
	--OPEN
	if not (tick.blackboard:get("isOpen", tick.tree.id, self.id)) then
		status = self:_open(tick)
	end

	if status == b3.SUCCESS then
		--TICK
		status = self:_tick(tick)

		--CLOSE
		if status ~= b3.RUNNING then
			self:_close(tick)
		end
	else
		self:_close(tick)
	end

	--EXIT
	self:_exit(tick)

	return status
end

function cBtBaseNode:_enter(tick)
	tick:_enterNode(self)
	self:enter(tick)
end

function cBtBaseNode:_open(tick)
	tick:_openNode(self)
	tick.blackboard:set("isOpen", true, tick.tree.id, self.id)
	return self:open(tick)
end

function cBtBaseNode:_tick(tick)
	tick:_tickNode(self)
	return self:tick(tick)
end

function cBtBaseNode:_close(tick)
	tick:_closeNode(self)
	tick.blackboard:set("isOpen", false, tick.tree.id, self.id)
	self:close(tick)
end

function cBtBaseNode:_exit(tick)
	tick:_exitNode(self)
	self:exit(tick)
end

function cBtBaseNode:enter(tick)
end

function cBtBaseNode:open(tick)
	
	if self.precondition then
		local status = tick.target[self.precondition](tick.target)
		return status
	end
	return b3.SUCCESS
end

function cBtBaseNode:tick(tick)
end

function cBtBaseNode:close(tick)
end

function cBtBaseNode:exit(tick)
end

