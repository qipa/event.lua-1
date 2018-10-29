local object = import "module.object"

btTick = {}

function btTick.create()
	self.tree = nil
	self.debug = nil
	self.target = nil
	self.blackboard = nil

	self._openNodes = {}
	self._nodeCount = 0
end

function btTick.enterNode(node)
	self._nodeCount = self._nodeCount + 1
	table.insert(self._openNodes, node)
end

function btTick.openNode(node)
	-- print("open",node.title)
end

function btTick.tickNode(node)
	-- print("tick",node.title)
end

function btTick.closeNode(node)
	-- print("close",node.title)
	table.remove(self._openNodes)
end

function btTick.exitNode(node)
end