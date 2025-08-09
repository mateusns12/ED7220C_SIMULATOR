-- EMITTER

local sim = require('sim')
local SerialPort = require "simSerialPort"
require(sim.getObject("/runtime"))

local f = string.format

Emitter = {}

-- @brief Emitter object Constructor
function Emitter:new()
    Emitter.__index = Emitter
    return setmetatable({port = nil,arg = nil, operation = nil, motors = {'B','C','D','E','F'}},Emitter)
end

-- @brief Receives and open a serial port
-- @param (SerialPort port) SerialPort object
function Emitter:setport(port)
    self.port = port
    self.port:open()
end

-- @brief Closes the serial port
function Emitter:closeport()
    self.port:close()
end

-- @brief Writes to the serial port
function Emitter:write(cmd)
    self.port:write(cmd)
end

-- @brief Reads from the serial port
function Emitter:read()
    return self.port:read()
end

-- @brief Waits for a time delay in milliseconds
-- @param (int delay) Delay in millisecons
--        sim.wait() wraps sim.step(), wich wraps coroutine.yield(), so it is
--        safe to use inside of a coroutine. (Non Blocking)
function Emitter:wait(delay)
    sim.wait(delay/1000,false)
end

-- @brief Register functions to be used in Emitter Switch Case
function Emitter:register()
    local function set_position(point)
        for i=1,#self.motors do
            self:write(f("pd,%s,%d\r",self.motors[i],point[i]))
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
        local point = args[2]
        for i=1,#self.motors do
            self:write(f("pr,%s,%d\r",self.motors[i],point[i]))
            self:wait(50)
        end
        self:write("mc\r")
        self:wait(100)
        while (motor_busy()==1) do
        end
        local final_pos = get_position()
    end
    local function movep(args)
        local point = args[2]
        set_position(point)
        self:write("mc\r")
        self:wait(100)
        while (motor_busy()==1) do
        end
        local final_pos = get_position()
    end
    local function moveto()
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
        set_position({0,0,0,0,0})
        self:write("mc\r")   -- Start
        self:wait(100)
        while(motor_busy()==1)do
        end
        local pos = get_position()
    end
    local function hardhome(args)
        self:write("hh\r")
        while(motor_busy()==1)do
        end
        -- Loop check_system_status until Finish
        local pos = get_position()
    end
    local function vel(args)
        self:write(f("vs,%s,%d\r",args[2],args[3]))
        self:wait(100)
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
        self:write(f("%s\r",args[2][2]))
        self:wait(100)
        local ret,msg = self:read()
        cmd[3] = msg
    end
    
    local function input_pending()
        self:write("ss\r")
        self:wait(100)
        local ret,msg = self:read()
        local status = tonumber(msg)
        local pending = (status&16) >>4
        return pending
    end
    local function args2dec(dec,args)
        for i=1,#args do
            local sig = args[i]
            if sig > 0 then
                dec = dec | 1 << math.abs(sig-1)
            else
                dec = dec & ~(1 << math.abs(sig)-1)
            end
        end
        return dec
    end
    local function waitfor(args)
        local sig = args[4]
        for i=1,#sig do
            if sig[i] > 0 then
                self:write(f("wi,%s,%d\r",sig[i],1))
            else
                self:write(f("wi,%s,%d\r",math.abs(sig[i]),0))
            end
        end
        while(input_pending()==1)do end
    end
    
    local function outsig(args)
        self:write("ip\r")
        self:wait(100)
        local ret,msg = self:read()
        local out = args2dec(tonumber(msg),args[4])
        self:write(f("op,%s\r",out))
    end
    local function ifsig(args)
        self:write("ip\r")
        self:wait(100)
        local ret,msg = self:read()
        local state = tonumber(msg)
        args[3] = state == args2dec(state,args[4])
    end

    self.operation = Switch:new():build()
        :case("MOVE",move)
        :case('MOVEP',movep)
        :case('MOVETO',moveto)
        :case('OPEN',open)
        :case('CLOSE',close)
        :case('VEL',vel)
        :case('HARDHOME',hardhome)
        :case('HOME',home)
        :case('WAITFOR',waitfor)
        :case('IFSIG',ifsig)
        :case('OUTSIG',outsig)
        :case('SEND',send)
        :default(function(args) 
            Runtime.assert(false,'Emitter:',"Operation '"..args[1].."' not implemented") 
        end)
end

-- @brief Execution is asynchronous, running parallel to Robot. 
--        Sets argument as nil after conclusion
function Emitter:exec()
    if self.arg then
        self.operation:switch(self.arg[1],self.arg)
    end
    self.arg = nil
end
