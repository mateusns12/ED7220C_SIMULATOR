#ifndef SERIALPORT_H
#define SERIALPORT_H

#include <windows.h>
#include <locale.h>
#include <string>
#include <tuple>
#include <cstring>
#include <format>

#define DLL extern "C" __declspec(dllexport)

__declspec(dllexport) std::string ErrorMessage(DWORD error);

class SerialPort {

	private:
		std::string 	_port;
		HANDLE 		_handle;
		DCB 		_dcb;
		COMMTIMEOUTS 	_cto;
		COMSTAT 	_coms;
		DWORD		_BaudRate = 9600;
		DWORD		_Parity = 1;
		DWORD		_ByteSize = 7;
		DWORD		_StopBits = 2;
	public:
	
	SerialPort(std::string name);

	~SerialPort();

	HANDLE & GetHandle();
	COMSTAT & GetCom();

	void ClosePort();

	std::tuple<bool,unsigned long> SetConfig();
	
	std::tuple<bool,unsigned long> Config(int baud,int parity,int bytes, int stopbits);
	
	//void ConfigTimeouts();
	
	//void ConfigEvents();
	
	//--------------------  SYNC SERIAL  -------------------------

	std::tuple<bool,unsigned long> ConnectPort();

	std::tuple<bool,unsigned long> WritePort(const std::string & msg);

	std::tuple<bool,unsigned long> ReadPortSync(std::string & received);
	
	//--------------------  ASYNC SERIAL  ------------------------
	
	//bool ConnectAsync(std::string port);
	//bool WriteAsync(std::string msg);
	//bool ReadAsync();
};
#endif
