local event = require "event"


local _M = {}


function _M.callout(interval,inst,method,...)
	local args = {...}
	local __timer = rawget(inst,"__timer")
	local timer = event.timer(interval,function ()
		inst[method](inst,table.unpack(args))
	end)
	__timer[timer] = true 
	return timer
end

function _M.calloutAfter(interval,inst,method,...)
	local args = {...}
	local __timer = rawget(inst,"__timer")
	local timer = event.timer(interval,function ()
		inst[method](inst,table.unpack(args))
		__timer[timer] = nil
	end)
	__timer[timer] = false 
	return timer
end

function _M.removeTimer(inst,timer)
	assert(__timer[timer],string.format("no such timer:%s",timer))
	timer:cancel()
	__timer[timer] = nil
end

function _M.removeAll(inst)
	local __timer = rawget(inst,"__timer")
	for timer in pairs(__timer) do
		timer:cancel()
	end
	rawset(inst,__timer,{})
end

return _M
