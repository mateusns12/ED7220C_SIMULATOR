local serial = require('libserial')

local SerialPort = {}

local f = string.format

--	@param (string portname) Nome da porta COM. Ex: COM1
--	@return (table) Objeto do tipo SerialPort
function SerialPort:new(portname)
	SerialPort.__index = SerialPort
	return setmetatable({port = portname,opened = false},SerialPort)
end

--	@return (boolean) Falso caso a porta seja inválida ou houve erro na abertura
function SerialPort:open()
	local res = serial.NewSerial(self.port)
	if res then
		self.opened = serial.Connect(self.port)
	else
		print(f("\x1b[1;31m[ERRO]\x1b[0m Cannot create: '%s' is not a valid port",msg))
	end
	return self.opened
end

--	@param (string msg) Mensagem a ser enviada pela porta
--	@return (boolean) Falso caso houve erro na escrita ou se a porta nao está aberta
function SerialPort:write(msg)
	if self.opened then
		return serial.Write(self.port,msg)
	else
		print("\x1b[1;31m[ERRO]\x1b[0m Cannot write: Port isnt Opened")
		return false
	end
end

--	@return (boolean) Falso caso houve erro na leitura ou se a porta nao está aberta
--	@return (string) contendo a mensagem lida
function SerialPort:read()
	if self.opened then
		return serial.Read(self.port)
	else
		print("\x1b[1;31m[ERRO]\x1b[0m Cannot read: Port isnt Opened")
		return false,{}
	end
end

--	@param (int baud)     Baudrate 
--	@param (int parity)   Paridade (0 ou 1) 
--	@param (int bytesize) Tamanho do byte (7 ou 8) 
--	@param (int stopbits) Stopbits (1 ou 2)
--	@return (boolean) Falso se houve falha na configuração ou se a porta não está aberta,
function SerialPort:config(baud,parity,bytesize,stopbits)
	if self.opened then
		return serial.Config(self.port,baud,parity,bytesize,stopbits)
	else
		return false
	end
end

--	Versão Procedural
--	@return (boolean) False se não há portas abertas ou se a varredura falhou
--	@return (table) tabela contendo as portas obtidas
function SerialPort.list()
	return serial.List() 
end

--	Versão Orientada a Objeto
--	@return (boolean) False se não há portas abertas ou se a varredura falhou
--	@return (table) tabela contendo as portas obtidas
function SerialPort:list()
	return serial.List() 
end

--	Fecha a porta
function SerialPort:close()
	serial.Close(self.port)
	self.opened = false
end

return SerialPort
