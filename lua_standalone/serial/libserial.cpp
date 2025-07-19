#pragma comment(lib, "lua54.lib")
#pragma comment(lib, "OneCore.lib")

#define DLL extern "C" __declspec(dllexport)

#include "lua.hpp"
#include "SerialPort.h"
#include <map>
#include <iostream>
#include <chrono>
#include <thread>

std::map<std::string,SerialPort> ports;

void checkname(lua_State * L,const char * fname){
	if (lua_type(L,-1) != LUA_TSTRING) luaL_error(L,"bad argument #-1 to '%s' (string expected, got %s)",fname,luaL_typename(L,-1));
}

DLL int waitmillis(lua_State * L){
	if (lua_type(L,-1) != LUA_TNUMBER) luaL_error(L,"bad argument #-1 to '%s' (number expected, got %s)","Wait",luaL_typename(L,-1));
	std::chrono::milliseconds delay(luaL_checkinteger(L,-1));
	std::this_thread::sleep_for(delay);
	return 0;
}

DLL int newserial(lua_State * L){
	checkname(L,"NewSerial");
	std::string com_name(lua_tostring(L,-1));
	lua_pop(L,1);

	DWORD res = GetFileAttributes(com_name.c_str());
	std::cout << std::format("Creating Port {}\n",com_name);

	bool ret = (res != INVALID_FILE_ATTRIBUTES) ? true : false;
	
	if (ret) {
		ports.emplace(com_name,com_name);
	}
	lua_pushboolean(L,ret);
	return 1;
}

DLL int connectport(lua_State * L){
	checkname(L,"Connect");
	std::string com_name(lua_tostring(L,-1));
	lua_pop(L,1);

	auto it = ports.find(com_name);	
	SerialPort & port = it->second;

	std::cout << std::format("Connecting: {}\n",it->first);

	auto [res,error] = port.ConnectPort();
	std::string result;
	if(!res){
		std::cout << std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser aberta: {}",error,ErrorMessage(error));
	}
	std::cout << std::format("Result: {}\n",res ? "Connected":"Failed");
	lua_pushboolean(L,res);
	return 1;
}

DLL int writeport(lua_State * L){
	checkname(L,"Write");
	std::string com_name(lua_tostring(L,-2));
	std::string msg(lua_tostring(L,-1));
	lua_pop(L,2);
	
	std::cout << std::format("Sending[{}]: {}\n",msg.length(),msg);

	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	
	
	auto [res,error] = port.WritePort(msg);
	if(!res){
		std::cout << std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser escrita: {}",error,ErrorMessage(error));
	}
	lua_pushboolean(L,res);
	return 1;
}

DLL int readport(lua_State * L){
	checkname(L,"Read");
	std::string com_name(lua_tostring(L,-1));
	lua_pop(L,1);
	
	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	

	std::string received;
	auto [res,error] = port.ReadPortSync(received);
	
	if(!res){
		std::cout << std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser lida: {}",error,ErrorMessage(error));
	}else{
		std::cout << std::format("Received[{}]: {}\n",received.length(),received);
	}
	lua_pushboolean(L,res);
	lua_pushstring(L,received.c_str());
	return 2;

}

DLL int closeport(lua_State * L){

	checkname(L,"Close");
	std::string com_name(lua_tostring(L,-1));
	lua_pop(L,1);
	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	
	
	port.ClosePort();
	return 0;
}

DLL int configureport(lua_State * L){
	int argsc = lua_gettop(L);
	if (argsc != 5){
		std::cout << std::format("\x1b[1;31m[ERRO]\x1b[0m Porta nao pode ser configurada: Numero de argumentos incorreto: {}\n",argsc);
		lua_pushboolean(L,false);
		return 1;
	}
	checkname(L,"Config");
	std::string com_name(lua_tostring(L,-5));
	int baud 	= luaL_checkinteger(L,-4);
	int parity 	= luaL_checkinteger(L,-3);
	int bytesize 	= luaL_checkinteger(L,-2);
	int stopbits 	= luaL_checkinteger(L,-1);
	lua_pop(L,5);
	
	auto it = ports.find(com_name);	
	SerialPort & port = it->second;

	auto [res,error] = port.Config(baud,parity,bytesize,stopbits);
	
	if(!res){
		std::cout << std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser configurada: {}",error,ErrorMessage(error));
	}
	lua_pushboolean(L,res);
	return 1;
}

DLL int listport(lua_State * L){
	ULONG coms[20];
	ULONG found = 0;
	ULONG res = GetCommPorts(coms,20,&found);
	switch(res){
		case ERROR_SUCCESS:
			lua_pushboolean(L,true);
			lua_createtable(L,0,(int)found);
			for(int i=1;i==found;i++){
				lua_pushinteger(L,coms[i-1]);
				lua_seti(L,-2,i);
			}
			break;
		case ERROR_MORE_DATA:
		case ERROR_FILE_NOT_FOUND:
		default:
			lua_pushboolean(L,false);
			lua_pushnil(L);
	}
	return 2;
}

static const struct luaL_Reg functions [] = {
	{"NewSerial",newserial},
	{"Write",writeport},
	{"Read",readport},
	{"Connect",connectport},
	{"Close",closeport},
	{"List",listport},
	{"Config",configureport},
	{"Wait",waitmillis},
	{NULL,NULL}
};

DLL int luaopen_libserial(lua_State * L){
	luaL_newlib(L,functions);
	return 1;
}
