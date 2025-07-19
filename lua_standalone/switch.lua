Switch = {}

function Switch:new()
	Switch.__index = Switch
	return setmetatable({default = nil, functions = {}},Switch)
end

function Switch:build()
	function Switch:case(value,block)
		self.functions[value] = block
		return self
	end
	function Switch:default(block)
		self.default = block
		return self
	end
	function Switch:switch(value,args)
		local case = self.functions[value]
		if case then
			case(args)
		elseif self.default then
			self.default(args)
		end
	end
	return self
end

function switch(object)
    local Table = {
        value = object,
        default = nil,
        functions = {}
    }
    function Table.case(value,block)
        Table.functions[value] = block
        return Table
    end
    function Table.default(block)
        Table.default = block
        return Table
    end
    function Table.exec(args)
        local case = Table.functions[Table.value]
        if case then
            case(args)
        elseif Table.default then
            Table.default()
        end
    end    
    return Table
end

function switch_build()
    local Table = {
        value = nil,
        default = nil,
        functions = {}
    }
    function Table.case(value,block)
        Table.functions[value] = block
        return Table
    end
    function Table.default(block)
        Table.default = block
        return Table
    end    
    return Table
end

function switch_exec(Table,object,args)
    Table.value = object
    local case = Table.functions[Table.value]
        if case then
            case(args)
        elseif Table.default then
            Table.default()
        end
end

--[[
    local opt = switch_build()
                .case(1,function() print("case 1")end)
                .case(2,function(args) print("case 2",args)end)
    switch_exec(opt,2,"abas")
]]


