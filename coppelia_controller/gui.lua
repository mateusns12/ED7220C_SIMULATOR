-- GUI

-- GUI Namespace. UI Callbacks have argument signature as (ui,id,...)
CB = {}

local sim = require('sim')
local simUI = require('simUI')
require(sim.getObject('/interpreter'))

-- Global Objects initialization
robot = Robot:new()
tokenizer = Tokenizer:new()
parser = Parser:new()
emitter = Emitter:new()
interpreter = Interpreter:new()
Runtime.cleanup()

-- @brief Controller main Thread
main_coro = coroutine.create(function()
    sim.addLog(sim.verbosity_msgs, "Main Thread Spawned")
    
    CB.code = ""
    parser:register()
    emitter:register()
    robot:register()

    interpreter.robot = robot
    interpreter.emitter = emitter
    
    -- Spawning ED7220C Threads
    Runtime.resume(robot_coro)
    Runtime.resume(emit_coro)
    CB.control()
    coroutine.yield()
    while true do
        if Runtime.enabled then
            local t1 = sim.getSystemTime()
            interpreter:run(CB.ops)
            Runtime.enabled = false
            local t2 = sim.getSystemTime()
            print("Time elapse: ",t2-t1)
        end
        coroutine.yield()
        --collectgarbage("collect")
    end
end)

-- @brief Robot IO/Actuator main Thread
grip_coro = coroutine.create(function()
    sim.addLog(sim.verbosity_msgs, "IO/Actuator Thread Spawned")
    sim.wait(0.2,false)
    while true do
        robot:gripper()
        CB.OutputSignal()
        CB.InputSignal()
        --CB.tabMenu = simUI.getCurrentTab(CB.ui,300)
        --CB.tabTeste = simUI.getCurrentTab(CB.ui,306)
        coroutine.yield()
    end
end)

-- @brief Robot main Thread 
robot_coro = coroutine.create(function()
    sim.addLog(sim.verbosity_msgs, "Robot Thread Spawned")
    sim.wait(0.2,false)
    while true do
        robot:exec(); coroutine.yield()
    end
end)

-- @brief Emitter main Thread 
emit_coro = coroutine.create(function()
    sim.addLog(sim.verbosity_msgs, "Emitter Thread Spawned")
    sim.wait(0.2,false)
    while true do
        emitter:exec(); coroutine.yield()
    end
end)

-- @brief Updates Output ports in GUI 
function CB.OutputSignal()
    local output = Runtime.output
    for i=0,7 do
        local v = ((output&(2^i)) >> i) 
        simUI.setCheckboxValue(CB.ui,410+i,v*2)
    end
end

-- @brief Updates Input ports in GUI
function CB.InputSignal()
    local input = 0
    for i=2,9 do
        local v = simUI.getCheckboxValue(CB.ui,400+i)
        if v == 2 then v = 1 else v = 0 end
        input = input | v << (i-2)
    end
    Runtime.input = input
end

-- @brief Opens File Dialog to load a file path, and sets the content in GUI
function CB.GetFileContent(ui,id)
    local file_path = simUI.fileDialog(simUI.filedialog_type.load,"Open File",CB.scenePath,"*.txt","","txt",true)
    if file_path[1] then
        local file = io.open(file_path[1],"r")
        local content = file:read("all")
        file:close()
        simUI.setText(ui,101,content,true)
        CB.code = content
    end
end

-- @brief Opens File Dialog to save GUI Console output as a .txt file
function CB.SaveFileContent(ui,id)
    local file_path = simUI.fileDialog(simUI.filedialog_type.save,"Save File",CB.scenePath,"*.txt","","txt",true)
    if file_path[1] then
        local file = io.open(file_path[1],"w")
        file:write("garbanzo")
        file:close()
    end
end

-- @brief Executes the user code in GUI.
function CB.Execute(ui,id)
    if Runtime.paused then 
        Runtime.paused = false
    else
        simUI.setText(ui,102,"")
        parser:cleanup()
        parser.tokens = tokenizer:tokenize(CB.code)
        CB.ops = parser:parse()
        if CB.ops == nil then
            --simUI.msgBox(simUI.msgbox_type.critical,simUI.msgbox_buttons.ok,"Falha","Erro de Sintaxe. Vejo o Log de erros no console.")
            return
        end
        simUI.appendText(ui,102,parser:dump()..'\n\n')
        Runtime.enabled = true
    end
end

-- @brief Pauses Interpreter execution. It does not stop running motion operations,
--        but justs does not advance to the next instruction.
function CB.Pause(ui,id)
    --sim.addLog(420,"Paused")
    Runtime.paused = true
end

-- @brief Restarts the Interpreter. Restarts the scene for virtual robot, and sends
--        command HOME to the real robot (position 0,0,0,0,0).
function CB.Restart(ui,id)
    Runtime.cleanup()
    robot:restart()
end

-- @brief Stops Interpreter execution. Stops all running motion operations for virtual
--        robot, and stops all motors for real robot (intruction 'ma'). This command
--        may trigger a System Error Status, setting SS bit 6 high. 
function CB.Stop(ui,id)

end

-- @brief Cancels waitings on input ports.
function CB.CancelPending(ui,id)
    Runtime.cancelPending = true
end

-- @brief Updates the code to be executed when chamges ocurr on GUI.
function CB.GetCode(ui,id,code)
    CB.code = code
end

-- @brief Enables Sending/Receiving messages for the serial port. 
--        CLS instruction (Clear Console) wont work if this checkbox is marked.
function CB.EnableSerialDebug(ui,id)
    local state = simUI.getCheckboxValue(ui,id)
    if state == 2 then
        simUI.msgBox(simUI.msgbox_type.info,simUI.msgbox_buttons.ok,"Info","O comando CLS sera desabilitado!")
    end
end

function CB.EnableFastMode(ui,id)
    local state = simUI.getCheckboxValue(ui,id)
    if state == 2 then
        Runtime.fastMode = true
        simUI.msgBox(simUI.msgbox_type.warning,simUI.msgbox_buttons.ok,"Info","Os comandos nao respondem em fast mode! Nao e possivel fechar, reiniciar, pausar ou parar a execucao")
    else
        Runtime.fastMode = false
    end
end

-- @brief Creates/Updates the Robot Status Tree
function CB.CreateStatusTree(ui,id)
    for s=1,#CB.status do
        simUI.addTreeItem(ui,id,s,CB.status[s][1],0)
        for i=2,#CB.status[s] do
            simUI.addTreeItem(ui,id,i+s-1,CB.status[s][i],s)
        end
    end
end

-- @brief Clear the status tree, and gets status words from the real robot via serial.
--        This function does not work if a simulation is running.
function CB.UpdateStatusTree(ui,id)
    if Runtime.enabled then 
        simUI.msgBox(simUI.msgbox_type.warning,simUI.msgbox_buttons.ok,"Atencao","Nao e possivel atualizar status com uma rotina em andamento!")
        return
    end
    simUI.clearTree(CB.ui,501)
    --robot:status(CB.status)
    CB.CreateStatusTree(CB.ui,501)
end

-- @brief Append text to the Console (text-browser widget)
function CB.AppendConsole(msg)
    simUI.appendText(CB.ui,102,msg)
end

-- @brief Opens Input Dialog, for INPUT instruction
function CB.Input(msg)
    return simUI.inputDialog("",msg,"Input")
end

-- @brief Handles cleanup tasks and stops simulation at GUI closing. 
--        This function triggers sysCall_cleanup()
function CB.Cleanup()
    --serial:close()
    sim.stopSimulation()
end

-- @brief: Control Window UI build
function CB.control()
    --  ID
    --  Text-Browser:100
    --  Button:200
    --  Tabs:300
    --  Checkbox:400
    --  Tree:500
    --  ComboBox:700
    --  Label:800
    --  Group:900
    
    local xml = [[
    <ui title="ED7220C Controller" closeable="true" on-close="CB.Cleanup" resizable="true" size="800,600" activate="true">
        <group id="901" layout="hbox" flat="true" content-margins="0,0,0,0">
        <tabs id="300">
            <tab id="301" layout="vbox" title="Comandos"> 
                <group id="905" layout="hbox" flat="true" content-margins="0,0,0,0">
                    <button id="201" text="Executar"  on-click="CB.Execute" icon="default://SP_MediaPlay"/>
                    <button id="202" text="Pausar"    on-click="CB.Pause"   icon="default://SP_MediaPause"/>
                    <button id="203" text="Reiniciar" on-click="CB.Restart" icon="default://SP_BrowserReload"/>
                    <button id="204" text="Parar"     on-click="CB.Stop"    icon="default://SP_MediaStop"/>
                </group>
                <group id="906" layout="hbox" flat="true" content-margins="0,0,0,0">
                    <label id="801" text="Programa:"/>
                    <checkbox id="420" text="Habilitar Fast Mode" on-change="CB.EnableFastMode"/>
                    <button id="205" text="Carregar do arquivo"
                        icon="default://SP_DialogOpenButton"
                        on-click="CB.GetFileContent"/>
                </group>
                <text-browser id="101" type="plain" read-only="false" word-wrap="false" on-change="CB.GetCode"/>
                <group id="907" layout="hbox" flat="true" content-margins="0,0,0,0">
                    <label id="802" text="Console:"/>
                    <checkbox id="401" text="Habilitar Debug Serial" on-change="CB.EnableSerialDebug"/>
                    <button id="206" text="Salvar no arquivo" 
                        icon="default://SP_DialogSaveButton"
                        on-click="CB.SaveFileContent"/>
                </group>
                <text-browser id="102" type="plain" read-only="true" word-wrap="false"/>
            </tab>
            <tab id="302" layout="hbox" title="Configuracao">
                <group id="909" layout="vbox" flat="true" content-margins="0,0,0,0">
                    <label text="Comunicacao Serial"/>
                    <button id="220" text="Procurar portas COM" icon="default://SP_BrowserReload"/>
                    <group id="910" layout="grid" flat="true" content-margins="0,0,0,0">
                        <label text="Selecionar Porta:"/>
                        <combobox id="701">
                            <item>Selecionar</item>
                        </combobox>
                        <br/>
                        <label text="Baudrate"/>
                        <combobox id="702">
                            <item>9600</item>
                            <item>115200</item>
                        </combobox>
                        <br/>
                        <label text="Paridade"/>
                        <combobox id="703">
                            <item>1</item>
                            <item>0</item>
                        </combobox>
                        <br/>
                        <label text="Stopbits"/>
                        <combobox id="704">
                            <item>2</item>
                            <item>1</item>
                        </combobox>
                        <br/>
                        <label text="Bytesize"/>
                        <combobox id="705">
                            <item>7</item>
                            <item>8</item>
                        </combobox>
                    </group>
                   <button text="Aplicar" icon="default://SP_DialogApplyButton"/>
                </group id="911">
                <group layout="vbox">
                
                </group>                
            </tab>
            <tab id="304" title="Teste">
                <tabs id="306">
                    <tab id="307" title="Robo Simulacao">
                        <group>
                        </group>
                    </tab>
                    <tab id="308" title="Robo Real">
                    </tab>
                </tabs>
            </tab>
            <tab id="305" title="Status">
                <group id="912" layout="hbox" flat="true" content-margins="0,0,0,0">
                    <label text="Palavras de Status"/>
                    <button id="207" text="Recarregar" icon="default://SP_BrowserReload" on-click="CB.UpdateStatusTree"/>
                </group>
                <label text="Valores de 0 a 255, onde cada bit representa uma propriedade." 
                        word-wrap="true"/>
                <tree id="501" autosize-header="true" >
                    <header>
                        <item>Status</item>
                        <item>Valor</item>
                    </header>
                </tree>
            </tab>
        </tabs>
        <group id="913" layout="vbox" flat="true" content-margins="0,0,0,0">
            <group id="914" layout="vbox" flat="true" content-margins="0,0,0,0">
                <label id="803" text="OFFLINE"/>
                <button text="Conectar" icon="default://SP_CommandLink"/>
            </group>
            <label id="804" text="Entradas"/>
            <group id="915" layout="grid" content-margins="10,10,10,10">
                <checkbox id="402" text="Input 1"/>
                <checkbox id="403" text="Input 2"/>
                <br/>
                <checkbox id="404" text="Input 3"/>
                <checkbox id="405" text="Input 4"/>
                <br/>
                <checkbox id="406" text="Input 5"/>
                <checkbox id="407" text="Input 6"/>
                <br/>
                <checkbox id="408" text="Input 7"/>
                <checkbox id="409" text="Input 8"/>
            </group>
            <button id="210" text="Remover esperas" on-click="CB.CancelPending"/>
            <label id="805" text="Saidas" />
            <group id="916" layout="grid" content-margins="10,10,10,10">
                <checkbox id="410" text="Output 1"/>
                <checkbox id="411" text="Output 2"/>
                <br/>
                <checkbox id="412" text="Output 3"/>
                <checkbox id="413" text="Output 4"/>
                <br/>
                <checkbox id="414" text="Output 5"/>
                <checkbox id="415" text="Output 6"/>
                <br/>
                <checkbox id="416" text="Output 7"/>
                <checkbox id="417" text="Output 8"/>
            </group>
        </group>
        </group>
    </ui>
    ]]
    
    ------------------ STYLESHEETS ------------------
    
    CB.ui = simUI.create(xml)
    
    CB.font = 'Iosevka'
    CB.font_sz_std = "14px" 
    CB.font_sz_title = "16px"
    CB.font_sz_menu = "18px"
    
    local IO_Style = [[
        QGroupBox, QGroupBox * {
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_std..[[}
        QCheckBox{color: #565656}
        QCheckBox::indicator{height:20px;width:20px;}
        QCheckBox::indicator::checked{background-color:#00c600}
    ]]
    simUI.setStyleSheet(CB.ui,915,IO_Style)
    simUI.setStyleSheet(CB.ui,916,IO_Style)
    
    local MD_Style = [[
        QGroupBox{background-color:#FFFFFF}
        QLabel{
            font-family:']]..CB.font..[[';
            font-weight:bold;
            font-size:24px;
            qproperty-alignment: AlignCenter
        }
        QPushButton{
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_title..[[;
            width: 150px;
            min-height: 30px;
            max-height: 60px;
        }
    ]]
    local LB_Style = [[
        QLabel{
            font-family:']]..CB.font..[[';
            font-weight:bold;
            font-size:]]..CB.font_sz_title..[[
        }
        QLabel{qproperty-alignment: AlignCenter}
    ]]
    simUI.setStyleSheet(CB.ui,914,MD_Style)
    simUI.setStyleSheet(CB.ui,804,LB_Style)
    simUI.setStyleSheet(CB.ui,805,LB_Style)
    
    local TB_Style = [[
        QTabBar{
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_menu..[[;
            font-weight:bold
        }
    ]]
    simUI.setStyleSheet(CB.ui,300,TB_Style)
    
    local TX_Style = [[
        QTextBrowser{
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_title..[[;
            color:#303030;
            background-color:#F9F9F9
        }
    ]]
    simUI.setStyleSheet(CB.ui,101,TX_Style)
    simUI.setStyleSheet(CB.ui,102,TX_Style)
    
    local CB_Style = [[
        QPushButton {
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_std..[[;
            min-height: 25px;
            max-height: 50px;
        }
    ]]
    simUI.setStyleSheet(CB.ui,201,CB_Style)
    simUI.setStyleSheet(CB.ui,202,CB_Style)
    simUI.setStyleSheet(CB.ui,203,CB_Style)
    simUI.setStyleSheet(CB.ui,204,CB_Style)
    simUI.setStyleSheet(CB.ui,205,CB_Style)
    simUI.setStyleSheet(CB.ui,206,CB_Style)
    
    local PD_Style = [[
        QPushButton {
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_std..[[;
            max-height: 40px;
        }
    ]]
    simUI.setStyleSheet(CB.ui,210,PD_Style)
    
    local TT_Style = [[
        QLabel{
            font-family:']]..CB.font..[[';
            font-weight:bold;
            font-size:]]..CB.font_sz_title..[[
        }
    ]]
    simUI.setStyleSheet(CB.ui,801,TT_Style)
    simUI.setStyleSheet(CB.ui,802,TT_Style)
    
    local BX_Style = [[
        QComboBox{
        font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_std..[[
        }
        QPushButton{
            font-family:']]..CB.font..[[';
            font-size:]]..CB.font_sz_std..[[;
            min-height:22px
        }
    ]]
    
    simUI.setStyleSheet(CB.ui,909,TT_Style..BX_Style)
    
    CB.scenePath = (sim.getProperty(sim.handle_scene,"scenePath")):match("(.*[/\\\\])")
    
    ------------------ STATUS TREE ------------------
    
    CB.status = {
        {{'[SS] - System Status','0'},
            {'[7] - Motor Ligado','0'},
            {'[6] - Erro de Sistema','0'},
            {'[5] - Timer Delay ativo','0'},
            {'[4] - Sinal entrada pendente','0'},
            {'[3] - Controle Manual desconectado','0'},
            {'[2] - Tecla ENTER Pressionada','0'},
            {'[1] - Tecla ESCAPE Pressionada','0'},
            {'[0] - Erro no Controle Manual','0'}},
        {{'[SC] - System Configuration','0'},
            {'[7] - Mode\t\t(1-Host, 0-Controller)','0'},
            {'[6] - Pendant\t\t(1-Enabled, 0-Disabled)','0'},
            {'[5] - Controller\t(1-Generic, 0-Robot)','0'},
            {'[4] - Robot Mode\t(1-SCARA, 0-XR3)','0'},
            {'[3] - Gripper\t\t(1-Enabled, 0-Disabled)','0'},
            {'[2] - Coordinate\t(1-XYZ, 0-Joint)','0'}},
        {{'[SA] - System Motor State','0'},--0-Parado,1-Movimento
            {'[A] - Motor','0'},
            {'[B] - Motor','0'},
            {'[C] - Motor','0'},
            {'[D] - Motor','0'},
            {'[E] - Motor','0'},
            {'[F] - Motor','0'}},
        {{'[SM] - System Motor Mode','0'},--Idle,Trapezoidal,Velocity,Open-Loop
            {'[A] - Motor','0'},
            {'[B] - Motor','0'},
            {'[C] - Motor','0'},
            {'[D] - Motor','0'},
            {'[E] - Motor','0'},
            {'[F] - Motor','0'}},
        {{'[IP] - Input Port Status','0'},
            {'[7] - Input','0'},
            {'[6] - Input','0'},
            {'[5] - Input','0'},
            {'[4] - Input','0'},
            {'[3] - Input','0'},
            {'[2] - Input','0'},
            {'[1] - Input','0'},
            {'[0] - Input','0'}},
        {{'[IX] - Input Switch Status','0'},
            {'[7] - Input','0'},
            {'[6] - Input','0'},
            {'[5] - Input','0'},
            {'[4] - Input','0'},
            {'[3] - Input','0'},
            {'[2] - Input','0'},
            {'[1] - Input','0'},
            {'[0] - Input','0'}},
        {{'[OR] - Output Port Status','0'},
            {'[7] - Output','0'},
            {'[6] - Output','0'},
            {'[5] - Output','0'},
            {'[4] - Output','0'},
            {'[3] - Output','0'},
            {'[2] - Output','0'},
            {'[1] - Output','0'},
            {'[0] - Output','0'}},
        {{'[SE] - Host Error Stack','0'}}
    }
    CB.CreateStatusTree(CB.ui,501)
    simUI.show(CB.ui)
end
