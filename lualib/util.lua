require("lfs")
local util_core = require "util.core"
local filter_core = require "filter0.core"

local type = type
local assert = assert
local os_date = os.date
local os_time = os.time
local math_modf = math.modf

local _M = setmetatable({},{__index = util_core})

_M.mkdir = lfs.mkdir
_M.attributes = lfs.attributes
_M.link = lfs.link
_M.unlock = lfs.unlock
_M.touch = lfs.touch
_M.currentdir = lfs.currentdir
_M.rmdir = lfs.rmdir
_M.chdir = lfs.chdir
_M.dir = lfs.dir

_M.convert = filter_core.convert
_M.split_utf8 = filter_core.split
_M.word_filter_create = filter_core.create

local function get_tag( t )
    local str = type(t)
    return string.sub(str, 1, 1)..":"
end

function _M.dump(data, prefix, depth, output, record)
    record = record or {}

    depth = depth or 1

    if output == nil then
        output = _G.print
    end

    local tab = string.rep("\t", depth)
    if prefix ~= nil then
        tab = prefix .. tab
    end

    if data == nil then
        output(tab.." nil")
        return
    end

    if type(data) ~= "table" then
        output(tab..get_tag(data)..tostring(data))
        return
    end

    if record[data] then
        output(tab.." {}")
	return
    end
    --assert(record[data] == nil)
    record[data] = true

    local count = 0
    for k,v in pairs(data) do
        local str_k = get_tag(k)
        if type(v) == "table" then
            output(tab..str_k..tostring(k).." -> ")
            _M.dump(v, prefix, depth + 1, output, record)
        else
            output(tab..str_k..tostring(k).." -> ".. get_tag(v)..tostring(v))
        end
        count = count + 1
    end

    if count == 0 then
        output(tab.." {}")
    end
end


local function get_suffix(filename)
    return filename:match(".+%.(%w+)$")
end

function _M.list_dir(path,recursive,suffix,is_path_name,r_table)
    r_table = r_table or {}

    for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local f = path..'/'..file

            local attr = lfs.attributes (f)
            if attr.mode == "directory" and recursive then
                _M.list_dir(f, recursive, suffix, is_path_name,r_table)
            else
                local target = file
                if is_path_name then target = f end

                if suffix == nil or suffix == "" or suffix == get_suffix(f) then
                    table.insert(r_table, target)
                end
            end
        end
    end

    return r_table
end

function _M.split( str,reps )
    local result = {}
    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(result,w)
    end)
    return result
end

local function completion(str)
    local ch = str:sub(1,1)
    if ch == "r" then
        return {"reload"}
    elseif ch == "s" then
        return {"stop"}
    elseif ch == "m" then
        return {"mem","mem_dump"}
    elseif ch == "g" then
        return {"gc"}
    elseif ch == "y" then
        return {"yes"}
    elseif ch == "n" then
        return {"no"}
    elseif ch == "d" then
        return {"dump_model"}
    end
end

function _M.readline(prompt,func)
    return util_core.readline(prompt or ">>",func or completion)
end

function _M.to_date(unix_time)
    return os.date("*t",unix_time)
end

function _M.to_unixtime(year,mon,day,hour,min,sec)
    local time = {
        year = year,
        month = mon,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
    }
    return os.time(time)
end

function _M.format_to_unixtime(str)
    local year,mon,day,hour,min,sec = string.match(str,"(.*)-(.*)-(.*) (.*):(.*):(.*)")
    return _M.to_unixtime(year,mon,day,hour,min,sec)
end

function _M.format_to_daytime(unix_time,str)
    local hour,min = string.match(str,"(%d+):(%d+)")
    return _M.daytime(unix_time,tonumber(hour),tonumber(min))
end

function _M.daytime(unix_time,hour,min,sec)
    local unix_time = unix_time + 8 * 3600
    local tmp = math_modf(unix_time / 86400)
    local result = tmp * 86400 - 8 * 3600
    if hour then
        result = result + hour * 3600
    end
    if min then
        result = result + min * 60
    end
    if sec then
        result = result + sec
    end
    return result
end

function _M.next_time(unix_time,sec)
    return _M.daytime(unix_time) + sec
end

function _M.day_start(unix_time)
    return _M.daytime(unix_time)
end

function _M.day_over(unix_time)
    return _M.daytime(unix_time) + 24 * 3600
end

function _M.week_start(unix_time)
    local day_start = _M.day_start(unix_time)
    local result = os.date("*t",day_start)

    local wday = result.wday
    if wday == 2 then
        return day_start
    end

    if wday == 1 then
        wday = 8
    end
    return day_start - (wday-2) * 24 * 3600
end

function _M.week_over(unix_time)
    return _M.week_start(unix_time) + 7 * 24 * 3600
end

function _M.same_day(ti0,ti1,sep)
    assert(ti0 ~= nil and ti1 ~= nil)
    local sep = sep or 0
    return _M.daytime(ti0 - sep) == _M.daytime(ti1 - sep)
end

function _M.same_week(ti1,ti2,sep)
    local ti1 = ti1 - (sep or 0)
    local ti2 = ti2 - (sep or 0)

    local wstart
    if ti1 < ti2 then
        wstart = _M.week_start(ti2)
        if ti1 < wstart then
            return false
        end
    else
        wstart = _M.week_start(ti1)
        if ti2 < wstart then
            return false
        end
    end
    return true
end

function _M.time_diff(desc,func)
    local now = _M.time()
    func()
    print(string.format("%s:%f",desc,(_M.time() - now) * 10))
end

--十进制右边数起第b位
_M.decimal_bit = util_core.decimal_bit

--十进制右边数起第from到to位的数字
_M.decimal_sub = util_core.decimal_sub

--严格的矩形与圆形相交检测
--args:x0(矩形.起点.x),z0(矩形.起点.z),length(矩形.长度),width(矩形.宽度),angle(矩形.朝向),x(圆.x),z(圆.z),r(圆.r)
_M.rectangle_intersect = util_core.rectangle_intersect

--严格的圆柱与圆形相交检测
--args:x0(圆柱.起点.x),z0(圆柱.起点.z),x1(圆柱.终点.x),z1(圆柱.终点.z),x(圆.x),z(圆.z),r(圆.r)
_M.capsule_intersect = util_core.capsule_intersect

--严格的扇形与圆形相交检测
--args:x0(扇形.x),z0(扇形.z),angle(扇形.朝向),degree(扇形.跨过的角度),l(扇形.长度),x1(圆.x),z1(圆.z),r1(圆.r)
_M.sector_intersect = util_core.sector_intersect

--点到点的距离
--args:x0,z0,x1,z1
_M.dot2dot = util_core.dot2dot

--点到点的距离的平方
--args:x0,z0,x1,z1
_M.sqrt_dot2dot = util_core.sqrt_dot2dot

--点到线段的距离
--args:x0(线段.起点.x),z0(线段.起点.z),x1(线段.终点.x),z1(线段.终点.z),x(点.x),z(点.z)
_M.dot2segment = util_core.dot2segment

--求点相对某点逆时针旋转指定角度的坐标
--args:x0,z0,x1,z1,angle
_M.rotation = util_core.rotation

--求点往某个角度移动指定长度后的坐标
--args:x,z,angle,distance
_M.move_torward = util_core.move_torward

--求两点之前移动指定长度后的坐标
--args:x0,z0,x1,z1,distance
_M.move_forward = util_core.move_forward

--简单的圆形与圆形的相交检测
--args:x0(圆0.x),z0(圆0.z),r0(圆0.r),x1(圆1.x),z1(圆1.z),r1(圆1.r)
_M.inside_circle = util_core.inside_circle

--不严谨的扇形与圆形的相交检测
--args:x0(扇形.x),z0(扇形.z),angle(扇形.朝向),degree(扇形.跨过的角度),l(扇形.长度),x1(圆.x),z1(圆.z),r1(圆.r)
_M.inside_sector = util_core.inside_sector

--不严谨的矩形与圆形的相交检测
--args:x0(矩形.起点x),z0(矩形.起点z),angle(矩形.朝向),length(矩形.长度),width(矩形.宽度),x1(圆.x),z1(圆.z),r1(圆.r)
_M.inside_rectangle = util_core.inside_rectangle

--vector2
function _M.normalize(x,z)
    local dt = math.sqrt(x * x + z * z)
    return x / dt, z / dt
end

function _M.angle2dir(angle)
    return math.cos(angle),math.sin(angle)
end

--vector2
local vector2 = {}
vector2.__index = vector2

function vector2:new(x,z)
    local vt = setmetatable({},self)
    vt[1] = x
    vt[2] = z
    return vt
end

function vector2:instance(vt)
    return setmetatable(vt,self)
end

function vector2:__add(vt)
    local x = self[1] + vt[1]
    local z = self[2] + vt[2]
    return vector2:new(x,z)
end

function vector2:__sub(vt)
    local x = self[1] - vt[1]
    local z = self[2] - vt[2]
    return vector2:new(x,z)
end

function vector2:__mul(vt)
    local x = self[1] * vt[1]
    local z = self[2] * vt[2]
    return vector2:new(x,z)
end

function vector2:__div(vt)
    local x = self[1] / vt[1]
    local z = self[2] / vt[2]
    return vector2:new(x,z)
end

function vector2:__eq(vt)
    return self[1] == vt[1] and self[2] == vt[2]
end

function vector2:abs()
    local x = math.abs(self[1])
    local z = math.abs(self[2])
    return vector2:new(x,z)
end

function vector2:angle(vt)
    local dot = self:dot(vt)
    local cos = dot / (self:magnitude() * vt:magnitude())
    return math.deg(math.acos(cos))
end

function vector2:magnitude()
    return math.sqrt(self[1] * self[1] + self[2] * self[2])
end

function vector2:sqrmagnitude()
    return self[1] * self[1] + self[2] * self[2]
end

function vector2:normalize()
    local dt = math.sqrt(self[1] * self[1] + self[2] * self[2])
    return vector2:new(self[1] / dt,self[2] / dt)
end

function vector2:distance(to)
    return math.sqrt((self[1] - to[1])^2 + (self[2] - to[2])^2)
end

function vector2:lerp(to,t)
    local x = self[1] + (to[1] - self[1]) * t
    local z = self[2] + (to[1] - self[2]) * t
    return vector2:new(x,z)
end

function vector2:move_forward(vt,pass)
    local dt = self:distance(vt)
    local t = pass / dt
    if t > 1 then
        t = 1
    end
    return self:lerp(vt,t)
end

function vector2:move_toward(dir,dt)
    local radian = math.atan2(dir[2] / dir[1])
    local x = math.cos(radian) * dt + self[1]
    local z = math.sin(radian) * dt + self[2]
    return vector2:new(x,z)
end

function vector2:rotation(center,angle)
    local radian = math.rad(angle)
    local sin = math.sin(radian)
    local cos = math.cos(radian)
    local rx = (self[1] - center[1]) * cos - (self[2] - center[2]) * sin + center[1]
    local rz = (self[1] - center[1]) * sin + (self[2] - center[2]) * cos + center[2]
    return vector2:new(rx,rz)
end

function vector2:dot(vt)
    return self[1] * vt[1] + self[2] * vt[2]
end

function vector2:cross(vt)
    return self[1] * vt[2] - self[2] * vt[1]
end

_M.vector2 = vector2

return _M
