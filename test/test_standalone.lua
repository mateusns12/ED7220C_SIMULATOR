SerialPort = require("serialport")

local port = SerialPort:new("COM1");

--ret,tab = port:list()

--print(table.unpack(tab))

port:open()
port:write("vs,D,50\r")
port:wait(100)
ret,msg = port:read()
print(msg,tonumber(msg)==128)
port:write("ss\r")
port:wait(100)
ret,msg = port:read()
print(msg,tonumber(msg)==128)
port:close()

