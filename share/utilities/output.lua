local oldwrite = io.write
module(..., package.seeall)
--- wsapi write function
local write = function(...)
	local resp = webylene.response
	if not resp then
		return oldwrite(...)
	end
	for i, arg in ipairs({...}) do
		resp:write(arg and tostring(arg) or "")
	end
end
_G.write = write

--- print replacement. expects all paramenters to already be concatenable as strings
_G.print = function(...)
	write(table.concat({...},"\t") .. "\n")
end 