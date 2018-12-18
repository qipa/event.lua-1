local worker = require "worker"
local model = require "model"

_workerQueue = _workerQueue or {}
_workerBalance = _workerBalance or 1
_workerCount = _workerCount

MODEL_BINDER("dbUser","uid")

function start(self,workerCount)
	local workerQueue = {}
	for i = 1,workerCount do
		table.insert(workerQueue,worker.create("server/data_worker"))
	end

	_workerQueue = workerQueue
	_workerBalance = 1
	_workerCount = #workerQueue
end

function doRequest(self,method,args)
	local workerIndex = _workerBalance
	_workerBalance = _workerBalance + 1
	if _workerBalance > _workerCount then
		_workerBalance = 1
	end
	return worker.master_call(workerIndex-1,"handler.data_mysql",method,args)
end

function loadUser(_,args)
	local user = model.fetch_dbUser_with_uid(args.userUid)
	if user then
		return user
	end

	local dbUserInfo = doRequest(nil,"loadUser",args.userUid)

	model.bind_dbUser_with_uid(args.userUid,dbUserInfo)

	return dbUserInfo
end

function saveUser(_,args)

end

function updateUser(_,args)

end