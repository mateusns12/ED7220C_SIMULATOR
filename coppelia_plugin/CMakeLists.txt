cmake_minimum_required(VERSION 3.16)
project(simLibserial)

set(CMAKE_CXX_STANDARD 20)

message("Current Source Dir = " ${CMAKE_CURRENT_SOURCE_DIR})
add_compile_definitions(WIN_SIM=1)

set(SOURCE 
	sourceCode/SerialPort.cpp
	sourceCode/SerialPort.h
	sourceCode/simLibserial.cpp
	sourceCode/simLibserial.h
	sourceCode/include/simLib.cpp
	sourceCode/include/scriptFunctionData.cpp
	sourceCode/include/scriptFunctionDataItem.cpp
)

add_library(simLibserial SHARED ${SOURCE})
target_include_directories(simLibserial PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/sourceCode/include")
