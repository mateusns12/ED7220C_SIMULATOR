require "switch"
require "tokenizer"
require "parser"
SerialPort = require "serialport"

Evaluator = {}
Interpreter = {}
Emitter = {}
Runtime = {}
local f = string.format

function Runtime.assert(condition,cmd,msg)
    if not condition then
        print(f("\x1b[91m[RUNTIME ERROR]\x1b[0m \x1b[92;2mAt Instruction: \x1b[0m\x1b[93m%s\x1b[0m %s",cmd,msg))
    end
end

function Evaluator:new()
    Evaluator.__index = Evaluator
    return setmetatable({},Evaluator)
end

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
        else assert(false,f("%s,Something wrong i can feel it",expr[1]))
        end
    end
    return eval(expr)
end

function Interpreter:new(op,em)
    Interpreter.__index = Interpreter
    return setmetatable({ops = op, connected = false, emitter = em},Interpreter)
end

function Interpreter:run()
    local eval = Evaluator:new()
    local idx = 1
    local advance = function() idx = idx + 1 end
    while idx <= #self.ops do
        local cmd = self.ops[idx]
        if run_cmd == 0 then break end
        if cmd[1] == 'TYPE' then
            local p = f("%s",eval:eval(cmd[2]))
            if not cmd[3] then p = p .. "\n" end
            io.write(p)
        elseif cmd[1] == 'IF' then
            local result = eval:eval(cmd[2])
            if result == false then advance() end   
        elseif cmd[1] == 'GOTO' then
            idx = Symbols.labels[cmd[2]]
        elseif cmd[1] == 'SETI'
            or cmd[1] == 'ASSIGN'then
            local var = Symbols.globals[cmd[2]]
            if not var then push(Symbols.globals[cmd[2]],{'NUM',eval:eval(cmd[3])})
            else var[#var] = {'NUM',eval:eval(cmd[3])}
            end
        elseif cmd[1] == 'END' then
            run_cmd = 0
        elseif cmd[1] == 'LOCAL' then
            local sub = Symbols.subs
            Runtime.assert(sub[#sub],'LOCAL',"Local variable outside of a subroutine")
            push(sub[#sub],cmd[2])
            push(Symbols.globals[cmd[2]],{'NUM',0})
        elseif cmd[1] == 'GOSUB' then
            push(Symbols.subs,{cmd[2],idx})
            idx = Symbols.labels[cmd[2]]
        elseif cmd[1] == 'RETURN' then
            local ret = pop(Symbols.subs)
            for i=3,#ret do
                local var = Symbols.globals[ret[i]]; pop(var)
            end
            idx = ret[2]
        elseif cmd[1] == 'FOR' then
            local var = Symbols.globals[cmd[2]]
            if eval:eval(var[#var]) > eval:eval(cmd[3]) then
                idx = cmd[4]
            end
        elseif cmd[1] == 'NEXT' then
            local var = Symbols.globals[cmd[2]]
            var[#var] = {'NUM',eval:eval(var[#var])+1}
            idx = cmd[3]
        elseif cmd[1] == 'LABEL' then
        elseif cmd[1] == 'INPUT' then
            io.write(cmd[2][2])
            v = io.read()
            local var = Symbols.globals[cmd[3]]
            if not var then push(Symbols.globals[cmd[3]],{'NUM',v})
            else var[#var] = {'NUM',v}
            end
        ------------------------------------------------
        elseif cmd[1] == 'CLS' then
        ------------------------------------------------
        elseif cmd[1] == 'IFSIG' then
            self.emitter:exec(cmd) 
            if cmd[3] == 0 then advance() end   
        else
            self.emitter:exec(cmd)     
        end
        advance()
    end
end

function Emitter:new()
    Emitter.__index = Emitter
    return setmetatable({port = nil,eval = Evaluator:new(),motors = {'B','C','D','E','F'}},Emitter)
end

function Emitter:setport(port)
    self.port = port
    self.port:open()
end

function Emitter:closeport()
    self.port:close()
end

function Emitter:write(cmd)
    self.port:write(cmd)
end

function Emitter:read()
    return self.port:read()
end

function Emitter:wait(delay)
    return self.port:wait(delay)
end

function Emitter:register()
    local function set_position(point)
        for i=1,#self.motors do
            self:write(f("pd,%s,%d\r",self.motors[i],self.eval:eval(point[i])))
            self:wait(50)
        end
    end
    local function get_position()
        local pos = {}
        for i=1,#self.motors do
            self:write(f("pa,%s\r",self.motors[i]))
            self:wait(100)
            local res,msg = self:read()
            push(pos,msg)
        end
        return pos
    end
    local function motor_busy()
        self:write('ss\r')
        self:wait(100)
        local ret,msg = self:read()
        local status = tonumber(msg)
        local busy = (status&128) >>7
        return busy
    end
    local function check_system_status()
        self:write('ss\r')
        self:wait(100)
        ret,msg = self:read()
    end
    local function move(args)
        local point = Symbols.points[args[2]]
        for i=1,#self.motors do
            self:write(f("pr,%s,%d\r",self.motors[i],self.eval:eval(point[i])))
            self:wait(50)
        end
        self:write("mc\r")
        self:wait(100)
        while (motor_busy()==1) do
        end
        local final_pos = get_position()
    end
    local function movep(args)
        local point = Symbols.points[args[2]]
        set_position(point)
        self:write("mc\r")
        self:wait(100)
        while (motor_busy()==1) do
        end
        local final_pos = get_position()
    end
    local function open()
        self:write("go\r") 
        self:wait(100)
        while(motor_busy()==1)do
        end
        self:write("gs\r")
        self:wait(100)
        local ret,msg = self:read()
    end
    local function close()
        self:write("gc\r") 
        self:wait(100)
        while(motor_busy()==1)do
        end
        self:write("gs\r")
        self:wait(100)
        local ret,msg = self:read()
    end
    local function home(args)
        set_position({{'NUM',0},{'NUM',0},{'NUM',0},{'NUM',0},{'NUM',0}})
        self:write("mc\r")   -- Start
        self:wait(100)
        while(motor_busy()==1)do
        end
        local pos = get_position()
    end
    local function pause(args)
        local time = eval:eval(args[2])
        self:wait(time*1000)
    end
    local function hardhome(args)
        self:write("hh\r")
        while(motor_busy()==1)do
        end
        -- Loop check_system_status until Finish
        local pos = get_position()
    end
    local function vel(args)
        self:write(f("vs,%s,%d",args[2][1],eval:eval(args[2][2])))
        self:wait(100)
    end
    local function outsig(args)
    end
    local function send(args)
        self:write("tc\r")
        self:wait(50)
        self:write("ts,1,1\r")
        self:wait(50)
        self:write(f("td,%s\r",args[2][2]))
        self:wait(100)
    end
    local function get_answer(args)
    end
    local function validate_sig(sig)
        if sig < 1 or sig > 8 then return false end
        return true 
    end
    local function input_pending()
        self:write("ss\r")
        self:wait(100)
        local ret,msg = self:read()
        local status = tonumber(msg)
        local pending = (status&16) >>4
        return pending
    end
    local function waitfor(args)
        for i=1,#args[2] do
            local sig = self.eval:eval(args[2][i])
            Runtime.assert(validate_sig(math.abs(sig)),args[1],'Out of Bounds')
            if sig > 0 then
                self:write(f("wi,%s,%d\r",sig,1))
            else
                self:write(f("wi,%s,%d\r",math.abs(sig),0))
            end
        end
        while(input_pending()==1)do end
    end
    local function outsig(args)
        local out = 0
        for i=1,#args[2] do
            local sig = self.eval:eval(args[2][i])
            Runtime.assert(validate_sig(math.abs(sig)),args[1],'Out of Bounds')
            if sig > 0 then
                out = out | 1 << (sig-1)
            end
        end
        self:write(f("op,%s\r",out))
    end
    local function ifsig(args)
        self:write("ip\r")
        self:wait(100)
        local ret,msg = self:read()
        local state = tonumber(msg)
        local result = 1
        for i=1,#args[2] do
            local sig = self.eval:eval(args[2][i])
            Runtime.assert(validate_sig(math.abs(sig)),args[1],'Out of Bounds')
            local level = 0
            if sig > 0 then level = 1 else level = 0 end
            sig = math.abs(sig)
            result = result and ((state&2^(sig-1))>>(sig-1))
        end
        args[3] = result
    end

    return Switch:new():build()
        :case("MOVE",move)
        :case('MOVEP',movep)
        :case('OPEN',open)
        :case('CLOSE',close)
        :case('VEL',vel)
        :case('HARDHOME',hardhome)
        :case('HOME',home)
        :case('WAITFOR',waitfor)
        :case('IFSIG',ifsig)
        :case('OUTSIG',outsig)
        :case('PAUSE',pause)
        :case('SEND',send)
        :default(function(args) 
            Runtime.assert(false,'--',"Operation "..args[1].." not implemented") 
        end)
end

function Emitter:exec(inst)
    local operation = self:register()
    return operation:switch(inst[1],inst)
end

function main()
    local tokenizer = Tokenizer:new(arg[1],true)
    local parser = Parser:new(tokenizer:tokenize())
    local ops = parser:parse()
    parser:dump()
    local serial = SerialPort:new(arg[2])
    local emitter = Emitter:new()
    emitter:setport(serial)
    local interpreter = Interpreter:new(parser.ops,emitter)
    interpreter:run()
end

main()