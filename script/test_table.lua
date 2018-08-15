


local t = {1,2,3}

for k,v in pairs(t) do
	print(k,v)
	if k == 1 then
		table.remove(t,4)
	end
end