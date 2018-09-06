local persistence = require "persistence"
local model = require "model"
require "lfs"

local kPROCESS_OFFSET = 100
local kSERVER_OFFSET = 10000
local kMASK_OFFSET = 10
local kID_STEP = 100

local eUNIQUE_MASK = {
	user = 1,
	item = 2,
	scene = 3,
}


local eTMP_MASK = {
	monster = 1
}

function init(self,serverId,distId)
	if distId >= kPROCESS_OFFSET then
		print(string.format("error dist id:%d",distId))
		os.exit(1)
	end

	local dbChannel = model.get_db_channel()

	for field,mask in pairs(eUNIQUE_MASK) do
		local result = dbChannel:findOne("common","id_builder",{query = {id = distId,key = field}})
		if not result then
			result = {begin = 1,offset = kID_STEP}
		else
			result.begin = result.begin + result.offset
			result.offset = kID_STEP
		end

		local updator = {}
		updator["$set"] = result
		dbChannel:update("common","id_builder",{id = distId,key = field},updator,true)

		local cursor = result.begin
		local max = result.begin + result.offset

		self[string.format("alloc_%s_uid",field)] = function ()
			local uid = cursor * kMASK_OFFSET * kSERVER_OFFSET * kPROCESS_OFFSET + mask * kSERVER_OFFSET * kPROCESS_OFFSET + serverId * kSERVER_OFFSET  + distId
			cursor = cursor + 1
			if cursor >= max then
				result.begin = cursor
				max = result.begin + result.offset

				local dbChannel = model.get_db_channel()
				local updator = {}
				updator["$set"] = result
				dbChannel:update("common","id_builder",{id = distId,key = field},updator,true)
			end
			return uid
		end
	end

	for field,mask in pairs(eTMP_MASK) do
		local pool = {}
		local step = 1
		local stepMax = kPROCESS_OFFSET * kSERVER_OFFSET * kMASK_OFFSET
		self[string.format("pop_%s_tid",field)] = function ()
			if step >= stepMax then
				error(string.format("%s tid empty",field))
			end
			local tid = next(pool)
			if tid then
				pool[tid] = nil
				return tid
			end
			local tid = step * kPROCESS_OFFSET * kMASK_OFFSET + mask * kPROCESS_OFFSET + distId
			step = step + 1
			return tid
		end

		self[string.format("push_%s_tid",field)] = function (tid)
			pool[tid] = true
		end
	end
end
