cmake_minimum_required(VERSION 3.16)
project(libserial)

set(CMAKE_CXX_STANDARD 20)

message("Current Source Dir = " ${CMAKE_CURRENT_SOURCE_DIR})

set(SOURCE 
	libserial.cpp
	SerialPort.h
	SerialPort.cpp
)

add_library(libserial SHARED ${SOURCE})
target_include_directories(libserial PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(libserial "${CMAKE_CURRENT_SOURCE_DIR}/include/lua54.lib")
