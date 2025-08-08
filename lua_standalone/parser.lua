Parser = {}

Symbols = {
    points = {},
    globals = {},
    subs = {},
    labels = {}
}

local f = string.format

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
    local prec_4 = {'POW'}
    local prec_5 = {'SUB'}
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

function Parser:register()
    local function value_list()
        local list,point = {},nil
        --while not (self:match('NL') or self:match(EOF) or self:match('THEN'))do
        repeat
            if self:match('SEP') then self:advance() end
            point = self:expr()
            if point then push(list,point) end
        until not self:match('SEP')
        return list
    end
    local function isvalid(id)
        if #id == 1 then
            if id:byte() < string.byte('A') and id:byte() > string.byte('Z') then return false end
        elseif #id == 2 then
            local bytes = {string.byte(id,1,-1)}
            if bytes[1] ~= string.byte('@') then return false end
            if bytes[2] < string.byte('A') and bytes[2] > string.byte('Z') then return false end
        else return false end
        return true 
    end
    local function move()
        local op = {'MOVE',nil}; self:advance()
        if self:match('TO') then op[1] = 'MOVETO' ;self:advance() end
        op[2] = value_list()
        push(self.ops,op)
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function movep()
        local op = {self:current(),nil}; self:advance()
        self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
        local var = self:value()
        self:assert(Symbols.points[var],CUSTOM,f("Point '%s' not set.",var))
        op[2] = self:value()
        push(self.ops,op);self:advance()
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function point()
        self:advance()
        local points = {};
        self:assert(self:match('ID'),CUSTOM,"Argument is not a variable")
        local point = self:value()
        self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        Symbols.points[point] = value_list()
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function vel()
        self:advance()
        local vel = {self:value(),nil}; self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        vel[2] = self:expr()
        push(self.ops,{'VEL',vel})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rgoto()
        self:advance()
        self:assert(self:match('NUM'),CUSTOM,"GOTO Argument must be a number ")
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
        local op = {'TYPE',self:expr(),nil}
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
        Symbols.labels[self:value()] = jump
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
        push(self.ops,{'IF',condition})
        self:parse('NL')
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function seti()
        local op = self:current() ; self:advance()
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'")
        if not Symbols.globals[id] then
            Symbols.globals[id] = {}
        end
        self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        push(self.ops,{op,id,self:expr()})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function rlocal()
        self:advance()
        self:assert(self:match('ID'),UNMATCH,{'Identifier',self:current()})
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Identifier from 'A' to 'Z'")
        self:advance()
        push(self.ops,{'LOCAL',id})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function gosub()
        self:advance()
        self:assert(self:match('NUM'),CUSTOM,"GOSUB Argument must be a number ")
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
    end
    local function input()
        self:advance()
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
    end
    local function send()
        self:advance()
        self:assert(self:match('STR'),UNMATCH,{'String',self:current()})
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
        local id = self:value()
        self:assert(isvalid(id),CUSTOM,"Expected Integer or float (@) Identifier from 'A' to 'Z'")
        self:advance()
        self:assert(self:match('EQ'),UNMATCH,{'=',self:current()}); self:advance()
        push(self.ops,{'ASSIGN',id,self:expr()})
        if not Symbols.globals[id] then Symbols.globals[id] = {} end
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()}) 
    end
    local function ifsig()
        self:advance()
        local condition = value_list()
        self:assert(self:match('THEN'),UNMATCH,{'THEN',self:current()}); self:advance()
        push(self.ops,{'IFSIG',condition})
        self:parse('NL')
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function outsig()
        self:advance()
        local sig = value_list()
        push(self.ops,{'OUTSIG',sig})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local function waitfor()
        self:advance()
        local conds = value_list()
        push(self.ops,{'WAITFOR',conds})
        self:assert(self:match('NL'),UNMATCH,{'new line',self:current()})
    end
    local statement = Switch:new()

    statement:build()
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

    return statement
end

function Parser:parse(EOF)
    if not EOF then EOF = 'EOF' end

    local statement = self:register()

    while not self:match(EOF) do
        if self:match('NL') then 
            self:advance()
            self.line = self.line + 1
        else
            statement:switch(self:current(),self)
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