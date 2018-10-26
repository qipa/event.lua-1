local object = import "module.object"

cBtBlackboard = object.cObject:inherit("btBlackboard")

function cBtBlackboard:ctor()
	self._baseMemory = {}
	self._treeMemory = {}
end

function cBtBlackboard:_getTreeMemory(treeScope)
	if not self._treeMemory[treeScope] then
		self._treeMemory[treeScope] = {nodeMemory = {}, openNodes = {}, traversalDepth = 0, traversalCycle = 0}
	end
	return self._treeMemory[treeScope]
end

function cBtBlackboard:_getNodeMemory(treeMemory, nodeScope)
	local memory = treeMemory.nodeMemory

	if not memory then
		memory = {}
	end

	if memory and not memory[nodeScope] then
		memory[nodeScope] = {}
	end

	return memory[nodeScope]
end

function cBtBlackboard:_getMemory(treeScope, nodeScope)
	local memory = self._baseMemory

	if treeScope then
		memory = self:_getTreeMemory(treeScope)

		if nodeScope then
			memory = self:_getNodeMemory(memory, nodeScope)
		end
	end

	return memory
end

function cBtBlackboard:set(key, value, treeScope, nodeScope)
	local memory = self:_getMemory(treeScope, nodeScope)
	memory[key] = value
end

function cBtBlackboard:get(key, treeScope, nodeScope)
	local memory = self:_getMemory(treeScope, nodeScope)
	if memory then
		return memory[key]
	end
	return {}
end
