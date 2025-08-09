-- TOKENIZER

Tokenizer = {}

KEYW = {
------------BUILTIN-------------
['ACOS']={'ACOS'},
['ASIN']={'ASIN'},
['ATAN']={'ATAN'},
['COS']={'COS'},
['SIN']={'SIN'},
['TAN']={'TAN'},
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

------------ UTILS -------------
push = function(t,item) t[#t+1] = item end  
pop = function(t,item) local it = t[#t]; t[#t] = nil; return it end
contains = function(t,v) for i=1,#t do if t[i] == v then return true end end return false end

-- @brief Tokenizer object Constructor
function Tokenizer:new()
    Tokenizer.__index = Tokenizer
    return setmetatable({text = "",tokens = nil},Tokenizer)
end

-- @brief Tokenizer main function
-- @param (string text) Text to be tokenized
-- @return (table tokens) table of key:value pairs of tokens
function Tokenizer:tokenize(text)
    self.tokens = {}
    self.text = text .. "\n"
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
            word = word .. chars[idx]:upper() ;advance() 
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
            --push(self.tokens,{'UNK',chars[idx]});advance()
            advance()
        end
    end
    push(self.tokens,{'EOF'})
    return self.tokens
end