require "switch"
require "tokenizer"
require "parser"
SerialPort = require "serialport"

Evaluator = {}
Interpreter = {}
Symbols = {
    points = {},
    globals = {},
    subs = {},
    labels = {},
    fors = {}
}

local f = string.format

function Interpreter:new(op)
    Interpreter.__index = Interpreter
    return setmetatable({ops = op, connected = false, port = nil},Interpreter)
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
        elseif expr[1]=='NEG' then
            return -eval(expr[2])
        else assert(false,f("%s,Something wrong i can feel it",expr[1]))
        end
    end
    return eval(expr)
end

function Interpreter:run()
    local eval = Evaluator:new()
    local serial = SerialPort:new("COM1")
    local emit = Emitter:new()
    emit:setport(serial)
    local idx = 1
    local count = 1
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
        elseif cmd[1] == 'SETI' then
            local var = Symbols.globals[cmd[2]]
            if not var then push(Symbols.globals[cmd[2]],{'NUM',eval:eval(cmd[3])})
            else var[#var] = {'NUM',eval:eval(cmd[3])}
            end
        elseif cmd[1] == 'END' then
            run_cmd = 0
        elseif cmd[1] == 'LOCAL' then
            local sub = Symbols.subs
            push(sub[#sub],cmd[2])
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
        elseif cmd[1] == 'PAUSE'
            or cmd[1] == "MOVEP"
            or cmd[1] == "OPEN"
            or cmd[1] == "CLOSE"

            or cmd[1] == "HOME"
            or cmd[1] == "HARDHOME"
            or cmd[1] == "VEL"
            or cmd[1] == "SEND"
            or cmd[1] == "OUTSIG" then
            
            emit:exec(cmd)
        else
            assert(false,cmd[1] ..' Not implemented')
        end
        advance()
    end
end

Emitter = {}

function Emitter:new()
    Emitter.__index = Emitter
    return setmetatable({port = nil},Emitter)
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

function Emitter:exec(inst)
    local motors = {'B','C','D','E','F'}
    local eval = Evaluator:new()
    local function set_position(point)
        for i=1,#motors do
            self:write(f("pd,%s,%d\r",motors[i],eval:eval(point[i])))
            self:wait(10)
        end
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
    local function movep(args)
        local point = Symbols.points[args[2]]

        set_position(point)
        
        self:write("mc\r")
        self:wait(200)
        while (motor_busy()==1) do
        end
        for i=1,#motors do
            print(f("pa,%s\r",motors[i]))
            -- Check Return == Set
        end
        -- If ss == 0 Proceed
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
        self:wait(200)
        while(motor_busy()==1)do
        end
        for i=1,#motors do
            print(f("pa,%s\r",motors[i]))
            -- Check Return == Set
        end
        -- If ss == 0 Proceed
    end
    local function pause(args)
        local time = eval:eval(args[2])
        self:wait(time*1000)
    end
    local function hardhome(args)
        print("hh\r")
        -- Loop check_system_status until Finish
    end
    local function vel(args)
        self:write(f("vs,%s,%d",args[2][1],eval:eval(args[2][2])))
        self:wait(100)
    end
    local function outsig(args)
    end
    local function send(args)
        print("tc\r")
        print("ts,1,1\r")
        print(f("td,%s\r",args[2][2]))
    end
    local function get_answer(args)
    end
    switch(inst[1])
        .case('MOVEP',movep)
        .case('OPEN',open)
        .case('CLOSE',close)
        .case('HARDHOME',hardhome)
        .case('HOME',home)
        .case('VEL',vel)
        .case('PAUSE',pause)
        .case('OUTSIG',outsig)
        .case('SEND',send)
        .exec(inst)
end

function main()
    local tokenizer = Tokenizer:new(arg[1],true)
    local parser = Parser:new(tokenizer:tokenize())
    local ops = parser:parse()
    parser:dump()
    local interpreter = Interpreter:new(parser.ops)
    interpreter:run()
end

main()