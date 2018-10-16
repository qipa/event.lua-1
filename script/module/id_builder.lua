local persistence = require "persistence"
local model = require "model"
require "lfs"

local kPROCESS_MASK = 100
local kSERVER_MASK = 10000
local kTYPE_MASK = 100
local kSTEP = 50

local eTYPE = {
	User = 1,
	Item = 2,
	Scene = 3,
	Monster = 4,
}

local eUNIQUE = {
	"User",
	"Item",
	"Scene"
}

local eTMP = {
	"Monster"
}

function init(self,serverId,distId)
	local dbChannel = model.get_dbChannel()
	assert(dbChannel ~= nil,string.format("no db channel"))

	assert(serverId < kSERVER_MASK,string.format("error serverId:%d",serverId))
	assert(distId < kPROCESS_MASK,string.format("error distId:%d",serverId))

	for _,idType in pairs(eUNIQUE) do
		local typeId = eTYPE[idType]
		assert(typeId < kTYPE_MASK,string.format("error type id:%d",typeId))

		local query = {id = distId,key = idType}
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

		local idHighMask = kTYPE_MASK * kSERVER_MASK * kPROCESS_MASK

		local idLow = distId + eTYPE[idType] * kPROCESS_MASK + serverId * kTYPE_MASK * kPROCESS_MASK

		self[string.format("alloc%sUid",idType)] = function ()
			local uid = cursor * idHighMask + idLow
			cursor = cursor + 1
			if cursor >= max then
				result.begin = cursor
				max = result.begin + result.offset

				local dbChannel = model.get_dbChannel()
				local updator = {}
				updator["$set"] = result
				dbChannel:update("common","idBuilder",query,updator,true)
			end
			return uid
		end
	end

	for _,idType in pairs(eTMP) do
		local pool = {}
		local step = 1
		local idLow = eTYPE[idType] * kPROCESS_MASK + distId
		local idHighMask = kTYPE_MASK * kPROCESS_MASK

		self[string.format("alloc%sTid",idType)] = function ()
			local tid = next(pool)
			if tid then
				pool[tid] = nil
				return tid
			end
			local tid = step * idHighMask + idLow
			step = step + 1
			return tid
		end

		self[string.format("reclaim%sTid",idType)] = function (tid)
			pool[tid] = true
		end
	end
end
