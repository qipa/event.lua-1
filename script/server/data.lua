local event = require "event"
local util = require "util"
local worker = require "worker"
local model = require "model"

MODEL_VALUE("workerQueue")

event.fork(function ()
	event.listen("ipc://data.ipc",4,function (channel)

	end)

	local workerQueue = {}
	for i = 1,8 do
		table.insert(workerQueue,worker.create("server/data_worker"))
	end

	model.set_workerQueue(workerQueue)

	for i = 0,7 do
		local result = worker.master_call(i,"handler.data_handler","loadUser",{userUid = 1 })
		table.print(result)
	end
end)