-- RUNTIME

local sim = require('sim')
local f = string.format

-- sim.addLog(420,"error on script")
-- sim.addLog(200,"error on script and console")
-- sim.addLog(430,"warning on script")
-- sim.addLog(300,"warning on script and console")

-- Runtime Namespace 
Runtime = {}

-- Runtime Global Control Variables.
-- Since there is no real 'threading' in Lua, its unlikely to have a race condition
-- on these variables. Also, all the scripts are in the same enviroment, due to 'require'.
-- So it is faster to use globals, than signals. But external Scripts, and Joint Callbacks
-- still needs to use signals, such as grippers.

Runtime.enabled = false
Runtime.output = 0
Runtime.input = 0
Runtime.connected = false
Runtime.cancelPending = false
Runtime.gripSignal = 0
Runtime.paused = false

-- @brief Runtime assertion, set a signal to stop execution if condition fails
function Runtime.assert(condition,cmd,msg)
    if not condition then
        sim.addLog(420,f("[RUNTIME ERROR] At Instruction: %s %s",cmd,msg))
        Runtime.enabled = false
    end
end

-- @brief Resumes a coroutine, checking its state and outputing error information
function Runtime.resume(coro)
    if coroutine.status(coro) ~= 'dead' then
        local ok, errorMsg = coroutine.resume(coro)
        if errorMsg then error(debug.traceback(coro, errorMsg), 2) end
    end
end

Evaluator = {}

-- @brief Evaluator object Constructor
function Evaluator:new()
    Evaluator.__index = Evaluator
    return setmetatable({},Evaluator)
end

-- @param (table expr) Expression binary tree to be evaluated
-- @return (number|string) Return of evaluated expression 
function Evaluator:eval(expr)
    local function eval(expr)
        if expr[1]=='NUM' or expr[1]=='STR' then
            return expr[2]
        elseif expr[1]=='ID' then
            local var = Symbols.globals[expr[2]]
            return eval(var[#var])
        elseif expr[1]=='ADD' then
            return eval(expr[2][1]) + eval(expr[2][2])
        elseif expr[1]=='SUB' then
            return eval(expr[2][1]) - eval(expr[2][2])
        elseif expr[1]=='MUL' then
            return eval(expr[2][1]) * eval(expr[2][2])
        elseif expr[1]=='DIV' then
            return eval(expr[2][1]) / eval(expr[2][2])
        elseif expr[1]=='EQ' then
            return eval(expr[2][1]) == eval(expr[2][2])
        elseif expr[1]=='GT' then
            return eval(expr[2][1]) > eval(expr[2][2])
        elseif expr[1]=='LT' then
            return eval(expr[2][1]) < eval(expr[2][2])
        elseif expr[1]=='POW' then
            return eval(expr[2][1]) ^ eval(expr[2][2])
        elseif expr[1]=='NEG' then
            return -eval(expr[2])
        else 
        sim.addLog(420,f("%s,Something wrong i can feel it",expr[1]))
        Runtime.enabled = false
        end
    end
    return eval(expr)
end