![System]
![Language 1]

# ED7220C Controller for Coppelia Simulator

> Files for ED7220C Robot Controler and Simulator, written in Lua for Coppelia Simulator, version 4.9.0.

This Controller is a Graphical User Interface (GUI) application, running inside a Coppelia Simulator Scene.

It is capable of controling both the virtual ED7220C model, and a real robot connected through serial port.

---
## Contents

These Lua scripts are already inside of '**Controller.ttt**' being part of the scene as threaded simulation scripts, and does not run in standalone Lua. They are listed here for quick reference of whats implemented inside of the scene.

They should **not** be confused with external Lua files for Coppelia, neither placed inside '**lua/**' folder. 

- [Controller.ttt][scene] - Actual Coppelia Scene.
- [main.lua][main] - Main entry script. Initializes the GUI.
- [robot.lua][robot] - Simulation Robot object implementation.
- [gui.lua][gui] - Graphical User Interface implementation, and namespace for UI callbacks and runtime objects.
- [interpreter.lua][interpreter] - Main entry file, runs the virtual machine of the interpreter.
- [tokenizer.lua][tokenizer] - Tokenizer for the RoboTalk language.
- [parser.lua][parser] - Parser for the RoboTalk language.
- [switch.lua][switch] - Switch like implementation using tables.

---
## Running the Controller

Download the scene **'Controller.ttt'**, the plugin **'simLibSerial.dll'**, and files from **'coppelia_plugin/lua/'**. the plugin should be placed inside main CoppeliaSim instalation folder. Lua files should be placed inside lua/ folder in CoppeliaSim instalation folder.  

Open the scene and start the simulation. The GUI should open.

---
## GUI



[System]: <https://img.shields.io/badge/System-windows-A100FF?style=for-the-badge&logo=windows>

[Language 1]: <https://img.shields.io/badge/Language-lua 5.4-2C2D72?style=for-the-badge&logo=lua>

[scene]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/Controller.ttt

[robot]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/robot.lua

[gui]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/gui.lua

[main]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/main.lua

[tokenizer]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/tokenizer.lua

[parser]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/parser.lua

[interpreter]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/interpreter.lua

[switch]:https://github.com/mateusns12/ED7220C_SIMULATOR/tree/master/coppelia_controller/switch.lua