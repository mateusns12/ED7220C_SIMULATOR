#include "SerialPort.h"
//--------------------------------------------------------------------
/*
 * Formmated error message. If set 'Portuguese', must use setlocale()
 */

#define DLL extern "C" __declspec(dllexport)

__declspec(dllexport) std::string ErrorMessage(DWORD error){
	WCHAR buffer[256];
	DWORD res = FormatMessage(
		FORMAT_MESSAGE_FROM_SYSTEM     |
		FORMAT_MESSAGE_IGNORE_INSERTS  ,
		NULL,
		error,
		MAKELANGID(LANG_ENGLISH,SUBLANG_ENGLISH_US),
		(LPSTR) buffer,
		sizeof(buffer),NULL
	);
	buffer[strlen((LPSTR)buffer)-2] = '\0';
	if (res == 0){
		return std::format("[ERROR {}] Failed to get message for error {}.",GetLastError(),error);
	}
	return std::string((LPSTR)buffer);
}

//std::array<int,10> ListPorts(){
//	return std::array<int,10>		
//}

//--------------------------------------------------------------------
/*
 * Close the SerialPort HANDLE object
 **/
SerialPort::~SerialPort(){
	if(_handle) CloseHandle(_handle);
}
//--------------------------------------------------------------------
/*
 * Initialize SerialPort com name
 */
SerialPort::SerialPort(std::string port){
	_port = port;
}
//--------------------------------------------------------------------
/*
 * Close the SerialPort HANDLE object
 */
void SerialPort::ClosePort(){
	CloseHandle(_handle);
	_handle = nullptr;
}

COMSTAT & SerialPort::GetCom(){
	return _coms;
}

HANDLE & SerialPort::GetHandle(){
	return _handle;
}

std::tuple<bool,unsigned long> 
SerialPort::SetConfig(){
	GetCommState(_handle,&(_dcb));
	_dcb.BaudRate = _BaudRate;
	_dcb.Parity   = _Parity;
	_dcb.ByteSize = _ByteSize;
	_dcb.StopBits = _StopBits;
	BOOL res = SetCommState(_handle,&(_dcb));
	DWORD error = GetLastError();
	return { res == TRUE ? true:false ,(unsigned long)error};
}

std::tuple<bool,unsigned long> 
SerialPort::Config(int baud, int parity, int data, int stopbits){
	_BaudRate = 	(unsigned long) baud;
	_Parity   = 	(unsigned long) parity;
	_ByteSize = 	(unsigned long) data;
	_StopBits = 	(unsigned long) stopbits;
	return SetConfig();
}

//--------------------------------------------------------------------
/*
 * Open Serial Port. Return true on sucess.
 */
std::tuple<bool,unsigned long> 
SerialPort::ConnectPort(){
	_handle = CreateFileA(_port.c_str(),GENERIC_READ|GENERIC_WRITE,0,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);
	if(_handle == INVALID_HANDLE_VALUE){
		DWORD error = GetLastError();
		return {false,(unsigned long)error};
	}
	int res = SetCommMask(_handle,EV_RXCHAR);
	
	SetConfig();

	_cto.ReadIntervalTimeout = MAXDWORD; 
	_cto.ReadTotalTimeoutMultiplier = 0;
	_cto.ReadTotalTimeoutConstant = 0;
	_cto.WriteTotalTimeoutMultiplier = 0;
	_cto.WriteTotalTimeoutConstant = 0;

	SetCommTimeouts(_handle,&_cto);
	return {true,(unsigned long)0};
}

//--------------------------------------------------------------------
/*
 * Write a buffer to serial port, returns true on sucess.
 */
std::tuple<bool,unsigned long> 
SerialPort::WritePort(const std::string & msg){
	unsigned long bytes;
	int res = WriteFile(_handle,msg.c_str(),msg.length(),&bytes,NULL);
	if(res == 0){
		DWORD error = GetLastError();
		return {false,(unsigned long)error};
	}
	return std::tuple(true,(unsigned long)0);
}

//--------------------------------------------------------------------
/*
 * Reads Serial port byte by byte, while the number of bytes pending 
 * in cbInQue is not zero.
std::tuple<bool,unsigned long> 
SerialPort::ReadPort(std::string & received){
	char buffer[32];
	unsigned long bytes;
	BOOL pending = TRUE;
	DWORD error;
	int idx = 0;
	char read = '\0';
	while(pending == TRUE){
		ReadFile(_handle,&read,1,&bytes,NULL);
		if(read == '\r'){
			buffer[idx] = '\0';
		}
		buffer[idx] = read;
		ClearCommError(_handle,&error,&_coms);
		if(_coms.cbInQue == 0) pending = FALSE;
		idx++;
	}
	received.assign(buffer,0,31);
	return true;
}
 */
//--------------------------------------------------------------------
/*
 * Reads all pending bytes in cbInQue at once.
 */
#define BUFFSIZE 1024

std::tuple<bool,unsigned long> 
SerialPort::ReadPortSync(std::string & received){
	char buffer[BUFFSIZE] = {0};
	unsigned long bytes;
	BOOL pending = TRUE;
	DWORD error;
	int idx = 0;
	char read = '\0';
	ClearCommError(_handle,&error,&_coms);
	BOOL res = ReadFile(_handle,buffer,_coms.cbInQue,&bytes,NULL);
	//Check error
	ClearCommError(_handle,&error,&_coms);
	if (_coms.cbInQue == 0){
		received.assign(buffer,0,bytes);
		return {true,error};
	}
	error = GetLastError();
	return {false,error};
}
