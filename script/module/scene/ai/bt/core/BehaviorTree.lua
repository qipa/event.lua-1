local b3 = import "module.scene.ai.bt.bt_const"

local object = import "module.object"

cBtTree = object.cObject:inherit("btTree")

local eBtNode = {
	["Action"] = import "module.scene.ai.bt.core.Action".cBtAction,
	["Error"] = import "module.scene.ai.bt.actions.Error".cBtError,
	["Failer"] = import "module.scene.ai.bt.actions.Failer".cBtFailer,
	["Runner"] = import "module.scene.ai.bt.actions.Runner".cBtRunner,
	["Succeeder"] = import "module.scene.ai.bt.actions.Succeeder".cBtSucceeder,
	["Wait"] = import "module.scene.ai.bt.actions.Wait".cBtWait,
	["MemPriority"] = import "module.scene.ai.bt.composites.MemPriority".cBtMemPriority,
	["MemSequence"] = import "module.scene.ai.bt.composites.MemSequence".cBtMemSequence,
	["Priority"] = import "module.scene.ai.bt.composites.Priority".cBtPriority,
	["Sequence"] = import "module.scene.ai.bt.composites.Sequence".cBtSequence,
	["Condition"] = import "module.scene.ai.bt.core.Condition".cBtCondition,
}

function cBtTree:ctor()
	self.id 			= self.__objectId

	self.title 			= "The behavior tree"
	self.description 	= "Default description"
	self.properties 	= {}
	self.root			= nil
	self.debug			= nil
end

function cBtTree:load(data)
	self.title 			= data.title or self.title
	self.description 	= data.description or self.description
	self.properties 	= data.properties or self.properties

	local nodes = {}
	local id, spec, node

	for i,v in pairs(data.nodes) do
		id = i
		spec = v

		local cls = eBtNode[spec.name]
		assert(cls ~= nil,string.format("no found bt node:%s",spec.name))

		node = cls:new(spec)
		nodes[id] = node
	end

	for i,v in pairs(data.nodes) do
		id = i
		spec = v
		node = nodes[id]

		if v.children and node.category == b3.COMPOSITE then
			for i = 1,#v.children do
				local cid = spec.children[i]
				table.insert(node.children, nodes[cid])
			end
		elseif v.child and node.category == b3.DECORATOR then
			local cid = spec.children[i]
			node.child = nodes[cid]
		end
	end

	self.root = nodes[data.root]
end

function cBtTree:dump()
	local data = {}
	local customNames = {}

	data.title 			= self.title
	data.description 	= self.description
	if self.root then
		data.root		= self.root.id
	else
		data.root		= nil
	end
	data.properties		= self.properties
	data.nodes 			= {}
	data.custom_nodes	= {}

	if self.root then
		return data
	end

	--TODO:
end

function cBtTree:tick(tick,target, blackboard)
	if not blackboard then
		print("The blackboard parameter is obligatory and must be an instance of b3.Blackboard")
	end

	tick.debug 		= self.debug
	tick.target		= target
	tick.blackboard = blackboard
	tick.tree 		= self

	--TICK NODE
	local state = self.root:_execute(tick)

	-- --CLOSE NODES FROM LAST TICK, IF NEEDED
	-- local lastOpenNodes = blackboard:get("openNodes", self.id)
	-- local currOpenNodes = tick._openNodes[0]
	-- if not lastOpenNodes then
	-- 	lastOpenNodes = {}
	-- end

	-- if not currOpenNodes then
	-- 	currOpenNodes = {}
	-- end

	-- local start = 0
	-- local i
	-- for i = 0,math.min(table.getn(lastOpenNodes), table.getn(currOpenNodes)) do
	-- 	start = i + 1
	-- 	if lastOpenNodes[i] ~= currOpenNodes[i] then
	-- 		break
	-- 	end
	-- end

	-- for i = table.getn(lastOpenNodes),0,-1 do
	-- 	if lastOpenNodes[i] then
	-- 		lastOpenNodes[i]:_close(tick)
	-- 	end
	-- end

	-- blackboard:set("openNodes", currOpenNodes, self.id)
	-- blackboard:set("nodeCount", tick._nodeCount, self.id)
end
