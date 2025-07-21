![System]
![Language 1]
![Language 2]

# Lua Standalone Controler

> Files for the ED7220C Robot Controler, written in Lua, version 5.4. SerialPort library 'libserial' written in C++20.

This controler is a CLI application, wich interprets RoboTalk code, and outputs ASCII commands to the serial port, to wich an ED7220C must be connected.

---

## Contents
- [serial/][serial] - Files for building 'libserial' library.
- [interpreter.lua][interpreter] - Main entry file, runs the virtual machine of the interpreter.
- [tokenizer.lua][tokenizer] - Tokenizer for the RoboTalk language.
- [parser.lua][parser] - Parser for the RoboTalk language.
- [switch.lua][switch] - Switch like implementation using tables.
- [serialport.lua][serialport] - Lua OOP wraper for the 'libserial' library
- [setup.ps1][setup] - Powershell script for compiling 'libserial' library.
It uses MSVC and nmake, but can be changed to another build tool.

---
## Running the Controler

Clone the repository. Copy the file **'libserial.dll'** from [libraries][libraries] folder into this 'lua_standalone' folder, or build it from source. 

The COM port is hardcoded into intepreter.lua until we implement a CLI menu, so change it before running. Run the script, with a RoboTalk code txt file as argument:

````bash
lua interpreter.lua <path to file>.txt
````
The 'test' folder has sample files to be used as arguments. All subprograms in 'snippets.txt' can run locally.

---

## Building libserial from source

This library is built with MSVC, using the **Developer Powershell for VS 2022** enviroment. It should work with MinGW GNU Compiler, using MSYS2 enviroment, but then the path for [**OneCore.lib**][OneCore] needs to be provided in CMakeLists.

Clone the repository, then go to 'lua_standalone' folder, wich has the 'setup.ps1' script. 

Change **$BuildTool** and **$Generator** variables if not using MSVC and nmake. Run the script.

````bash
./serial.ps1
````
If using another Build Tool or compiler, or MSYS2 enviroment, that is not Powershell, inside 'lua_standalone', paste the following code in the shell or bash file:

````bash
mkdir serial/build
cp serial/build
cmake .. -G "<Your Generator>" # Run cmake -G to see generators
make # or any other Build Tool, Ex: ninja
cd ../..
cp serial/build/libserial.dll libserial.dll
````
---

## Lua Wrapper simSerialPort.lua

'libserial' should not be called directly into the script. 'simSerialPort' wraps these functions as an Object SerialPort. It makes management of multiple ports easier. There are no sigletons on C++ side, so multiple objects can be created. Usage example:

````lua
local SerialPort = require("simSerialPort")

local port = SerialPort:new("COM1")
res = port:open()
res = port:config(115200,0,8,1) -- yes, config is called after opening the port.
res = port:write("text")
port:wait(100) -- value in milliseconds
res,msg = port:read()
port:close()
````
---
## Resource Cleanup

If the user does not close the port, on C++ side, if Lua terminates normally, all mapped ports will be closed by its destructor.

---

## Infos

### About Lua

Its built with Lua 5.4 and does not work with Lua 5.3 and under. If needed to work in another version, change the include files for that version of Lua, and change luaopen_libserial() function in libserial.cpp if needed (5.1 and under).

### About timming

SerialPort:wait() is implemented using std::chrono and std::thread, so its a blocking operation. Lua os.wait() is not accurate enough, neither Sleep() from WinAPI. Coppelia version of this library does not have this function, since the controler runs in a threaded enviroment, it uses sim.wait(), wich supends the thread instead of blocking.

This is why waiting functions are wrapped by the Emitter object method wait(). So the timming and accuracy may be different between the two controllers.

### About SerialPort class

It is a wrapper for WinAPI Communication Resources. It requires OneCore.lib to use GetCommPorts() function. 

It does not follow conventional implementation for Write/Read operations, that returns the ammount of bytes transfered. Instead, it returns a tuple with a boolean result and an error code. If there was any errors, result is false. Then the error code can be retrieved and converted to a formatted string using ErrorMessage function.


[System]: <https://img.shields.io/badge/System-windows-A100FF?style=for-the-badge&logo=windows>

[Language 1]: <https://img.shields.io/badge/Language-lua 5.4-2C2D72?style=for-the-badge&logo=lua>

[Language 2]: <https://img.shields.io/badge/Language-C++20-00599C?style=for-the-badge&logo=cplusplus>

[OneCore]:https://github.com/mateusns12/ED7220C_SIMULATOR/blob/master/libraries/OneCore.Lib

[libraries]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/libraries

[serial]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/serial

[interpreter]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/interpreter.lua

[parser]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/parser.lua

[switch]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/switch.lua

[tokenizer]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/tokenizer.lua

[serialport]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/serialport.lua

[setup]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone/setup.ps1
