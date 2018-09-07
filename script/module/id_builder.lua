local persistence = require "persistence"
local model = require "model"
require "lfs"

local kPROCESS_OFFSET = 100
local kSERVER_OFFSET = 10000
local kMASK_OFFSET = 10
local kSTEP = 50

local eFIELD_MASK = {
	user = 1,
	item = 2,
	scene = 3,
	monster = 4,
}
local eUNIQUE = {
	"user",
	"item",
	"scene"
}


local eTMP = {
	"monster"
}

function init(self,serverId,distId)
	assert(serverId < kSERVER_OFFSET,string.format("error serverId:%d",serverId))
	assert(distId < kPROCESS_OFFSET,string.format("error distId:%d",serverId))

	local dbChannel = model.get_db_channel()
	assert(dbChannel ~= nil,string.format("no db channel"))

	for _,field in pairs(eUNIQUE) do
		local query = {id = distId,key = field}
		local result = dbChannel:findOne("common","idBuilder",{query = query})
		if not result then
			result = {begin = 1,offset = kSTEP}
		else
			result.begin = result.begin + result.offset
			result.offset = kSTEP
		end

		local updator = {}
		updator["$set"] = result
		dbChannel:update("common","idBuilder",query,updator,true)

		local cursor = result.begin
		local max = result.begin + result.offset

		self[string.format("alloc_%s_uid",field)] = function ()
			local uid = cursor * kMASK_OFFSET * kSERVER_OFFSET * kPROCESS_OFFSET + serverId * kMASK_OFFSET * kPROCESS_OFFSET + eFIELD_MASK[field] * kPROCESS_OFFSET + distId
			cursor = cursor + 1
			if cursor >= max then
				result.begin = cursor
				max = result.begin + result.offset

				local dbChannel = model.get_db_channel()
				local updator = {}
				updator["$set"] = result
				dbChannel:update("common","idBuilder",query,updator,true)
			end
			return uid
		end
	end

	for _,field in pairs(eTMP) do
		local pool = {}
		local step = 1
		self[string.format("pop_%s_tid",field)] = function ()
			local tid = next(pool)
			if tid then
				pool[tid] = nil
				return tid
			end
			local tid = step * kMASK_OFFSET * kPROCESS_OFFSET + eFIELD_MASK[field] * kPROCESS_OFFSET + distId
			step = step + 1
			return tid
		end

		self[string.format("push_%s_tid",field)] = function (tid)
			pool[tid] = true
		end
	end
end
