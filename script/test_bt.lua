local event = require "event"
local btTree = import "module.scene.ai.bt.core.BehaviorTree"
local btTick = import "module.scene.ai.bt.core.Tick"
local btBlackboard = import "module.scene.ai.bt.core.Blackboard"


local FILE = io.open("./config/测试.lua","r")
local treeData = FILE:read("*a")
FILE:close()

local treeData = load(treeData)()

-- table.print(treeData)

local tree = btTree.cBtTree:new()

tree:load(treeData)

local tick = btTick.cBtTick:new()

local blackBoard = btBlackboard.cBtBlackboard:new()

local target = {}

local needGoHome = 1
local goHomeCountor = 1
function target.isNeedGoHome()
	print("isNeedGoHome")
	return needGoHome
end

function target.noTarget()
	print("noTarget")
	return 2
end

function target.findTarget()
	print("findTarget")
end

function target.goHome()
	print("goHome")
	goHomeCountor = goHomeCountor + 1
	if goHomeCountor < 20 then
		return 3
	else
		needGoHome = 2
		return 1
	end
end

function target.randomSpeak()
	print("randomSpeak")
end

function target.randomMove()
	print("randomMove")
end

function target.moveToTarget()
	print("moveToTarget")
end

function target.attack()
	print("attack")
end

-- table.print(tree)

event.fork(function ()
	while true do
		event.sleep(0.1)
		tree:tick(tick,target,blackBoard)
	end

end)