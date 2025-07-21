![System]
![Language 2]

# Coppelia Plugin SimLibserial

> Files for the simLibserial plugin, written in C++20.

This plugin is a wrapper to the serial SerialPort class, the same used for the Lua Standalone interpreter.

## Contents

- [lua/][lua] - Files for loading the plugin and Lua SerialPort wrapper in Coppelia. Should be placed into local CoppeliaSimXXX/lua.
- [sourceCode/][sourceCode] - Files for building simLibserial from source.
- [CMakeLists.txt][cmake] - Cmake configuration file.
- [setup.ps1][setup] - Powershell script for compiling 'simLibserial' library.

---
## Motivation 

Coppelia has its own serial communications api, but it doesn't work with ED7220C, since its COM configuration parameters are different. 

ED7220C works synchronously, with odd parity, 2 stopbits and byte size of 7, while Coppelia serial api works asynchronously (overlapped), with even parity, 1 stopbit and byte size of 8.

We can send commands, but there is no response. So I've implemented this plugin to use in my Thesis.

---

## Building simLibserial from source

The official way of buiding Coppelia plugins is using QT Creator, and the project should be inside 'CoppeliaSimXXX/programming'. It did not work for me so, i've made my own CMakeLists and changed some file headers. 

This library is built with MSVC, using the **Developer Powershell for VS 2022** enviroment. It should work with MinGW GNU Compiler, using MSYS2 enviroment, but then the path for [**OneCore.lib**][OneCore] needs to be provided in CMakeLists.

Clone the repository, then go to 'coppelia_plugin' folder, wich has the 'setup.ps1' script. 

Change **$BuildTool** and **$Generator** variables if not using MSVC and nmake. Run the script.

````bash
./serial.ps1
````
If using another Build Tool or compiler, or MSYS2 enviroment, that is not Powershell, inside 'coppelia_plugin', paste the following code in the shell or bash file:

````bash
mkdir build
cp build
cmake .. -G "<Your Generator>" # Run cmake -G to see generators
make # or any other Build Tool, Ex: ninja
cd ..
````
The **'simLibserial.dll'** file inside 'build' should be placed into your current CoppeliaSim instalation folder.

---

## Lua Wrapper simSerialPort.lua

As in the Lua Standalone library, simLibserial is not called directly into the script. simSerialPort wraps these
functions as an Object SerialPort. It makes management of multiple ports easier. There are no sigletons on C++ side,
so multiple objects can be created.

````lua
local SerialPort = require("simSerialPort")

local port = SerialPort:new("COM1")
res = port:open()
res = port:config(115200,0,8,1) -- yes, config is called after opening the port.
res = port:write("text")
sim.wait(0.1,false) -- value in seconds, not using simulation time
res,msg = port:read()
port:close()
````

It does not implement a port:wait() method, since Coppelia has its own sim.wait() function.

---

````lua
 SerialPort:new(portname) -> SerialPort
````
This method takes a string with a COM port, and returns a SerialPort object.

````lua
SerialPort:open() -> bool
````
This method opens the port, returning false if failed. The error is shown in Coppelia Log Terminal.

````lua
SerialPort:close()
````
This method closes the port. There is no return value
````
SerialPort:write(msg) -> bool 
````
This method writes a string to the serial port. If the port isnt opened, it will show on Lua side. If the write operation failed, it returns false, and the error will be shown in Coppelia Log Terminal.

````lua
SerialPort:read() -> bool,string
````
This method reads form the serial port. If the port isnt opened, it will show on Lua side. If the write operation failed, it returns false and an empty string, and the error will be shown in Coppelia Log Terminal.

````lua
SerialPort:Config(baud,parity,bytesize,stopbits) -> bool
````

This method configures the communication parameters of the port. Default parameters are 9600,1,7,2. If it fails, it returns false, and the error is shown on Coppelia Log Terminal.

````lua
SerialPort.list() -> bool,table
````

This method returns true and a table with all available COM ports. If failed, it returns false and a nil value if no ports are available.

---

## Resource Cleanup

If the user does not close the port, on C++ side, if Coppelia terminates normally, all mapped ports will be closed by its destructor.






[System]: <https://img.shields.io/badge/System-windows-A100FF?style=for-the-badge&logo=windows>

[Language 1]: <https://img.shields.io/badge/Language-lua 5.4-2C2D72?style=for-the-badge&logo=lua>

[Language 2]: <https://img.shields.io/badge/Language-C++20-00599C?style=for-the-badge&logo=cplusplus>

[OneCore]:https://github.com/mateusns12/ED7220C_SIMULATOR/blob/master/libraries/OneCore.Lib

[libraries]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/libraries

[lua]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_plugin/lua

[cmake]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_plugin/CMakeLists.txt

[setup]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_plugin/setup.ps1

[sourceCode]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_plugin/sourceCode