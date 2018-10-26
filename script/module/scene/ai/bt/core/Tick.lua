local object = import "module.object"

cBtTick = object.cObject:inherit("btTick")

function cBtTick:ctor()
	self.tree = nil
	self.debug = nil
	self.target = nil
	self.blackboard = nil

	self._openNodes = {}
	self._nodeCount = 0
end

function cBtTick:_enterNode(node)
	self._nodeCount = self._nodeCount + 1
	table.insert(self._openNodes, node)
end

function cBtTick:_openNode(node)
end

function cBtTick:_tickNode(node)
end

function cBtTick:_closeNode(node)
end

function cBtTick:_exitNode(node)
end