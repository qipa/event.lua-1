local event = require "event"
local util = require "util"
local vector2 = util.vector2
local aoi_core = require "toweraoi.core"
local helper = require "helper"

local aoi = aoi_core.create(1001,1000,1000,5)

local object_ctx = {}

local object = {}

function object:new(id,x,z,range)
	local ctx = setmetatable({},{__index = self})
	ctx.x = x
	ctx.z = z
	ctx.id = id

	local enter_other,enter_self

	ctx.aoi_object_id,enter_other = aoi:create_entity(id,x,z)
	ctx.aoi_watcher_id,enter_self = aoi:create_trigger(id,x,z,range)

	for _,other_id in pairs(enter_other) do
		local other = object_ctx[other_id]
		other:enter(ctx)
	end

	for _,other_id in pairs(enter_self) do
		local other = object_ctx[other_id]
		ctx:enter(other)
	end

	object_ctx[id] = ctx

	return ctx
end

function object:move(x,z)
	self.x = x
	self.z = z
	local leave_other,enter_other = aoi:move_entity(self.aoi_object_id,x,z)
	if leave_other then
		for _,id in pairs(leave_other) do
			local other = object_ctx[id]
			other:leave(self)
		end

		for _,id in pairs(enter_other) do
			local other = object_ctx[id]
			other:enter(self)
		end
	end

	local leave_self,enter_self = aoi:move_trigger(self.aoi_watcher_id,x,z)
	if leave_self then
		for _,id in pairs(leave_self) do
			local other = object_ctx[id]
			self:leave(other)
		end
		for _,id in pairs(enter_self) do
			local other = object_ctx[id]
			self:enter(other)
		end
	end
end

function object:enter(other)
	-- print(string.format("enter:%d:[%f,%f],%d:[%f:%f],%f",self.id,self.x,self.z,other.id,other.x,other.z,util.distance(self.x,self.z,other.x,other.z)))
end

function object:leave(other)
	-- print(string.format("leave:%d:[%f,%f],%d:[%f:%f],%f",self.id,self.x,self.z,other.id,other.x,other.z,util.distance(self.x,self.z,other.x,other.z)))
end

for i = 1,5000 do
	local obj = object:new(i,math.random(0,1000),math.random(0,1000),5)
end

local move_set = {}

for i = 1,5000 do
	event.fork(function ()
		local move_obj = object_ctx[i]
		while true do
			local x,z = math.random(0,1000),math.random(0,1000)
			while true do
				event.sleep(0.1)
				local rx,rz = util.move_forward(move_obj.x,move_obj.z,x,z,5)
				local ox,oz = move_obj.x,move_obj.z
				move_obj:move(rx,rz)
				if util.distance(ox,oz,rx,rz) <= 1 then
					break
				end
			end
		end
	end)
end
