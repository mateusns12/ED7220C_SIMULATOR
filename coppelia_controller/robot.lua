--  ROBOT

local sim = require('sim')
require(sim.getObject("/switch"))
require(sim.getObject("/runtime"))

local f = string.format

Robot = {}

-- @brief Robot object Constructor
function Robot:new()
    Robot.__index = Robot
    
    local Attributes = {
        -- Map of joint actuators
        joints = {
            ['B'] = sim.getObject("/Revolute5"),
            ['C'] = sim.getObject("/Revolute4"),
            ['D'] = sim.getObject("/Revolute3"),
            ['E'] = sim.getObject("/Revolute2"),
            ['F'] = sim.getObject("/Revolute1"),
        },
        -- Map of angular/encoder limits for min/max range of motion 
        limits = {
            ['B'] = {{-180,180},{-1500,1500}},
            ['C'] = {{-40,165},{-900,3000}},       
            ['D'] = {{-5,45},{-200,2000}},     
            ['E'] = {{-60,10},{-2100,450}},    
            ['F'] = {{-135,135},{-6500,6500}},        
        },
        -- Initial offsets of the robot, to set starting position as 0,0,0,0,0
        offsets = {
            ['B'] = math.deg(sim.getJointPosition(sim.getObject("/Revolute5"))),
            ['C'] = math.deg(sim.getJointPosition(sim.getObject("/Revolute4"))),
            ['D'] = math.deg(sim.getJointPosition(sim.getObject("/Revolute3"))),
            ['E'] = math.deg(sim.getJointPosition(sim.getObject("/Revolute2"))),
            ['F'] = math.deg(sim.getJointPosition(sim.getObject("/Revolute1"))),
        },
        velocities = nil,
        gripperName = "BaxterGripper",
        parent = sim.getObject("/BaxterGripper"),
        gripperMotor = sim.getObject('/BaxterGripper_closeJoint'),
        sensor = sim.getObject("/BaxterGripper_attachProxSensor"),
        operation = nil,
        motors = {'B','C','D','E','F'},
        arg = nil,
        grabbed = nil,
        objects = {}
    }
    local openedGap=0.0562
    local closedGap=-0.03
    local interval={0,openedGap-closedGap}
    
    sim.setJointInterval(Attributes.gripperMotor,false,interval)
    return setmetatable(Attributes,Robot)
end

-- @brief register an detectable and graspable object. Whenever gripper closes, it will get the object
-- @param (string objectName) Pathname of the object in the project tree. Ex: "/Rob_Manipsphere"
function Robot:detectableObject(objectName)
    local handle = sim.getObject(objectName)
    local parent = sim.getObjectParent(handle)
    local position = sim.getObjectPosition(handle)
    self.objects[handle] = {handle,parent,position}
end

-- @brief Resets registered objects in scene back to start positions
function Robot:resetObjects()
    for k, v in pairs(self.objects) do
        sim.setObjectParent(v[1],v[2])
        sim.setObjectPosition(v[1],v[3])
    end
end

-- @brief Sets joint velocity
function Robot:setVelocity(joint,velocity)
    sim.setFloatArrayProperty(self.joints[joint],"maxVelAccelJerk",{math.rad(velocity),1,1})
end

-- @brief Sets absolute angular position
function Robot:setAbsolutePosition(joint,position)
    sim.setJointTargetPosition(self.joints[joint],math.rad(position+self.offsets[joint]))
end

-- @brief Sets Relative angular position (incremental)
function Robot:setRelativePosition(joint,position)
    local angle = sim.getJointPosition(self.joints[joint])
    sim.setJointTargetPosition(self.joints[joint],angle + math.rad(position))
end

-- @brief Opens robot gripper. Default delay = 1s
function Robot:open()
    Runtime.gripSignal = 0
    sim.wait(1,false)
    --sim.setInt32Signal(self.gripperName,0)
end

-- @brief Closes robot gripper. Default delay = 1s
function Robot:close()
    Runtime.gripSignal = 1
    sim.wait(1,false)
    --sim.setInt32Signal(self.gripperName,1)
end

-- @brief Grabs a detected object in scene, if is was registered as detectable.
--        Its is a fake grip, as we dont deal with dynamic properties.
function Robot:grab(handle)
    self.grabbed = self.objects[handle]
    if self.grabbed then
        sim.setObjectParent(handle,self.parent,true)
    end
end

-- @brief Releases a grabbed object, setting world as parent.
function Robot:release()
    if self.grabbed then
        sim.setObjectParent(self.grabbed[1],-1,true)
    end
    self.grabbed = nil
end

-- @brief Gripper main function. Reads gripper signal, opens, close and grab an object.
function Robot:gripper()
    --local close = sim.getInt32Signal(self.gripperName)
    local close = Runtime.gripSignal
    if (close==1) then
        sim.setJointTargetVelocity(self.gripperMotor,0.04)
    else
        sim.setJointTargetVelocity(self.gripperMotor,-0.04)
    end
    detected,dist,point,handle,_ = sim.checkProximitySensor(self.sensor,sim.handle_all)
    if detected == 1 and close == 1 then
        self:grab(handle)
    elseif close == 0 then
        self:release()
    end
end

-- @brief Register functions to be used in Robot Switch Case
function Robot:register()
    local function move(args)
        for i=1,#args[4] do
            self:setRelativePosition(self.motors[i],args[2][i])
        end
    end
    local function movep(args)
        for i=1,#args[4] do
            self:setAbsolutePosition(self.motors[i],args[4][i])
        end
    end
    function open(args)
        self:open()
    end
    local function close(args)
        self:close()
    end
    local function vel(args)
        self:setVelocity(args[4],args[3])
    end
    local function home(args)
        for i=1,#self.motors do
            self:setAbsolutePosition(self.motors[i],0)
        end
    end
    local function args2dec(dec,args)
        for i=1,#args do
            local sig = args[i]
            if sig > 0 then
                dec = dec | 1 << math.abs(sig-1)
            else
                dec = dec & ~(1 << math.abs(sig)-1)
            end
        end
        return dec
    end
    local function waitfor(args)
        Runtime.cancelPending = false
        local input = args2dec(Runtime.input,args[4])
        while Runtime.input ~= input do
            if Runtime.cancelPending then break end
            coroutine.yield()
        end
    end
    local function ifsig(args)
        args[3] = Runtime.input == args2dec(Runtime.input,args[4])
    end
    local function outsig(args)
        Runtime.output = args2dec(Runtime.output,args[4])
    end
    local function send(args)
    end
    self.operation = Switch:new():build()
        :case("MOVE",move)
        :case('MOVEP',movep)
        :case('MOVETO',movep)
        :case('OPEN',open)
        :case('CLOSE',close)
        :case('VEL',vel)
        :case('HARDHOME',home)
        :case('HOME',home)
        :case('WAITFOR',waitfor)
        :case('IFSIG',ifsig)
        :case('OUTSIG',outsig)
        :case('SEND',send)
        :default(function(args) 
            Runtime.assert(false,'Robot:',"Operation '"..args[1].."' not implemented")
        end)
end

--@brief Execution is asynchronous, running parallel to Emitter.
--        Sets argument as nil after conclusion
function Robot:exec()
    if self.arg then
        self.operation:switch(self.arg[1],self.arg)
    end
    self.arg = nil
end
