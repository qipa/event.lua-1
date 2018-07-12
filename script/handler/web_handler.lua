local util = require "util"
local cjson = require "cjson"
local http = require "http"
local persistence = require "persistence"

local function load_serverlist(file)
	local FILE = assert(io.open(file,"r"))
	local content = FILE:read("*a")
	FILE:close()
	return content
end

local API = {}

function API.getPfSrvList(channel, args)
	local content = load_serverlist("../newsvr/serverlist.txt")
	local serverlist = cjson.decode(content)

	local fs = persistence:open("../newsvr/","rolelist")

	local recent_login_srv = {}
	for srv_id in pairs(serverlist.data.srv_list) do
		
		local data = fs:load(srv_id)
		if next(data) and args.user_name then
			local role_list = data[args.user_name]
			if role_list then
				local list = {}
				for uid,info in pairs(role_list) do
					if not info.login_time then
						info.login_time = os.time()
					end
					info.uid = uid
					table.insert(list,info)
				end
				table.sort(list,function (l,r)
					return l.login_time > r.login_time
				end)
				recent_login_srv[srv_id] = {
					srv_id = srv_id,
					login_time = list[1].login_time,
					role_list = list
				}
			end
		end
	end
	serverlist.data.recent_login_srv = recent_login_srv
	return serverlist.data
end

function API.saveRecentLoginSrvs(channel,args)
	local fs = persistence:open("../newsvr/","rolelist")
	local data = fs:load(args.srv_id)

	local role_list = data[args.user_name or "test"]
	if not role_list then
		role_list = {}
		data[args.user_name or "test"] = role_list
	end
	role_list[args.user_uid] = {name = args.user_name,job = args.user_job_id,level = args.user_level,grade = args.user_grade,login_time = os.time()}
	fs:save(args.srv_id,data)

	return true
end 

function API.getLoginBulletin(channel,args)
	return {title = "标题",content = "内容"}
end

function dispatcher(channel,header,url,body)
	local path, query = http.url_parse(url)
	local path_info = path:split("/")

	local form = http.url_parse_query(query)
	form = http.url_parse_query(form.data)
	
	local api_name = path_info[#path_info - 2]

	local func = API[api_name]
	if not func then
		error(string.format("no such api:%s",api_name))
	end

	local data = func(channel,form)
	return cjson.encode({status = 1,data = data})
end