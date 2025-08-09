--  PARSER
local sim = require('sim')

Parser = {}

-- Global Symbol Table
Symbols = {
    points = {},
    globals = {},
    subs = {},
    labels = {}
}

local f = string.format

-- @brief Parser object Constructor 
function Parser:new()
    Parser.__index = Parser
    return setmetatable({tokens = nil, idx = 1,ops = {},line = 1,error = false,statement = nil},Parser)
end

-- @brief Advance parser index
function Parser:advance()
    self.idx = self.idx + 1
end

-- @return (table token) Returns current token key:value pair  
function Parser:token()
    return self.tokens[self.idx]
end
 
-- @return (string key) Returns current token key
function Parser:current()
    return self.tokens[self.idx][1]
end

-- @return (any value) Returns current token value 
function Parser:value()
    return self.tokens[self.idx][2]
end

-- @return (bool result) Returns true if current token matches tk
function Parser:match(tk)
    return self.tokens[self.idx][1] == tk
end

-- @brief Clears Parser state and Symbol table
function Parser:cleanup()
    self.idx = 1
    self.line = 1
    self.error = false
    self.tokens = nil
    self.ops = {}
    Symbols.points = {}
    Symbols.globals = {}
    Symbols.subs = {}
    Symbols.labels = {}
end

UNMATCH=2
CUSTOM=3

-- @brief Parser assertion, set a signal to stop parsing if condition fails
function Parser:assert(condition,error,token)
    --print(condition)
    if not condition then
        if error == UNMATCH then
            sim.addLog(420,f("[SYNTAX ERROR] At Line:%d Expected '%s' , got '%s'",self.line,token[1],token[2]))
        elseif error == CUSTOM then
            sim.addLog(420,f("[SYNTAX ERROR] At Line:%d %s",self.line,token))
        else
            sim.addLog(420,'Unhandled error')
        end
        self.error = true
    end
end

-- @brief Recursive Descent Expression parser
-- @return (table ast) Returns a table as an AST representing a math unary/binary operation
function Parser:expr()
    local prec_1 = {'EQ','GT','LT'}
    local prec_2 = {'ADD','SUB'}
    local prec_3 = {'DIV','MUL'}
    local prec_4 = {'POW'}
    local prec_5 = {'SUB'}
    local function atom() 
        local value = self:token()
        if self:match('NUM') or self:match('STR') then
            self:advance()
            return value
        elseif self:match('ID') then
            self:assert(Symbols.globals[self:value()],CUSTOM,f("Symbol '%s' not declared",self:value()))
            self:advance()
            return value
        elseif self:match('LPAR') then
            self:advance()
            value = self:expr()
            self:assert(self:match('RPAR'),UNMATCH,{')',self:value()})
            self:advance()
            return value
        end
        return nil
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
    
    local function f_prec_5()
        if self:match('SUB') then self:advance()
            return {'NEG',f_prec_5()}
        else return atom() end
    end
    local function f_prec_4() return binode(f_prec_5,prec_4) end
    local function f_prec_3() return binode(f_prec_4,prec_3) end
    local function f_prec_2() return binode(f_prec_3,prec_2) end
    local function f_prec_1() return binode(f_prec_2,prec_1) end
    return f_prec_1()
end

-- @brief Register functions to be used in Parser Switch Case
function Parser:register()
    local function value_list()
        local list,point = {},nil
        repeat
            if self:match('SEP') then self:advance() end
            point = self:expr()
            if point then push(list,point) end
        until not self:match('SEP')
        return list
    end
    local function isvalid(id)
        if #id == 1 then
            if id:byte() < string.byte('A') or id:byte() > string.byte('Z') then return false end
        elseif #id == 2 then
            local bytes = {string.byte(id,1,-1)}
            if bytes[1] ~= string.byte('@') then return false end
            if bytes[2] < string.byte('A') or bytes[2] > string.byte('Z') then return false end
        else return false end
        return true 
    end
    local function move()
        local op = {'MOVE',nil}; self:advance()
        if self:match('TO') then op[1] = 'MOVETO' ;self:advance() end
        op[2] = value_list()
        self:assert(#op[2]==5,CUSTOM,"Expected at least 5 position values")
        if self.error then return end
        push(self.ops,op)
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function movep()
        local op = {self:current(),nil}; self:advance()
        self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
        if self.error then return end
        local var = self:value()
        self:assert(Symbols.points[var],CUSTOM,f("Point '%s' not set.",var))
        if self.error then return end
        op[2] = self:value()
        push(self.ops,op);self:advance()
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function point()
        self:advance()
        local points = {};
        self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
        if self.error then return end
        local point = self:value()
        self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        if self.error then return end
        local values = value_list()
        self:assert(#values==5,CUSTOM,"Expected at least 5 position values")
        if self.error then return end
        Symbols.points[point] = values
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function vel()
        self:advance()
        self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
        if self.error then return end
        local motor = self:value(); self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        if self.error then return end
        local vel = self:expr()
        push(self.ops,{'VEL',motor,vel})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rgoto()
        self:advance()
        self:assert(self:match('NUM'),CUSTOM,"GOTO Argument must be a number ")
        if self.error then return end
        push(self.ops,{'GOTO',self:value()}); self:advance()
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function home()
        self:advance()
        push(self.ops,{'HOME'})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function close()
        self:advance()
        push(self.ops,{'CLOSE'})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function open()
        self:advance()
        push(self.ops,{'OPEN'})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function cls()
        self:advance()
        push(self.ops,{'CLS'})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rtype()
        self:advance()
        local expr = self:expr()
        self:assert(expr,CUSTOM,'Invalid Expression')
        if self.error then return end
        local op = {'TYPE',expr,nil}
        if self:match('SEMI') then op[3] = 1; self:advance() end
        push(self.ops,op)
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function pause()
        self:advance()
        push(self.ops,{'PAUSE',self:expr()});
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function label()
        local jump = #self.ops+1
        local lb = self:value()
        self:assert(Symbols.labels[lb]==nil,CUSTOM,f("Label %d is already defined",lb))
        if self.error then return end
        Symbols.labels[lb] = jump
        push(self.ops,{'LABEL',self:value(),jump});
        self:advance()
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rend()
        self:advance()
        push(self.ops,{'END'})
    end
    local function rif()
        self:advance()
        local condition = self:expr()
        self:assert(self:match('THEN'),UNMATCH,{'THEN',self:current()}); self:advance()
        if self.error then return end
        push(self.ops,{'IF',condition})
        self:parse('NL')
        if self.error then return end
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function seti()
        local op = self:current() ; self:advance()
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        if self.error then return end
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'")
        if self.error then return end
        if not Symbols.globals[id] then
            Symbols.globals[id] = {}
        end
        self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        if self.error then return end
        push(self.ops,{op,id,self:expr()})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rlocal()
        self:advance()
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        if self.error then return end
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'")
        if self.error then return end
        self:advance()
        push(self.ops,{'LOCAL',id})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function gosub()
        self:advance()
        self:assert(self:match('NUM'),CUSTOM,"GOSUB Argument must be a number ")
        if self.error then return end
        push(self.ops,{'GOSUB',self:value()});self:advance()
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rreturn()
        self:advance()
        push(self.ops,{'RETURN'})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rem()
        while not self:match('NL') and not self:match(EOF) do self:advance() end
    end
    local function rfor()
        self:advance()
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        if self.error then return end
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'"); self:advance()
        if self.error then return end
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        if self.error then return end
        if not Symbols.globals[id] then
            Symbols.globals[id] = {}
        end
        local start = self:expr()
        self:assert(self:match('TO',UNMATCH,{'TO',self:current()})); self:advance()
        if self.error then return end
        local final = self:expr()
        push(self.ops,{'SETI',id,start})
        local jmp = #self.ops
        push(self.ops,{'FOR',id,final,0})
        while not self:match('NEXT') and not self:match(EOF) do
            self:parse('NEXT')
            if self.error then return end
        end
        self:assert(self:match('NEXT',UNMATCH,{'NEXT',self:current()})); self:advance()
        if self.error then return end
        push(self.ops,{'NEXT',id,jmp})
        self.ops[jmp+1][4] = #self.ops
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function input()
        self:advance()
        local op = {'INPUT',nil,nil}
        if self:match('STR') then 
            op[2] = self:expr();
            self:assert(self:match('SEP'),UNMATCH,{',',self:current()}); self:advance()
            if self.error then return end
        else op[2] = {'STR','?'} end
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        if self.error then return end
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'"); self:advance()
        if self.error then return end
        if not Symbols.globals[id] then
            Symbols.globals[id] = {}
        end
        op[3] = id
        push(self.ops,op)
    end
    local function send()
        self:advance()
        self:assert(self:match('STR'),UNMATCH,{'String',self:current()})
        if self.error then return end
        local arg = self:expr()
        push(self.ops,{'SEND',arg})
    end
    local function hardhome()
        self:advance()
        push(self.ops,{'HARDHOME'})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function assign()
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        if self.error then return end
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Integer or Float (@) Identifier from 'A' to 'Z'")
        if self.error then return end
        self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        if self.error then return end
        local value = self:expr()
        push(self.ops,{'ASSIGN',id,value})
        if not Symbols.globals[id] then Symbols.globals[id] = {} end
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()}) 
    end
    local function ifsig()
        self:advance()
        local condition = value_list()
        self:assert(#condition>0,CUSTOM,"Expected at least 1 signal")
        if self.error then return end
        self:assert(self:match('THEN'),UNMATCH,{'THEN',self:current()}); self:advance()
        if self.error then return end
        push(self.ops,{'IFSIG',condition})
        self:parse('NL')
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function outsig()
        self:advance()
        local sig = value_list()
        self:assert(#sig>0,CUSTOM,"Expected at least 1 signal")
        if self.error then return end
        push(self.ops,{'OUTSIG',sig})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function waitfor()
        self:advance()
        local conds = value_list()
        self:assert(#conds>0,CUSTOM,"Expected at least 1 signal")
        if self.error then return end
        push(self.ops,{'WAITFOR',conds})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    
    self.statement = Switch:new():build()
        :case('MOVE',move)
        :case('MOVEP',movep)
        :case('POINT',point)
        :case('VEL',vel)
        :case('GOTO',rgoto)
        :case('HOME',home)
        :case('HARDHOME',hardhome)
        :case('CLOSE',close)
        :case('OPEN',open)
        :case('CLS',cls)
        :case('TYPE',rtype)
        :case('PAUSE',pause)
        :case('NUM',label)
        :case('END',rend)
        :case('IF',rif)
        :case('SETI',seti)
        :case('LOCAL',rlocal)
        :case('GOSUB',gosub)
        :case('RETURN',rreturn)
        :case('FOR',rfor)
        :case('REM',rem)
        :case('INPUT',input)
        :case('SEND',send)
        :case('OUTSIG',outsig)
        :case('IFSIG',ifsig)
        :case('WAITFOR',waitfor)
        :case('ID',assign)
        :default(function(p) p:assert(false,CUSTOM,"Unknown token "..p:value()) end)
end

-- @brief Parser main function.
-- @param (string EOF) A token to be used as End of File, defaults to 'EOF'.
-- @return (table operations) List of instructions to be used by Interpreter. 
function Parser:parse(EOF)
    if not EOF then EOF = 'EOF' end

    while not self:match(EOF) do
        if self.error then return nil end
        if self:match('NL') then 
            self:advance()
            self.line = self.line + 1
        else
            self.statement:switch(self:current(),self)
        end
    end
    return self.ops
end

-- @brief Generates a visual representation of operations.
function Parser:dump()
    local function format_table(t)
        local s = '{'
        for i=1,#t do
            if i>1 then s = s .. ',' end
            if type(t[i])=='table' then s = s .. format_table(t[i])
            else s = s .. t[i] end
        end
        return s .. '}'
    end
    local repr = ''
    for i=1,#self.ops do repr =  repr.. '['.. i ..']\t'..format_table(self.ops[i]) .. '\n' end
    return repr
end