require "switch"
Tokenizer = {}
Parser = {}
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

function Tokenizer:new(path,isfile)
    local self = setmetatable({path = path,text = "",tokens = {}},Tokenizer)
    Tokenizer.__index = Tokenizer
    if not path then return nil end
    if isfile then 
        local file = io.open(path,'r')
        if not file then return nil end
        self.text = file:read("*all")
        self.text = self.text:upper() .. "\n"
        file:close()
    else self.text = path:upper() .. "\n" end
    return self
end

KEYW = {
------------PROGRAM-------------
['TO']={'TO'},
['GOTO']={'GOTO'},
['PAUSE']={'PAUSE'},
['TYPE']={'TYPE'},
['CLS']={'CLS'},
['END']={'END'},
['SETI']={'SETI'},
['REM']={'REM'},
['IF']={'IF'},
['THEN']={'THEN'},
['LOCAL']={'LOCAL'},
['RETURN']={'RETURN'},
['GOSUB']={'GOSUB'},
['FOR']={'FOR'},
['NEXT']={'NEXT'},
['INPUT']={'INPUT'},
['POINT']={'POINT'},
-------------ROBOT--------------
['MOVE']={'MOVE'},
['MOVEP']={'MOVEP'},
['OPEN']={'OPEN'},
['CLOSE']={'CLOSE'},
['VEL']={'VEL'},
['HOME']={'HOME'},
['OFFLINE']={'OFFLINE'},
['ONLINE']={'ONLINE'},
['IFSIG']={'IFSIG'},
['WAITFOR']={'WAITFOR'},
['OUTSIG']={'OUTSIG'}}

local push = function(table,item) table[#table+1] = item end  
local pop = function(table,item) local it = table[#table]; table[#table] = nil; return it end
local contains = function(t,v) for i=1,#t do if t[i] == v then return true end end return false end

function Tokenizer:tokenize()
    local idx = 1
    local chars = {}
    for i=1,#self.text do chars[#chars+1] = self.text:sub(i,i) end;
    local function advance() idx = idx + 1 end
    local function getString()
        local word = "" 
        while chars[idx] ~= '\"' do word = word .. chars[idx];advance() end
        return {'STR',word}
    end
    local function getWord()
        local word = ""
        while chars[idx]:match("%w") do word = word .. chars[idx];advance() end
        if KEYW[word] then return KEYW[word]
        elseif tonumber(word) then return {'NUM',tonumber(word)}
        else return {'ID',word}
        end
    end
    while idx <= #chars do
        if chars[idx] == '-' then
            push(self.tokens,{'SUB','-'});advance()
        elseif chars[idx] == '^' then
            push(self.tokens,{'POW','^'});advance()
        elseif chars[idx] == '+' then
            push(self.tokens,{'ADD','+'});advance()
        elseif chars[idx] == '*' then
            push(self.tokens,{'MUL','*'});advance()
        elseif chars[idx] == '/' then
            push(self.tokens,{'DIV','/'});advance()
        elseif chars[idx] == '<' then
            push(self.tokens,{'LT','<'});advance()
        elseif chars[idx] == '>' then
            push(self.tokens,{'GT','>'});advance()
        elseif chars[idx] == '(' then
            push(self.tokens,{'LPAR','('});advance()
        elseif chars[idx] == ')' then
            push(self.tokens,{'RPAR',')'});advance()
        elseif chars[idx] == ',' then
            push(self.tokens,{'SEP',','});advance()
        elseif chars[idx] == ';' then
            push(self.tokens,{'SEMI',';'});advance()
        elseif chars[idx] == '=' then
            push(self.tokens,{'EQ','='});advance()
        elseif chars[idx] == '\n' then
            push(self.tokens,{'NL','new line'});advance()
        elseif chars[idx] == '\"' then
            advance()
            push(self.tokens,getString());advance()
        elseif chars[idx]:match("%w") then
            push(self.tokens,getWord());
        else
            advance()
        end
    end
    push(self.tokens,{'EOF'})
    --for i=1,#self.tokens do print(table.unpack(self.tokens[i])) end
    return self.tokens
end

Error = {}

function Parser:new(tokens)
    Parser.__index = Parser
    return setmetatable({tokens = tokens, idx = 1,ops = {},line = 1},Parser)
end

function Parser:advance()
    self.idx = self.idx + 1
end

function Parser:token()
    return self.tokens[self.idx]
end

function Parser:current()
    return self.tokens[self.idx][1]
end

function Parser:value()
    return self.tokens[self.idx][2]
end

function Parser:match(tk)
    return self.tokens[self.idx][1] == tk
end

function Parser:addLabel(label,idx)
    local lb = Symbols.labels[label]
    assert(lb==nil,f("Label '%s' already declared",label))
    Symbols.labels[label] = idx
end

--[[
    -       unary:negation
    * /     binary:multiplicative
    + -     binary:addtive
    < > =   binary:relational
]]

UNMATCH=2
CUSTOM=3

function Parser:assert(condition,error,token)
    if not condition then
        if error == UNMATCH then
            print(f("\x1b[91m[SYNTAX ERROR]\x1b[0m \x1b[92;2mAt Line:\x1b[0m\x1b[92m%d\x1b[0m Expected '%s' , got '%s'",self.line,token[1],token[2]))
        elseif error == CUSTOM then
            print(f("\x1b[91m[SYNTAX ERROR]\x1b[0m \x1b[92;2mAt Line:\x1b[0m\x1b[92m%d\x1b[0m %s",self.line,token))
        else
            print('Unhandled error')
        end
        os.exit(1)
    end
end

function Parser:expr()
    local prec_1 = {'EQ','GT','LT'}
    local prec_2 = {'ADD','SUB'}
    local prec_3 = {'DIV','MUL'}
    local prec_4 = {'SUB'}
    local function atom() 
        local value = self:token()
        if self:match('NUM') or self:match('STR') then
            self:advance()
        elseif self:match('ID') then
            self:assert(Symbols.globals[self:value()],CUSTOM,f("Symbol '%s' not declared",self:value()))
            self:advance()
        elseif self:match('LPAR') then
            self:advance()
            value = self:expr()
            self:assert(self:match('RPAR'),UNMATCH,{')',self:value()})
            self:advance()
        end
        return value
    end
    local function binode(func,ops)
        local lhs = func()
        local rhs = nil
        local op = ''
        while contains(ops,self:current()) and not self:match('EOF') do
            op = self:current();self:advance()
            rhs = func()
            lhs = {op,{lhs,rhs}} 
        end
        return lhs
    end
    local function f_prec_4()
        if self:match('SUB') then self:advance()
            return {'NEG',f_prec_4()}
        else return atom() end
    end
    local function f_prec_3() return binode(f_prec_4,prec_3) end
    local function f_prec_2() return binode(f_prec_3,prec_2) end
    local function f_prec_1() return binode(f_prec_2,prec_1) end
    return f_prec_1()
end

function Parser:parse(EOF)
    local function value_list()
        local list,point = {},nil
        while not self:match('NL') and not self:match(EOF) do
            if self:match('SEP') then self:advance()
            else point = self:expr(); push(list,point[2])
            end
        end
        return list
    end
    local function isvalid(id)
        if #id ~= 1 then return false end
        if id:byte() < string.byte('A') and id:byte() > string.byte('Z') then return false end
        return true 
    end
    if not EOF then EOF = 'EOF' end
    while not self:match(EOF) do
        if self:match('MOVE') or self:match('MOVEX') then
            local op = {self:current(),nil}; self:advance()
            op[2] = value_list()
            push(self.ops,op)
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('MOVEP') or self:match('MOVEXP') then 
            local op = {self:current(),nil}; self:advance()
            self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
            local var = self:value()
            self:assert(Symbols.points[var],CUSTOM,f("Point '%s' not set.",var))
            op[2] = self:value()
            push(self.ops,op);self:advance()
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('POINT') then self:advance()
            local points = {};
            self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
            local point = self:value()
            self:advance()
            Symbols.points[point] = value_list()          
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('VEL') then self:advance()
            local vel = {self:value(),nil}; self:advance()
            self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
            vel[2] = self:expr()
            push(self.ops,{'VEL',vel})
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('GOTO') then self:advance()
            self:assert(self:match('NUM'),CUSTOM,"GOTO Argument must be a number ")
            push(self.ops,{'GOTO',self:value()}); self:advance()
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('HOME') then self:advance()
            push(self.ops,{'HOME'})
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('CLOSE') then self:advance()
            push(self.ops,{'CLOSE'})
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('OPEN') then self:advance()
            push(self.ops,{'OPEN'})
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('CLS') then self:advance()
            push(self.ops,{'CLS'})
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('TYPE') then self:advance()
            local op = {'TYPE',self:expr(),nil}
            if self:match('SEMI') then op[3] = 1; self:advance() end
            push(self.ops,op)
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('PAUSE') then self:advance()
            push(self.ops,{'PAUSE',self:expr()});
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('NUM') then
            local jump = #self.ops+1
            Symbols.labels[self:value()] = jump
            push(self.ops,{'LABEL',self:value(),jump});
            self:advance()
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('END') then self:advance()
            push(self.ops,{'END'})
        elseif self:match('IF') then self:advance()
            local condition = self:expr()
            self:assert(self:match('THEN'),UNMATCH,{'THEN',self:current()}); self:advance()
            push(self.ops,{'IF',condition})
            self:parse('NL')
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('LOCAL') or self:match('SETI') then 
            local op = self:current() ; self:advance()
            self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
            local id = self:value()
            self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'")
            if not Symbols.globals[id] then
                Symbols.globals[id] = {}
            end
            self:advance()
            if op == "SETI" then
            self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
            push(self.ops,{op,id,self:expr()})
            end
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('GOSUB') then self:advance()
            self:assert(self:match('NUM'),CUSTOM,"GOSUB Argument must be a number ")
            push(self.ops,{'GOSUB',self:value()});self:advance()
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('RETURN') then self:advance()
            push(self.ops,{'RETURN'})
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('NL') then self:advance()
            self.line = self.line + 1
        elseif self:match('FOR') then self:advance()
            self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
            local id = self:value()
            self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'"); self:advance()
            self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
            if not Symbols.globals[id] then
                Symbols.globals[id] = {}
            end
            local start = self:expr()
            self:assert(self:match('TO',UNMATCH,{'TO',self:current()})); self:advance()
            local final = self:expr()
            push(self.ops,{'SETI',id,start})
            local jmp = #self.ops
            push(self.ops,{'FOR',id,final,0})
            while not self:match('NEXT') and not self:match(EOF) do
                self:parse('NEXT')
            end
            self:assert(self:match('NEXT',UNMATCH,{'NEXT',self:current()})); self:advance()
            push(self.ops,{'NEXT',id,jmp})
            self.ops[jmp+1][4] = #self.ops
            self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
        elseif self:match('REM') then 
            while not self:match('NL') and not self:match(EOF) do self:advance() end
        elseif self:match('INPUT') then self:advance()
            local op = {'INPUT',nil,nil}
            if self:match('STR') then 
                op[2] = self:expr();
                self:assert(self:match('SEP'),UNMATCH,{',',self:current()}); self:advance()
            else op[2] = {'STR','?'} end
            self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
            local id = self:value()
            self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'"); self:advance()
            if not Symbols.globals[id] then
                Symbols.globals[id] = {}
            end
            op[3] = id
            push(self.ops,op)
        else self:assert(false,CUSTOM,"Unknown token "..self:value()) 
        end
    end 
    return self.ops
end

function Parser:dump()
    local function format_table(t)
        local s = '\x1b[99;2m{\x1b[0m\x1b[97m'
        for i=1,#t do
            if i>1 then s = s .. '\x1b[92;2m,\x1b[0m' end
            if type(t[i])=='table' then s = s .. format_table(t[i])
            else s = s .. t[i] end
        end
        return s .. '\x1b[0m\x1b[99;2m}\x1b[0m'
    end
    local repr = ''
    for i=1,#self.ops do repr =  repr.. '\x1b[99;2m[\x1b[0m\x1b[96;2m'.. i ..'\x1b[0m\x1b[99;2m]\x1b[0m\t'..format_table(self.ops[i]) .. '\n' end
    print(repr)
end

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
            return -eval(expr[2][1])
        else assert(false,"Something wrong i can feel it")
        end
    end
    return eval(expr)
end

--function Evaluator:eval(expr)
--    local eval = {}
--    eval['NUM'] = function(expr)
--            return expr[2]
--        end
--    eval['STR'] = function(expr)
--            return expr[2]
--        end
--    eval['ADD'] = function(expr)
--            return eval[expr[2][1][1]](expr[2][1]) + eval[expr[2][2][1]](expr[2][2])
--        end
--    eval['SUB'] = function(expr)
--            return eval[expr[2][1][1]](expr[2][1]) - eval[expr[2][2][1]](expr[2][2])
--        end
--    return eval[expr[1]](expr)
--end

function Interpreter:run()
    local eval = Evaluator:new()
    local emit = Emitter:new()
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
            --push(Symbols.globals[cmd[2]],{'NUM',eval:eval(cmd[3])})
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
        elseif cmd[1] == "MOVEP"
            or cmd[1] == "OPEN"
            or cmd[1] == "CLOSE"
            or cmd[1] == "HOME"
            or cmd[1] == "HARDHOME"
            or cmd[1] == "VEL"
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
    return setmetatable({},Emitter)
end

function Emitter:exec(inst)
    local eval = Evaluator:new()
    local function movep(args)
        local point = Symbols.points[args[2]]
        print("Movendo ",args[2],eval:eval(point[2]))
    end
    local function open()
    end
    local function close()
    end
    local function home(args)
    end
    local function hardhome(args)
    end
    local function vel(args)
        print("Vel",eval(args[2]))
    end
    local function outsig(args)
    end
    local function get_answer(args)
    end
    switch(inst[1])
        .case('MOVEP',movep)
        .case('OPEN',open)
        .case('CLOSE',close)
        .case('HARDHOME',hardhome)
        .case('HOME',softhome)
        .case('VEL',vel)
        .case('OUTSIG',outsig)
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
