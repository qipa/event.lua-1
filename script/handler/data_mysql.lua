local event = require "event"
local worker = require "worker"
local mysqlEnv = require "luasql.mysql"
local mysqlCore = mysqlEnv.mysql()

mysqlSession = mysqlSession or nil

function init(self)
	local mysql,err = mysqlCore:connect("test","root","2444cc818a3bbc06","127.0.0.1",3306)
	print(env.tid,mysql,err)
	if not mysql then
		event.error(err)
		os.exit(1)
		return
	else
		event.error(string.format("connect mysql:%s@%s:%d success","root","127.0.0.1",3306))
	end
	mysqlSession = mysql
end

function querySql(sql)
	local cursor = mysqlSession:execute(sql)
	if not cursor then
		return
	end
	local result = {}
	local row = cursor:fetch ({}, "a")
	while row do
		local sub = {}
		for k,v in pairs(row) do
			sub[k] = v
		end
		table.insert(result,sub)
		row = cursor:fetch (row, "a")
	end
	cursor:close()
	return result
end

function updateSql(sql)
	print("updateSql",sql)
	local ok,err = mysqlSession:execute(sql)
	if not ok then
		error(err)
	end
	return true
end

local count = 0
function loadUser(uid)
	count = count + 1

	local dbUser = {}
	local userInfo = querySql("select * from user where userUid = "..uid)
	if userInfo then
		dbUser.user = userInfo[1]
	end

	local itemInfo = querySql("select * from item where userUid = "..uid)
	if itemInfo then
		dbUser.item = itemInfo
	end

	-- if count == 102 then
	-- 	worker.quit()
	-- 	mysqlSession:close()
	-- 	mysqlCore:close()
		
	-- end

	return dbUser
end

function saveUser()

end

function updateUser()

end