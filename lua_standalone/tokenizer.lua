Tokenizer = {}

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
['HARDHOME']={'HARDHOME'},
['SEND']={'SEND'},
['OFFLINE']={'OFFLINE'},
['ONLINE']={'ONLINE'},
['IFSIG']={'IFSIG'},
['WAITFOR']={'WAITFOR'},
['OUTSIG']={'OUTSIG'}}

push = function(table,item) table[#table+1] = item end  
pop = function(table,item) local it = table[#table]; table[#table] = nil; return it end
contains = function(t,v) for i=1,#t do if t[i] == v then return true end end return false end

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
        while chars[idx]:match("%w") or chars[idx]=='.' or chars[idx]=='@' do 
            word = word .. chars[idx];advance() 
        end
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
        elseif chars[idx] == '^' then
            push(self.tokens,{'POW','^'});advance()
        elseif chars[idx] == '\"' then
            advance()
            push(self.tokens,getString());advance()
        elseif chars[idx]:match("%w") or chars[idx] == '@' then
            push(self.tokens,getWord());
        else
            advance()
        end
    end
    push(self.tokens,{'EOF'})
    --for i=1,#self.tokens do print(table.unpack(self.tokens[i])) end
    return self.tokens
end