local codeEditorInfos = [[
bool result = SerialPort:new(string portname)
bool result = SerialPort:open()
bool result = SerialPort:write(string message)
bool result = SerialPort:config()
bool result, table ports = SerialPort:list()
bool result, string received = SerialPort:read()
SerialPort:close()
]]

registerCodeEditorInfos("simSerialPort", codeEditorInfos)
