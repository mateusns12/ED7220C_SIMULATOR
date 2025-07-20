local codeEditorInfos = [[
bool result = simLibserial.NewSerial(string portname)
bool result, string outputString = simLibserial.Read(string portname)
bool result = simLibserial.Write(string portname)
bool result, table ports = simLibserial.List(string portname)
bool result = simLibserial.Connect(string portname)
bool result = simLibserial.Config(string portname)
void = simLibserial.Close()
]]

registerCodeEditorInfos("simLibserial", codeEditorInfos)
