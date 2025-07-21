![System]
![Language 1]
![Language 2]

# ED7220C Controller and Simulator

> This Repository contains the code developed for the ED7220C Controller and Simulator, implemented for Coppelia Simulator and Standalone Lua.

> Used for my final Thesis in Mechatronics Engineering (TCC) at UFSJ

## In development

- [ ] RoboTalk commands.
- [ ] Async IO Operations.
- [ ] CLI menu.
- [ ] Coppelia GUI.
- [ ] GUI with GTK.

---

## Contents

Each folder has a README describing their contents and how to run the Controller, and how to build both library and plugin from source.

- [lua_standalone/][lua_standalone] - Folder for CLI Standalone Lua Ed7220C Controller, to run without Coppelia.
- [coppelia_plugin/][coppelia_plugin] - Folder for Coppelia Plugin simLibserial.
- [coppelia_controller/][coppelia_controller] - Folder for Coppelia ED7220C Controller and Simulator, as a script.
- [libraries/][libraries] - Folder for pre-compiled shared libraries and required build resources.
---

## RoboTalk Language

The ED7220C robot is a mechanic manipulator developed by ED Corporation in 2000. IT can be programmed via serial communication, using its Teach Pendant, or by a computer, using its proprietary software Arm Robot Trainer. 

The robot itself is an interpreter, running in the ED-MK4 integrated module, that receives ASCII commands via serial. When using the Teach Pendant, the language resembles assembly language, where there is a mnemonic for an instruction, followed by parameters separated by commas.

```asm
SL,2
OB,1,1
OB,1,0
GL,2
```
The RoboTalk Language used in the Arm Robot Trainer is a subset of BASIC language. Blocks, control structures, subroutines and intrinsic functions are identical. But it differs on variable declarations, input/output, etc. See as an example:

```basic
SETI B = 1
FOR A = B TO 5
    IF A = 5 THEN GOSUB 300 ELSE GOSUB 200
NEXT 
END
200 REM Body of Subroutine 200
TYPE "Subroutine 200"
OUTSIG 1
RETURN
300 REM Body of Subroutine 300
TYPE "Subroutine 300"
OUTSIG -1
RETURN
```

The Arm Robot Trainer interprets and converts this high level language into the ASCII commands mentioned above, and sends them through the serial port.

---

## The Controller

This Controller is an implementation of an RoboTalk interpreter and ASCII emitter, written in Lua, that allows the ED7220C to be simulated inside Coppelia, and to control a real ED7220C connected through the serial port.

It runs RoboTalk in a virtual machine, running the logic locally in the computer, and outputing commands to the 3D model in Coppelia or the real robot when requested. 

It is built using a modular structure, making use of Lua OOP capabilities. So each process, such as tokenization, parsing, interpreter and emission can be 
developed, debbuged and run independent.

Also, multiple instances of controllers can be created in the same scene or script, allowing multiple robots to be simulated or controlled through serial ports.

---

## Tokenizer

It has RoboTalk commands as keywords. The BASIC subset is fully implemented, but some robot specifics are missing.
Also, there is no support yet for Floating Point numbers and variables.

It takes a string containing RoboTalk code, wich comes from a txt file, such as in the Lua CLI controller, or from an text-browser widget, from Coppelia GUI. 

It generates a list containing Key:Value pairs as tokens. EOF token marks the end of file. As an example:
````lua
sentence = "SETI A = 45"

{ 'SETI' }
{ 'IDENT','A' }
{ 'ASSIGN','=' }
{ 'NUM',45 }
{ 'EOF' }
````
---
## Parser

It takes a token list as argument, and generates an Abstract Syntax Tree (AST) from it. It is a top down parser, with a recursive descent expression parser.

As in classic BASIC, there are just 26 integer variables, from A to Z. 

The list above would be parsed into the follwing AST:

````lua
{ SETI,A,{NUM,45} }
````
---

## Interpreter

Receives the AST nodes list from the parser. Runs the virtual machine and emits the ASCII code for robot specific commands. It uses 2 objects, the Evaluator and Emitter.

### Evaluator
The Evaluator reduces AST node expressions to a final value, being integers or strings, loading values from the global symbol table.

````lua
{ ADD,{IDENT,A},{NUM,3}} -> { NUM,48 }
````

### Emmiter

The Emitter receives AST nodes with robot specific commands, and outputs the required ASCII commands to complete the operation. It also controls the timming between read/write operations and controls robot moves by looking at its status words. 

As an example, for moving from point P to P1 and back to P, it move to a point and will wait until all motors stopped and check if the encoders are in the final position to issue the next move. 

Example, we need to move motor D to encoder position 1500.

````asm
pa,D

Response: 600 -> motor encoder is at position 600

pd,D,1500
ms,D
ss

Response: 128 -> motor is still running, wait()

ss

Response: 0 -> motors stopped

pa,D

Response: 1500 -> motor arrived at destination, continue
````
Status words are 8 bit values sent as ASCII in response to status commands, such as ss,sc,sa and se.

The Controller checks those values to indentify configurations, modes, errors etc.

---


[System]: <https://img.shields.io/badge/System-windows-A100FF?style=for-the-badge&logo=windows>

[Language 1]: <https://img.shields.io/badge/Language-lua 5.4-2C2D72?style=for-the-badge&logo=lua>

[Language 2]: <https://img.shields.io/badge/Language-C++20-00599C?style=for-the-badge&logo=cplusplus>

[libraries]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/libraries

[lua_standalone]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/lua_standalone

[coppelia_plugin]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_plugin

[coppelia_controller]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller