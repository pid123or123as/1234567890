local MovementEnhancements = {}

local Services = nil
local PlayerData = nil
local notify = nil
local LocalPlayerObj = nil
local core = nil

MovementEnhancements.Config = {
    Timer = {
        Enabled = false,
        Speed = 2.5,
        ToggleKey = nil
    },
    Disabler = {
        Enabled = false,
        ToggleKey = nil
    },
    Speed = {
        Enabled = false,
        AutoJump = false,
        Method = "CFrame",
        Speed = 16,
        JumpInterval = 0.3,
        PulseTPDist = 5,
        PulseTPDelay = 0.2,
        ToggleKey = nil,
        SmoothnessFactor = 0.2
    },
    Fly = {
        Enabled = false,
        Speed = 50,
        VerticalSpeed = 50,
        ToggleKey = nil,
        VerticalKeys = "E/Q"
    },
    NoStamina = {
        Enabled = false,
        Mode = "Block"
    }
}

local TimerStatus = {
    Running = false,
    Connection = nil,
    Speed = MovementEnhancements.Config.Timer.Speed,
    Key = MovementEnhancements.Config.Timer.ToggleKey,
    Enabled = MovementEnhancements.Config.Timer.Enabled
}

local DisablerStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Disabler.ToggleKey,
    Enabled = MovementEnhancements.Config.Disabler.Enabled
}

local SpeedStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Speed.ToggleKey,
    Enabled = MovementEnhancements.Config.Speed.Enabled,
    Method = MovementEnhancements.Config.Speed.Method,
    Speed = MovementEnhancements.Config.Speed.Speed,
    AutoJump = MovementEnhancements.Config.Speed.AutoJump,
    LastJumpTime = 0,
    JumpCooldown = 0.5,
    JumpInterval = MovementEnhancements.Config.Speed.JumpInterval,
    PulseTPDistance = MovementEnhancements.Config.Speed.PulseTPDist,
    PulseTPFrequency = MovementEnhancements.Config.Speed.PulseTPDelay,
    SmoothnessFactor = MovementEnhancements.Config.Speed.SmoothnessFactor,
    CurrentMoveDirection = Vector3.new(0, 0, 0),
    LastPulseTPTime = 0
}

local FlyStatus = {
    Running = false,
    Connection = nil,
    Key = MovementEnhancements.Config.Fly.ToggleKey,
    Enabled = MovementEnhancements.Config.Fly.Enabled,
    Speed = MovementEnhancements.Config.Fly.Speed,
    VerticalSpeed = MovementEnhancements.Config.Fly.VerticalSpeed,
    VerticalKeys = MovementEnhancements.Config.Fly.VerticalKeys,
    BodyVelocity = nil
}

local NoStaminaStatus = {
    Running = false,
    Connection = nil,
    Enabled = MovementEnhancements.Config.NoStamina.Enabled,
    Mode = MovementEnhancements.Config.NoStamina.Mode,
    OriginalFireServer = nil
}

local function getCharacterData()
    local character = LocalPlayerObj and LocalPlayerObj.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    return humanoid, rootPart
end

local function isCharacterValid(humanoid, rootPart)
    return humanoid and rootPart and humanoid.Health > 0
end

local function isInVehicle(rootPart)
    local currentPart = rootPart
    while currentPart do
        if currentPart:IsA("Seat") or currentPart:IsA("VehicleSeat") then
            return true
        end
        currentPart = currentPart.Parent
    end
    return false
end

local function isInputFocused()
    return Services and Services.UserInputService and Services.UserInputService:GetFocusedTextBox() ~= nil
end

local function getCustomMoveDirection()
    if not Services.UserInputService or not Services.Workspace.CurrentCamera then
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
        return Vector3.new(0, 0, 0)
    end

    local camera = Services.Workspace.CurrentCamera
    local cameraCFrame = camera.CFrame
    local flatCameraForward = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z)
    local flatCameraRight = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z)
    if flatCameraForward.Magnitude == 0 or flatCameraRight.Magnitude == 0 then
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
        return Vector3.new(0, 0, 0)
    end
    flatCameraForward = flatCameraForward.Unit
    flatCameraRight = flatCameraRight.Unit

    local w = Services.UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0
    local s = Services.UserInputService:IsKeyDown(Enum.KeyCode.S) and -1 or 0
    local a = Services.UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0
    local d = Services.UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0

    local inputVector = Vector3.new(a + d, 0, w + s)
    local targetDirection = Vector3.new(0, 0, 0)
    if inputVector.Magnitude > 0 then
        inputVector = inputVector.Unit
        targetDirection = (flatCameraForward * inputVector.Z + flatCameraRight * inputVector.X)
        if targetDirection.Magnitude > 0 then
            targetDirection = targetDirection.Unit
        end
        local alpha = SpeedStatus.SmoothnessFactor
        SpeedStatus.CurrentMoveDirection = SpeedStatus.CurrentMoveDirection * (1 - alpha) + targetDirection * alpha
        if SpeedStatus.CurrentMoveDirection.Magnitude > 0 then
            SpeedStatus.CurrentMoveDirection = SpeedStatus.CurrentMoveDirection.Unit
        end
    else
        SpeedStatus.CurrentMoveDirection = Vector3.new(0, 0, 0)
    end
    return SpeedStatus.CurrentMoveDirection
end

local Timer = {}
Timer.Start = function()
    if TimerStatus.Running or not Services then return end
    local success = pcall(function()
        setfflag("SimEnableStepPhysics", "True")
        setfflag("SimEnableStepPhysicsSelective", "True")
    end)
    if not success then
        warn("Timer: Failed to enable physics flags")
        notify("Timer", "Failed to enable physics simulation.", true)
        return
    end
    TimerStatus.Running = true
    TimerStatus.Connection = Services.RunService.RenderStepped:Connect(function(dt)
        if not TimerStatus.Enabled or TimerStatus.Speed <= 1 then return end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local success, err = pcall(function()
            Services.RunService:Pause()
            Services.Workspace:StepPhysics(dt * (TimerStatus.Speed - 1), {rootPart})
            Services.RunService:Run()
        end)
        if not success then
            warn("Timer physics step failed: " .. tostring(err))
            Timer.Stop()
            notify("Timer", "Physics step failed. Timer stopped.", true)
        end
    end)
    notify("Timer", "Started with speed: " .. TimerStatus.Speed, true)
end

Timer.Stop = function()
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    TimerStatus.Running = false
    notify("Timer", "Stopped", true)
end

Timer.SetSpeed = function(newSpeed)
    TimerStatus.Speed = math.clamp(newSpeed, 1, 15)
    MovementEnhancements.Config.Timer.Speed = TimerStatus.Speed
    notify("Timer", "Speed set to: " .. TimerStatus.Speed, false)
end

local Disabler = {}
Disabler.DisableSignals = function(character)
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("CFrame"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
    for _, connection in ipairs(getconnections(rootPart:GetPropertyChangedSignal("Velocity"))) do
        pcall(function() hookfunction(connection.Function, function() end) end)
    end
end

Disabler.Start = function()
    if DisablerStatus.Running or not LocalPlayerObj then return end
    DisablerStatus.Running = true
    DisablerStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(Disabler.DisableSignals)
    if LocalPlayerObj.Character then
        Disabler.DisableSignals(LocalPlayerObj.Character)
    end
    notify("Disabler", "Started", true)
end

Disabler.Stop = function()
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    DisablerStatus.Running = false
    notify("Disabler", "Stopped", true)
end

local Speed = {}
Speed.UpdateMovement = function(humanoid, rootPart, moveDirection, currentTime, dt)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.Method == "CFrame" then
        if moveDirection.Magnitude > 0 then
            local newCFrame = rootPart.CFrame + (moveDirection * SpeedStatus.Speed * dt)
            rootPart.CFrame = CFrame.new(newCFrame.Position, newCFrame.Position + moveDirection)
        end
    elseif SpeedStatus.Method == "PulseTP" then
        if moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastPulseTPTime >= SpeedStatus.PulseTPFrequency then
            local scaledDistance = SpeedStatus.PulseTPDistance * (SpeedStatus.Speed / 16) -- Масштабируем дистанцию на основе Speed
            local teleportVector = moveDirection.Unit * scaledDistance
            local destination = rootPart.Position + teleportVector
            local raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = {LocalPlayerObj.Character}
            raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local raycastResult = Services.Workspace:Raycast(rootPart.Position, teleportVector, raycastParams)
            if not raycastResult then
                rootPart.CFrame = CFrame.new(destination, destination + moveDirection)
                SpeedStatus.LastPulseTPTime = currentTime
            end
        end
    end
end

Speed.UpdateJumps = function(humanoid, rootPart, currentTime, moveDirection)
    if not isCharacterValid(humanoid, rootPart) then return end
    if SpeedStatus.AutoJump and moveDirection.Magnitude > 0 and currentTime - SpeedStatus.LastJumpTime >= SpeedStatus.JumpInterval then
        local state = humanoid:GetState()
        if state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            SpeedStatus.LastJumpTime = currentTime
        end
    end
end

Speed.Start = function()
    if SpeedStatus.Running or not Services then return end
    SpeedStatus.Running = true
    SpeedStatus.Connection = Services.RunService.Heartbeat:Connect(function(dt)
        if not SpeedStatus.Enabled then
            SpeedStatus.Running = false
            return
        end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then return end
        local currentTime = tick()
        local moveDirection = getCustomMoveDirection()
        Speed.UpdateMovement(humanoid, rootPart, moveDirection, currentTime, dt)
        Speed.UpdateJumps(humanoid, rootPart, currentTime, moveDirection)
    end)
    notify("Speed", "Started with Method: " .. SpeedStatus.Method, true)
end

Speed.Stop = function()
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    SpeedStatus.Running = false
    notify("Speed", "Stopped", true)
end

Speed.SetSpeed = function(newSpeed)
    SpeedStatus.Speed = math.clamp(newSpeed, 2, 250) -- Изменен минимум на 2
    MovementEnhancements.Config.Speed.Speed = SpeedStatus.Speed
    notify("Speed", "Speed set to: " .. SpeedStatus.Speed, false)
end

Speed.SetMethod = function(newMethod)
    SpeedStatus.Method = newMethod
    MovementEnhancements.Config.Speed.Method = newMethod
    notify("Speed", "Method set to: " .. newMethod, false)
    if SpeedStatus.Running then
        Speed.Stop()
        Speed.Start()
    end
end

Speed.SetPulseTPDistance = function(value)
    SpeedStatus.PulseTPDistance = math.clamp(value, 1, 20)
    MovementEnhancements.Config.Speed.PulseTPDist = SpeedStatus.PulseTPDistance
    notify("Speed", "PulseTP Distance set to: " .. SpeedStatus.PulseTPDistance, false)
end

Speed.SetPulseTPFrequency = function(value)
    SpeedStatus.PulseTPFrequency = math.clamp(value, 0.1, 1)
    MovementEnhancements.Config.Speed.PulseTPDelay = SpeedStatus.PulseTPFrequency
    notify("Speed", "PulseTP Frequency set to: " .. SpeedStatus.PulseTPFrequency, false)
end

Speed.SetJumpInterval = function(newInterval)
    SpeedStatus.JumpInterval = math.clamp(newInterval, 0.1, 2)
    MovementEnhancements.Config.Speed.JumpInterval = SpeedStatus.JumpInterval
    notify("Speed", "JumpInterval set to: " .. SpeedStatus.JumpInterval, false)
end

Speed.SetSmoothnessFactor = function(value)
    SpeedStatus.SmoothnessFactor = math.clamp(value, 0, 1)
    MovementEnhancements.Config.Speed.SmoothnessFactor = SpeedStatus.SmoothnessFactor
    notify("Speed", "Smoothness Factor set to: " .. SpeedStatus.SmoothnessFactor, false)
end

local Fly = {}
Fly.Start = function()
    if FlyStatus.Running or not Services or not LocalPlayerObj then return end
    local humanoid, rootPart = getCharacterData()
    if not isCharacterValid(humanoid, rootPart) then return end

    FlyStatus.Running = true
    humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = rootPart
    FlyStatus.BodyVelocity = bodyVelocity

    FlyStatus.Connection = Services.RunService.Heartbeat:Connect(function(dt)
        if not FlyStatus.Enabled then
            FlyStatus.Running = false
            Fly.Stop()
            return
        end
        local humanoid, rootPart = getCharacterData()
        if not isCharacterValid(humanoid, rootPart) then
            Fly.Stop()
            return
        end
        local moveDirection = getCustomMoveDirection()
        local vertical = 0
        if FlyStatus.VerticalKeys == "E/Q" then
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.E) then
                vertical = FlyStatus.VerticalSpeed
            elseif Services.UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                vertical = -FlyStatus.VerticalSpeed
            end
        elseif FlyStatus.VerticalKeys == "Space/LShift" then
            if Services.UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                vertical = FlyStatus.VerticalSpeed
            elseif Services.UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                vertical = -FlyStatus.VerticalSpeed
            end
        end
        local velocity = moveDirection * FlyStatus.Speed + Vector3.new(0, vertical, 0)
        FlyStatus.BodyVelocity.Velocity = velocity
        humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
    end)
    notify("Fly", "Started with Speed: " .. FlyStatus.Speed .. ", VerticalSpeed: " .. FlyStatus.VerticalSpeed, true)
end

Fly.Stop = function()
    if FlyStatus.Connection then
        FlyStatus.Connection:Disconnect()
        FlyStatus.Connection = nil
    end
    if FlyStatus.BodyVelocity then
        FlyStatus.BodyVelocity:Destroy()
        FlyStatus.BodyVelocity = nil
    end
    FlyStatus.Running = false
    local humanoid, _ = getCharacterData()
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    notify("Fly", "Stopped", true)
end

Fly.SetSpeed = function(newSpeed)
    FlyStatus.Speed = math.clamp(newSpeed, 10, 200)
    MovementEnhancements.Config.Fly.Speed = FlyStatus.Speed
    notify("Fly", "Speed set to: " .. FlyStatus.Speed, false)
end

Fly.SetVerticalSpeed = function(newSpeed)
    FlyStatus.VerticalSpeed = math.clamp(newSpeed, 10, 200)
    MovementEnhancements.Config.Fly.VerticalSpeed = FlyStatus.VerticalSpeed
    notify("Fly", "Vertical Speed set to: " .. FlyStatus.VerticalSpeed, false)
end

Fly.SetVerticalKeys = function(newKeys)
    if newKeys == "E/Q" or newKeys == "Space/LShift" then
        FlyStatus.VerticalKeys = newKeys
        MovementEnhancements.Config.Fly.VerticalKeys = newKeys
        notify("Fly", "Vertical Keys set to: " .. newKeys, false)
    end
end

local NoStamina = {}
NoStamina.RemoveMaxStaminaValue = function(character)
    if not character then return end
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end
    local maxStamina = humanoid:FindFirstChild("MaxStamina")
    if maxStamina and maxStamina:IsA("IntValue") then
        maxStamina:Destroy()
        notify("NoStamina", "MaxStamina value removed", true)
    end
end

NoStamina.Start = function()
    if NoStaminaStatus.Running or not Services or not LocalPlayerObj then return end
    NoStaminaStatus.Running = true

    if NoStaminaStatus.Mode == "Block" then
        local success, staminaEvent = pcall(function()
            return Services.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ToServer"):WaitForChild("Stamina")
        end)
        if not success or not staminaEvent then
            warn("NoStamina: Failed to find Stamina RemoteEvent")
            notify("NoStamina", "Failed to find Stamina RemoteEvent.", true)
            return
        end

        if hookmetamethod then
            local oldFireServer
            oldFireServer = hookmetamethod(game, "__namecall", function(self, ...)
                if self == staminaEvent and getnamecallmethod() == "FireServer" and NoStaminaStatus.Enabled and NoStaminaStatus.Mode == "Block" then
                    return
                end
                return oldFireServer(self, ...)
            end)
            NoStaminaStatus.OriginalFireServer = oldFireServer
        else
            local success, err = pcall(function()
                for _, connection in ipairs(getconnections(staminaEvent.OnClientEvent)) do
                    pcall(function() connection:Disable() end)
                end
            end)
            if not success then
                warn("NoStamina: Failed to disable Stamina RemoteEvent connections: " .. tostring(err))
                notify("NoStamina", "Failed to block Stamina RemoteEvent.", true)
                return
            end
        end
    elseif NoStaminaStatus.Mode == "RemoveValue" then
        NoStaminaStatus.Connection = LocalPlayerObj.CharacterAdded:Connect(function(newChar)
            NoStamina.RemoveMaxStaminaValue(newChar)
        end)
        if LocalPlayerObj.Character then
            NoStamina.RemoveMaxStaminaValue(LocalPlayerObj.Character)
        end
    end

    notify("NoStamina", "Started with Mode: " .. NoStaminaStatus.Mode, true)
end

NoStamina.Stop = function()
    if NoStaminaStatus.Connection then
        NoStaminaStatus.Connection:Disconnect()
        NoStaminaStatus.Connection = nil
    end
    if NoStaminaStatus.OriginalFireServer and hookmetamethod then
        hookmetamethod(game, "__namecall", NoStaminaStatus.OriginalFireServer)
        NoStaminaStatus.OriginalFireServer = nil
    end
    NoStaminaStatus.Running = false
    notify("NoStamina", "Stopped", true)
end

NoStamina.SetMode = function(newMode)
    if newMode == "Block" or newMode == "RemoveValue" then
        if NoStaminaStatus.Running then
            NoStamina.Stop()
            NoStaminaStatus.Mode = newMode
            MovementEnhancements.Config.NoStamina.Mode = newMode
            NoStamina.Start()
        else
            NoStaminaStatus.Mode = newMode
            MovementEnhancements.Config.NoStamina.Mode = newMode
        end
        notify("NoStamina", "Mode set to: " .. newMode, false)
    end
end

local function SetupUI(UI)
    local uiElements = {}

    if UI.Sections.Timer then
        UI.Sections.Timer:Header({ Name = "Timer" })
        uiElements.TimerEnabled = UI.Sections.Timer:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Timer.Enabled,
            Callback = function(value)
                TimerStatus.Enabled = value
                MovementEnhancements.Config.Timer.Enabled = value
                if value then Timer.Start() else Timer.Stop() end
            end
        }, "TimerEnabled")
        uiElements.TimerSpeed = UI.Sections.Timer:Slider({
            Name = "Speed",
            Minimum = 1,
            Maximum = 15,
            Default = MovementEnhancements.Config.Timer.Speed,
            Precision = 1,
            Callback = function(value)
                Timer.SetSpeed(value)
            end
        }, "TimerSpeed")
        uiElements.TimerKey = UI.Sections.Timer:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Timer.ToggleKey,
            Callback = function(value)
                TimerStatus.Key = value
                MovementEnhancements.Config.Timer.ToggleKey = value
                if isInputFocused() then return end
                if TimerStatus.Enabled then
                    if TimerStatus.Running then Timer.Stop() else Timer.Start() end
                else
                    notify("Timer", "Enable Timer to use keybind.", true)
                end
            end
        }, "TimerKey")
    end

    if UI.Sections.Disabler then
        UI.Sections.Disabler:Header({ Name = "Disabler" })
        uiElements.DisablerEnabled = UI.Sections.Disabler:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Disabler.Enabled,
            Callback = function(value)
                DisablerStatus.Enabled = value
                MovementEnhancements.Config.Disabler.Enabled = value
                if value then Disabler.Start() else Disabler.Stop() end
            end
        }, "DisablerEnabled")
        uiElements.DisablerKey = UI.Sections.Disabler:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Disabler.ToggleKey,
            Callback = function(value)
                DisablerStatus.Key = value
                MovementEnhancements.Config.Disabler.ToggleKey = value
                if isInputFocused() then return end
                if DisablerStatus.Enabled then
                    if DisablerStatus.Running then Disabler.Stop() else Disabler.Start() end
                else
                    notify("Disabler", "Enable Disabler to use keybind.", true)
                end
            end
        }, "DisablerKey")
    end

    if UI.Sections.Speed then
        UI.Sections.Speed:Header({ Name = "Speed" })
        uiElements.SpeedEnabled = UI.Sections.Speed:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Speed.Enabled,
            Callback = function(value)
                SpeedStatus.Enabled = value
                MovementEnhancements.Config.Speed.Enabled = value
                if value then Speed.Start() else Speed.Stop() end
            end
        }, "SpeedEnabled")
        uiElements.SpeedAutoJump = UI.Sections.Speed:Toggle({
            Name = "AutoJump",
            Default = MovementEnhancements.Config.Speed.AutoJump,
            Callback = function(value)
                SpeedStatus.AutoJump = value
                MovementEnhancements.Config.Speed.AutoJump = value
                notify("Speed", "AutoJump " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "SpeedAutoJump")
        uiElements.SpeedMethod = UI.Sections.Speed:Dropdown({
            Name = "Method",
            Options = {"CFrame", "PulseTP"},
            Default = MovementEnhancements.Config.Speed.Method,
            Callback = function(value)
                Speed.SetMethod(value)
            end
        }, "SpeedMethod")
        uiElements.Speed = UI.Sections.Speed:Slider({
            Name = "Speed",
            Minimum = 2, -- Изменен минимум на 2
            Maximum = 250,
            Default = MovementEnhancements.Config.Speed.Speed,
            Precision = 1,
            Callback = function(value)
                Speed.SetSpeed(value)
            end
        }, "Speed")
        uiElements.SpeedJumpInterval = UI.Sections.Speed:Slider({
            Name = "Jump Interval",
            Minimum = 0.1,
            Maximum = 2,
            Default = MovementEnhancements.Config.Speed.JumpInterval,
            Precision = 1,
            Callback = function(value)
                Speed.SetJumpInterval(value)
            end
        }, "SpeedJumpInterval")
        uiElements.SpeedPulseTPDistance = UI.Sections.Speed:Slider({
            Name = "PulseTP Dist",
            Minimum = 1,
            Maximum = 20,
            Default = MovementEnhancements.Config.Speed.PulseTPDist,
            Precision = 1,
            Callback = function(value)
                Speed.SetPulseTPDistance(value)
            end
        }, "SpeedPulseTPDistance")
        uiElements.SpeedPulseTPFrequency = UI.Sections.Speed:Slider({
            Name = "PulseTP Delay",
            Minimum = 0.1,
            Maximum = 1,
            Default = MovementEnhancements.Config.Speed.PulseTPDelay,
            Precision = 2,
            Callback = function(value)
                Speed.SetPulseTPFrequency(value)
            end
        }, "SpeedPulseTPFrequency")
        uiElements.SpeedSmoothnessFactor = UI.Sections.Speed:Slider({
            Name = "Smoothness Factor",
            Minimum = 0,
            Maximum = 1,
            Default = MovementEnhancements.Config.Speed.SmoothnessFactor,
            Precision = 2,
            Callback = function(value)
                Speed.SetSmoothnessFactor(value)
            end
        }, "SpeedSmoothnessFactor")
        uiElements.SpeedKey = UI.Sections.Speed:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Speed.ToggleKey,
            Callback = function(value)
                SpeedStatus.Key = value
                MovementEnhancements.Config.Speed.ToggleKey = value
                if isInputFocused() then return end
                if SpeedStatus.Enabled then
                    if SpeedStatus.Running then Speed.Stop() else Speed.Start() end
                else
                    notify("Speed", "Enable Speed to use keybind.", true)
                end
            end
        }, "SpeedKey")
    end

    if UI.Sections.Fly then
        UI.Sections.Fly:Header({ Name = "Fly" })
        uiElements.FlyEnabled = UI.Sections.Fly:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.Fly.Enabled,
            Callback = function(value)
                FlyStatus.Enabled = value
                MovementEnhancements.Config.Fly.Enabled = value
                if value then Fly.Start() else Fly.Stop() end
            end
        }, "FlyEnabled")
        uiElements.FlySpeed = UI.Sections.Fly:Slider({
            Name = "Speed",
            Minimum = 10,
            Maximum = 200,
            Default = MovementEnhancements.Config.Fly.Speed,
            Precision = 1,
            Callback = function(value)
                Fly.SetSpeed(value)
            end
        }, "FlySpeed")
        uiElements.FlyVerticalSpeed = UI.Sections.Fly:Slider({
            Name = "Vertical Speed",
            Minimum = 10,
            Maximum = 200,
            Default = MovementEnhancements.Config.Fly.VerticalSpeed,
            Precision = 1,
            Callback = function(value)
                Fly.SetVerticalSpeed(value)
            end
        }, "FlyVerticalSpeed")
        uiElements.FlyVerticalKeys = UI.Sections.Fly:Dropdown({
            Name = "Vertical Keys",
            Options = {"E/Q", "Space/LShift"},
            Default = MovementEnhancements.Config.Fly.VerticalKeys,
            Callback = function(value)
                Fly.SetVerticalKeys(value)
            end
        }, "FlyVerticalKeys")
        uiElements.FlyKey = UI.Sections.Fly:Keybind({
            Name = "Toggle Key",
            Default = MovementEnhancements.Config.Fly.ToggleKey,
            Callback = function(value)
                FlyStatus.Key = value
                MovementEnhancements.Config.Fly.ToggleKey = value
                if isInputFocused() then return end
                if FlyStatus.Enabled then
                    if FlyStatus.Running then Fly.Stop() else Fly.Start() end
                else
                    notify("Fly", "Enable Fly to use keybind.", true)
                end
            end
        }, "FlyKey")
    end

    if UI.Sections.NoStamina then
        UI.Sections.NoStamina:Header({ Name = "No Stamina" })
        uiElements.NoStaminaEnabled = UI.Sections.NoStamina:Toggle({
            Name = "Enabled",
            Default = MovementEnhancements.Config.NoStamina.Enabled,
            Callback = function(value)
                NoStaminaStatus.Enabled = value
                MovementEnhancements.Config.NoStamina.Enabled = value
                if value then NoStamina.Start() else NoStamina.Stop() end
            end
        }, "NoStaminaEnabled")
        uiElements.NoStaminaMode = UI.Sections.NoStamina:Dropdown({
            Name = "Mode",
            Options = {"Block", "RemoveValue"},
            Default = MovementEnhancements.Config.NoStamina.Mode,
            Callback = function(value)
                NoStamina.SetMode(value)
            end
        }, "NoStaminaMode")
    end

    local localconfigSection = UI.Tabs.Config:Section({ Name = "Movement Enhancements Sync", Side = "Right" })
    localconfigSection:Header({ Name = "LocalPlayer Settings Sync" })
    localconfigSection:Button({
        Name = "Sync Config",
        Callback = function()
            MovementEnhancements.Config.Timer.Enabled = uiElements.TimerEnabled:GetState()
            MovementEnhancements.Config.Timer.Speed = uiElements.TimerSpeed:GetValue()
            MovementEnhancements.Config.Timer.ToggleKey = uiElements.TimerKey:GetBind()

            MovementEnhancements.Config.Disabler.Enabled = uiElements.DisablerEnabled:GetState()
            MovementEnhancements.Config.Disabler.ToggleKey = uiElements.DisablerKey:GetBind()

            MovementEnhancements.Config.Speed.Enabled = uiElements.SpeedEnabled:GetState()
            MovementEnhancements.Config.Speed.AutoJump = uiElements.SpeedAutoJump:GetState()
            local speedMethodOptions = uiElements.SpeedMethod:GetOptions()
            for option, selected in pairs(speedMethodOptions) do
                if selected then
                    MovementEnhancements.Config.Speed.Method = option
                    break
                end
            end
            MovementEnhancements.Config.Speed.Speed = uiElements.Speed:GetValue()
            MovementEnhancements.Config.Speed.JumpInterval = uiElements.SpeedJumpInterval:GetValue()
            MovementEnhancements.Config.Speed.PulseTPDist = uiElements.SpeedPulseTPDistance:GetValue()
            MovementEnhancements.Config.Speed.PulseTPDelay = uiElements.SpeedPulseTPFrequency:GetValue()
            MovementEnhancements.Config.Speed.SmoothnessFactor = uiElements.SpeedSmoothnessFactor:GetValue()
            MovementEnhancements.Config.Speed.ToggleKey = uiElements.SpeedKey:GetBind()

            MovementEnhancements.Config.Fly.Enabled = uiElements.FlyEnabled:GetState()
            MovementEnhancements.Config.Fly.Speed = uiElements.FlySpeed:GetValue()
            MovementEnhancements.Config.Fly.VerticalSpeed = uiElements.FlyVerticalSpeed:GetValue()
            local flyVerticalKeysOptions = uiElements.FlyVerticalKeys:GetOptions()
            for option, selected in pairs(flyVerticalKeysOptions) do
                if selected then
                    MovementEnhancements.Config.Fly.VerticalKeys = option
                    break
                end
            end
            MovementEnhancements.Config.Fly.ToggleKey = uiElements.FlyKey:GetBind()

            MovementEnhancements.Config.NoStamina.Enabled = uiElements.NoStaminaEnabled:GetState()
            local noStaminaModeOptions = uiElements.NoStaminaMode:GetOptions()
            for option, selected in pairs(noStaminaModeOptions) do
                if selected then
                    MovementEnhancements.Config.NoStamina.Mode = option
                    break
                end
            end

            TimerStatus.Enabled = MovementEnhancements.Config.Timer.Enabled
            TimerStatus.Speed = MovementEnhancements.Config.Timer.Speed
            TimerStatus.Key = MovementEnhancements.Config.Timer.ToggleKey
            if TimerStatus.Enabled then
                if not TimerStatus.Running then Timer.Start() end
            else
                if TimerStatus.Running then Timer.Stop() end
            end

            DisablerStatus.Enabled = MovementEnhancements.Config.Disabler.Enabled
            DisablerStatus.Key = MovementEnhancements.Config.Disabler.ToggleKey
            if DisablerStatus.Enabled then
                if not DisablerStatus.Running then Disabler.Start() end
            else
                if DisablerStatus.Running then Disabler.Stop() end
            end

            SpeedStatus.Enabled = MovementEnhancements.Config.Speed.Enabled
            SpeedStatus.AutoJump = MovementEnhancements.Config.Speed.AutoJump
            SpeedStatus.Method = MovementEnhancements.Config.Speed.Method
            SpeedStatus.Speed = MovementEnhancements.Config.Speed.Speed
            SpeedStatus.JumpInterval = MovementEnhancements.Config.Speed.JumpInterval
            SpeedStatus.PulseTPDistance = MovementEnhancements.Config.Speed.PulseTPDist
            SpeedStatus.PulseTPFrequency = MovementEnhancements.Config.Speed.PulseTPDelay
            SpeedStatus.SmoothnessFactor = MovementEnhancements.Config.Speed.SmoothnessFactor
            SpeedStatus.Key = MovementEnhancements.Config.Speed.ToggleKey
            if SpeedStatus.Enabled then
                if not SpeedStatus.Running then Speed.Start() end
            else
                if SpeedStatus.Running then Speed.Stop() end
            end

            FlyStatus.Enabled = MovementEnhancements.Config.Fly.Enabled
            FlyStatus.Speed = MovementEnhancements.Config.Fly.Speed
            FlyStatus.VerticalSpeed = MovementEnhancements.Config.Fly.VerticalSpeed
            FlyStatus.VerticalKeys = MovementEnhancements.Config.Fly.VerticalKeys
            FlyStatus.Key = MovementEnhancements.Config.Fly.ToggleKey
            if FlyStatus.Enabled then
                if not FlyStatus.Running then Fly.Start() end
            else
                if FlyStatus.Running then Fly.Stop() end
            end

            NoStaminaStatus.Enabled = MovementEnhancements.Config.NoStamina.Enabled
            NoStaminaStatus.Mode = MovementEnhancements.Config.NoStamina.Mode
            if NoStaminaStatus.Enabled then
                if not NoStaminaStatus.Running then NoStamina.Start() end
            else
                if NoStaminaStatus.Running then NoStamina.Stop() end
            end

            notify("Syllinse", "Config synchronized!", true)
        end
    })
end

function MovementEnhancements.Init(UI, coreParam, notifyFunc)
    core = coreParam
    Services = core.Services
    PlayerData = core.PlayerData
    notify = notifyFunc
    LocalPlayerObj = PlayerData.LocalPlayer

    _G.setTimerSpeed = Timer.SetSpeed
    _G.setSpeed = Speed.SetSpeed
    _G.setFlySpeed = Fly.SetSpeed
    _G.setFlyVerticalSpeed = Fly.SetVerticalSpeed
    _G.setFlyVerticalKeys = Fly.SetVerticalKeys
    _G.setNoStaminaMode = NoStamina.SetMode

    if LocalPlayerObj then
        LocalPlayerObj.CharacterAdded:Connect(function(newChar)
            if DisablerStatus.Enabled then
                Disabler.DisableSignals(newChar)
            end
            if SpeedStatus.Enabled then
                Speed.Start()
            end
            if FlyStatus.Enabled then
                Fly.Start()
            end
            if NoStaminaStatus.Enabled and NoStaminaStatus.Mode == "RemoveValue" then
                NoStamina.RemoveMaxStaminaValue(newChar)
            end
        end)
    end

    SetupUI(UI)
end

function MovementEnhancements:Destroy()
    if TimerStatus.Connection then
        TimerStatus.Connection:Disconnect()
        TimerStatus.Connection = nil
    end
    if DisablerStatus.Connection then
        DisablerStatus.Connection:Disconnect()
        DisablerStatus.Connection = nil
    end
    if SpeedStatus.Connection then
        SpeedStatus.Connection:Disconnect()
        SpeedStatus.Connection = nil
    end
    if FlyStatus.Connection then
        FlyStatus.Connection:Disconnect()
        FlyStatus.Connection = nil
    end
    if FlyStatus.BodyVelocity then
        FlyStatus.BodyVelocity:Destroy()
        FlyStatus.BodyVelocity = nil
    end
    if NoStaminaStatus.Connection then
        NoStaminaStatus.Connection:Disconnect()
        NoStaminaStatus.Connection = nil
    end
    if NoStaminaStatus.OriginalFireServer and hookmetamethod then
        hookmetamethod(game, "__namecall", NoStaminaStatus.OriginalFireServer)
        NoStaminaStatus.OriginalFireServer = nil
    end
    TimerStatus.Running = false
    DisablerStatus.Running = false
    SpeedStatus.Running = false
    FlyStatus.Running = false
    NoStaminaStatus.Running = false
end

return MovementEnhancements
