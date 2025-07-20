#pragma comment(lib, "OneCore.lib")

#include "simLibserial.h"
#include <map> 
#include "SerialPort.h"
#include <format>
#define PLUGIN_VERSION 8 // 2 since version 3.2.1, 3 since V3.3.1, 4 since V3.4.0, 5 since V3.4.1, 6 since V4.6

static LIBRARY simLib; // the CoppelisSim library that we will dynamically load and bind

using DataVec = std::vector<CScriptFunctionDataItem>*;
using Data = CScriptFunctionData;
using Item = CScriptFunctionDataItem;

std::map<std::string, SerialPort> ports;

#define PLUGIN_NAME "SerialPort"

const int args_newport [] = {
	1,
	sim_script_arg_string,0
};

void lua_newport_callback(SScriptCallBack * p){
	Data D;
	D.readDataFromStack(p->stackID,args_newport,args_newport[0],nullptr);
	DataVec inData = D.getInDataPtr();

	std::string & com_name = inData->at(0).stringData[0];
	
	DWORD res = GetFileAttributes(com_name.c_str());
	simAddLog(PLUGIN_NAME,sim_verbosity_loadinfos,std::format("Port {}",com_name).c_str());

	bool ret = (res != INVALID_FILE_ATTRIBUTES) ? true : false;
	
	if (ret) {
		ports.emplace(com_name,com_name);
	}
	D.pushOutData(CScriptFunctionDataItem(ret));
	D.writeDataToStack(p->stackID);	
}

const int args_connect [] = {
	1,
	sim_script_arg_string,0
};

void lua_connect_callback(SScriptCallBack * p){
	Data D;
	D.readDataFromStack(p->stackID,args_connect,args_connect[0],nullptr);
	DataVec inData = D.getInDataPtr();
	
	std::string & com_name = inData->at(0).stringData[0];
	auto it = ports.find(com_name);	
	SerialPort & port = it->second;

	simAddLog(PLUGIN_NAME,sim_verbosity_loadinfos,std::format("Connecting: {}",it->first).c_str());

	auto [res,error] = port.ConnectPort();
	std::string result;
	if(!res){
		simAddLog(PLUGIN_NAME,sim_verbosity_errors,std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser aberta: {}",error,ErrorMessage(error)).c_str());
	}
	simAddLog(PLUGIN_NAME,sim_verbosity_loadinfos,std::format("Result: {}",res ? "Connected":"Failed").c_str());
	D.pushOutData(CScriptFunctionDataItem(res));
	D.writeDataToStack(p->stackID);	
}

const int args_readport [] = {
	1,
	sim_script_arg_string,0
};

void lua_readport_callback(SScriptCallBack * p){
	Data D;
	D.readDataFromStack(p->stackID,args_readport,args_readport[0],nullptr);
	DataVec inData = D.getInDataPtr();
	
	std::string & com_name = inData->at(0).stringData[0];

	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	

	std::string received;
	auto [res,error] = port.ReadPortSync(received);

	if(!res){
		simAddLog(PLUGIN_NAME,sim_verbosity_errors,std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser lida: {}",error,ErrorMessage(error)).c_str());
	}else{
		simAddLog(PLUGIN_NAME,sim_verbosity_loadinfos,std::format("Received[{}]: {}",received.length(),received).c_str());
	}

	D.pushOutData(CScriptFunctionDataItem(res));
	D.pushOutData(CScriptFunctionDataItem(received));
	D.writeDataToStack(p->stackID);	
}

const int args_writeport [] = {
	2,
	sim_script_arg_string,0,
	sim_script_arg_string,0
};

void lua_writeport_callback(SScriptCallBack * p){
	Data D;
	D.readDataFromStack(p->stackID,args_writeport,args_writeport[0],nullptr);
	DataVec inData = D.getInDataPtr();
	
	std::string & com_name = inData->at(0).stringData[0];
	std::string & msg = inData->at(1).stringData[0];
	
	simAddLog(PLUGIN_NAME,sim_verbosity_loadinfos,std::format("Sending[{}]: {}",msg.length(),msg).c_str());

	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	
	
	auto [res,error] = port.WritePort(msg);
	if(!res){
		simAddLog(PLUGIN_NAME,sim_verbosity_errors,std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser escrita: {}",error,ErrorMessage(error)).c_str());
	}
	D.pushOutData(CScriptFunctionDataItem(res));
	D.writeDataToStack(p->stackID);	
}

const int args_closeport [] = {
	1,
	sim_script_arg_string,0
};

void lua_closeport_callback(SScriptCallBack * p){
	Data D;
	D.readDataFromStack(p->stackID,args_closeport,args_closeport[0],nullptr);
	DataVec inData = D.getInDataPtr();
	
	std::string & com_name = inData->at(0).stringData[0];

	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	
	
	port.ClosePort();
}

const int args_configure [] = {
	5,
	sim_script_arg_string,0,
	sim_script_arg_int32,0,
	sim_script_arg_int32,0,
	sim_script_arg_int32,0,
	sim_script_arg_int32,0
};

//port:configure(BAUD,PARITY,BYTESIZE,STOPBITS)

void lua_configureport_callback(SScriptCallBack * p){
	Data D;
	D.readDataFromStack(p->stackID,args_configure,args_configure[0],nullptr);
	DataVec inData = D.getInDataPtr();

	std::string & com_name = inData->at(0).stringData[0];
	int baud = inData->at(1).int32Data[0];
	int parity = inData->at(2).int32Data[0];
	int bytesize = inData->at(3).int32Data[0];
	int stopbits = inData->at(4).int32Data[0];

	auto it = ports.find(com_name);	
	SerialPort & port = it->second;	
	
	auto [res,error] = port.Config(baud,parity,bytesize,stopbits);
	
	if(!res){
		simAddLog(PLUGIN_NAME,sim_verbosity_errors,std::format("\x1b[1;31m[ERRO {}]\x1b[0m Porta nao pode ser configurada: {}",error,ErrorMessage(error)).c_str());
	}
	D.pushOutData(CScriptFunctionDataItem(res));
	D.writeDataToStack(p->stackID);
}

void lua_listport_callback(SScriptCallBack * p){
	Data D;
	ULONG coms[20];
	ULONG found = 0;
	ULONG res = GetCommPorts(coms,20,&found);
	std::vector<int> port;
	port.reserve(20);
	switch(res){
		case ERROR_SUCCESS:
			D.pushOutData(CScriptFunctionDataItem(true));
			for(int i=0;i<found;i++){
				port[i] = coms[i];
			}
			D.pushOutData(CScriptFunctionDataItem(port));
			break;
		case ERROR_MORE_DATA:
		case ERROR_FILE_NOT_FOUND:
		default:
			D.pushOutData(CScriptFunctionDataItem(false));
			D.pushOutData(CScriptFunctionDataItem());
	}
	D.writeDataToStack(p->stackID);
}

// This is the plugin start routine (called just once, just after the plugin was loaded):
SIM_DLLEXPORT int simInit(SSimInit* info)
{
    // Dynamically load and bind CoppelisSim functions:
    simLib=loadSimLibrary(info->coppeliaSimLibPath);
    simAddLog(PLUGIN_NAME,sim_verbosity_errors,"\x1b[1;32mSerialPort Plugin by Mateus Gomes.\x1b[0m");
    if (simLib==NULL)
    {
        simAddLog(PLUGIN_NAME,sim_verbosity_errors,"could not find or correctly load the CoppeliaSim library. Cannot start the plugin.");
        return(0); // Means error, CoppelisSim will unload this plugin
    }
    if (getSimProcAddresses(simLib)==0)
    {
        simAddLog(PLUGIN_NAME,sim_verbosity_errors,"could not find all required functions in the CoppeliaSim library. Cannot start the plugin.");
        unloadSimLibrary(simLib);
        return(0); // Means error, CoppelisSim will unload this plugin
    }

    // Check the version of CoppelisSim:
    int simVer,simRev;
    simGetInt32Param(sim_intparam_program_version,&simVer);
    simGetInt32Param(sim_intparam_program_revision,&simRev);
    if( (simVer<40000) || ((simVer==40000)&&(simRev<1)) )
    {
        simAddLog(info->pluginName,sim_verbosity_errors,"sorry, your CoppelisSim copy is somewhat old, CoppelisSim 4.0.0 rev1 or higher is required. Cannot start the plugin.");
        unloadSimLibrary(simLib);
        return(0); // Means error, CoppelisSim will unload this plugin
    }

    // Register the new function:
    simRegisterScriptCallbackFunction("NewSerial",nullptr,lua_newport_callback);
    simRegisterScriptCallbackFunction("Connect",nullptr,lua_connect_callback);
    simRegisterScriptCallbackFunction("Read",nullptr,lua_readport_callback);
    simRegisterScriptCallbackFunction("Write",nullptr,lua_writeport_callback);
    simRegisterScriptCallbackFunction("Close",nullptr,lua_closeport_callback);
    simRegisterScriptCallbackFunction("Config",nullptr,lua_configureport_callback);
    simRegisterScriptCallbackFunction("List",nullptr,lua_listport_callback);

    return(PLUGIN_VERSION); // initialization went fine, we return the version number of this plugin (can be queried with simGetModuleName)
}

// This is the plugin end routine (called just once, when CoppelisSim is ending, i.e. releasing this plugin):
SIM_DLLEXPORT void simCleanup()
{
    // Here you could handle various clean-up tasks

    unloadSimLibrary(simLib); // release the library
}

// This is the plugin messaging routine (i.e. CoppelisSim calls this function very often, with various messages):
SIM_DLLEXPORT void simMsg(SSimMsg* info)
{ // This is called quite often. Just watch out for messages/events you want to handle
    // Here we can intercept many messages from CoppelisSim. Only the most important messages are listed here.
    // For a complete list of messages that you can intercept/react with, search for "sim_message_eventcallback"-type constants
    // in the CoppelisSim user manual.

    if (info->msgId==sim_message_eventcallback_instancepass)
    {   // This message is sent each time the scene was rendered (well, shortly after) (very often)

    }

    if (info->msgId==sim_message_eventcallback_simulationabouttostart)
    { // Simulation is about to start

    }

    if (info->msgId==sim_message_eventcallback_simulationended)
    { // Simulation just ended

    }

    if (info->msgId==sim_message_eventcallback_instanceswitch)
    { // We switched to a different scene. Such a switch can only happen while simulation is not running

    }

    // You can add many more messages to handle here
}

