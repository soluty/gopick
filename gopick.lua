local M = {}

local function create_go_zero_obj(typ)
	if string.sub(typ, 1, 1) == "*" then
		return string.format("= new(%s)", string.sub(typ, 2, -1))
	end
	return string.format("%s", typ)
end

local function create_go_main_call(name, params, receiver)
	local lines = {
		"func main() {",
	}
	if receiver ~= nil then
		table.insert(lines, string.format("var r %s", create_go_zero_obj(receiver)))
	end
	for i, param in ipairs(params) do
		table.insert(lines, string.format("var v%d %s", i, create_go_zero_obj(param)))
	end
	local line = ""
	if receiver ~= nil then
		line = "r."
	end
	line = line .. name .. "("
	for i, _ in ipairs(params) do
		line = line .. "v" .. tostring(i)
		if i ~= #params then
			line = line .. ","
		end
	end
	line = line .. ")"
	table.insert(lines, line)
	table.insert(lines, "}")
	return lines
end

local function parse_go_func(line)
	-- -- Example
	-- line = "func main(a *Person, b string) {"
	-- line = "func (a *Unit)main(a *Person, b string) {"
	-- -- Example
	local functionName, parameters, receiver
	if string.sub(line, 6, 6) == "(" then
		receiver, functionName, parameters = line:match("func%s+%((.*)%)([%w_]+)%((.*)%)")
	else
		functionName, parameters = line:match("func%s+([%w_]+)%((.*)%)")
	end
	local receiverType
	local params = {}
	if receiver ~= nil then
		for param in receiver:gmatch("([^,]*)") do
			local _, paramType = param:match("(%w+)%s+([%*]?[%w_]+)")
			receiverType = paramType
			break
		end
	end
	if parameters ~= nil then
		for param in parameters:gmatch("([^,]*)") do
			local paramName, paramType = param:match("(%w+)%s+([%*]?[%w_]+)")
			if paramName ~= nil and paramType ~= nil then
				table.insert(params, paramType)
			end
		end
	end
	return functionName, params, receiverType
end

local function create_go_main_byline(line)
	local name, params, receiver = parse_go_func(line)
	local mainTable = create_go_main_call(name, params, receiver)
	return table.concat(mainTable, "\n")
end

local function call_bash(cmd)
	local c = io.popen(cmd)
	if not c then
		vim.notify("open command( " .. cmd .. " )failed.", vim.log.levels.ERROR)
		return
	end
	local output = c:read("*a")
	c:close()
	return output
end

local function pick_import(file)
	return call_bash("gopickimports " .. file)
end

-- if exist main func, change main func name to main____runner____
-- if package is not main, change package to main
M.process_file = function(file)
	local cmd =
		string.format([[sed -e 's/^package.*/package main/' -e 's/^func main(){/func main____runner____(){/' %s]], file)
	return call_bash(cmd)
end

M.create_main_file_content = function(file, line)
	return "package main\n" .. pick_import(file) .. "\n" .. create_go_main_byline(line)
end

return M
