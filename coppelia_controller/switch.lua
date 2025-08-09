--  SWITCH
Switch = {}

-- @brief Switch object Constructor
function Switch:new()
	Switch.__index = Switch
	return setmetatable({default = nil, functions = {}},Switch)
end

-- @brief Switch Case builder
-- @return (table switch) Switch Case Lookup Table 
function Switch:build()
    -- @brief Adds a case (key:value pair) with a key and function to execute. 
    -- @param (any key) Anything as a key
    -- @param (function func) A function body or function object
    -- @return (table switch) Switch Case Lookup Table
	function Switch:case(key,func)
		self.functions[key] = func
		return self
	end
    -- @brief Adds a default function to be executed if there is no matches  
    -- @param (function block) A function body or function object
    -- @return (table switch) Switch Case Lookup Table
	function Switch:default(block)
		self.default = block
		return self
	end
    -- @brief Executes the Swicth Case, by running the function registered for the key
    -- @param (any key) A key to be searched
    -- @param (any args) Argument to the function to be executed
    -- @return (any result) Optional return
	function Switch:switch(key,args)
		local case = self.functions[key]
		if case then
			return case(args)
		elseif self.default then
			return self.default(args)
		end
	end
	return self
end
