local BaitAttack = {}

function BaitAttack.Init(UI, Core, notify)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")

    local LocalPlayer = Players.LocalPlayer
    local localCharacter = LocalPlayer.Character
    local localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")
    local defaultWalkSpeed = game:GetService("StarterPlayer").StarterHumanoid.WalkSpeed
    local swingWalkSpeed = defaultWalkSpeed * 0.75

    local State = {
        BaitAttack = {
            Enabled = { Value = false, Default = false },
            FakeParry = { Value = false, Default = false },
            FakeRiposte = { Value = false, Default = false },
            FakeAttack = { Value = false, Default = false },
            FakeParryKey = { Value = nil, Default = nil },
            FakeRiposteKey = { Value = nil, Default = nil },
            FakeAttackKey = { Value = nil, Default = nil },
            ForceStopKey = { Value = nil, Default = nil },
            CheckStance = { Value = false, Default = false },
            ParryHold = { Value = false, Default = false },
            ParryAutoHold = { Value = 2, Default = 2 },
            AutoHoldEnabled = { Value = true, Default = true },
            ForceStopEnabled = { Value = false, Default = false },
            KeybindDisplayEnabled = { Value = true, Default = true },
            KeybindDisplayScale = { Value = 1, Default = 1 },
            ParryDisplayEnabled = { Value = true, Default = true },
            RiposteDisplayEnabled = { Value = true, Default = true },
            AttackDisplayEnabled = { Value = true, Default = true },
            ForceStopDisplayEnabled = { Value = true, Default = true }
        }
    }

    local isPerformingAction = false
    local parryAnimationTrack = nil
    local parryHoldConnection = nil
    local inputConnection = nil
    local keybindDisplays = {}
    local keybindPositions = {}
    local draggingFrame = nil
    local dragStartPos = nil
    local dragStartMousePos = nil

    -- Проверка валидности состояния
    local function isValidState()
        if UserInputService:GetFocusedTextBox() then
            return false, "Input focused"
        end
        if not (localCharacter and localHumanoid and localHumanoid.Health > 0) then
            return false, "Invalid character or humanoid"
        end
        if not State.BaitAttack.Enabled.Value then
            return false, "BaitAttack disabled"
        end
        if isPerformingAction then
            return false, "Already performing action"
        end
        if State.BaitAttack.CheckStance.Value then
            local stance = localCharacter:FindFirstChild("Stance", true)
            local currentStance = stance and stance.Value or "Idle"
            if currentStance ~= "Idle" and currentStance ~= "Recovery" then
                return false, "Invalid stance: " .. tostring(currentStance)
            end
        end
        return true, nil
    end

    -- Получение настроек оружия
    local function getLocalWeaponSettings()
        if not localCharacter then
            return nil, nil, "No character found"
        end
        local weapon
        for _, child in pairs(localCharacter:GetChildren()) do
            if child:IsA("Tool") then
                weapon = child
                break
            end
        end
        if not weapon then
            return nil, nil, "No weapon equipped"
        end
        local settingsModule = weapon:FindFirstChild("Settings")
        if not settingsModule then
            return nil, nil, "No settings module found"
        end
        local settings = require(settingsModule)
        if not settings or type(settings) ~= "table" or not settings.Type then
            return nil, nil, "Invalid weapon settings"
        end
        return settings, weapon, nil
    end

    -- Воспроизведение анимации
    local function playAnimationWithTiming(action, stateKey, windup, speed, recovery, walkSpeed)
        local valid, errorMsg = isValidState()
        if not valid then
            notify("BaitAttack", errorMsg, false)
            return false
        end
        isPerformingAction = true
        local settings, weapon, errorMsg = getLocalWeaponSettings()
        if not settings then
            notify("BaitAttack", errorMsg, false)
            isPerformingAction = false
            return false
        end
        local animationsModule = ReplicatedStorage:FindFirstChild("ClientModule") and ReplicatedStorage.ClientModule:FindFirstChild("WeaponAnimations")
        if not animationsModule then
            notify("BaitAttack", "WeaponAnimations module not found", false)
            isPerformingAction = false
            return false
        end
        local animations = require(animationsModule)[settings.Type]
        if not animations then
            notify("BaitAttack", "No animations for weapon type: " .. tostring(settings.Type), false)
            isPerformingAction = false
            return false
        end
        local animationId
        if action == "FakeAttack" then
            local swingAnimations = {animations.RightSwing, animations.LeftSwing}
            animationId = swingAnimations[math.random(1, #swingAnimations)]
        else
            animationId = animations[action]
        end
        if not animationId then
            notify("BaitAttack", "No animation ID for action: " .. action, false)
            isPerformingAction = false
            return false
        end
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://" .. animationId
        local success, animationTrack = pcall(function()
            return localHumanoid:LoadAnimation(animation)
        end)
        if not success or not animationTrack then
            notify("BaitAttack", "Failed to load animation for " .. action, false)
            animation:Destroy()
            isPerformingAction = false
            return false
        end

        animationTrack:Play(windup)
        animationTrack:AdjustSpeed(speed)
        if localHumanoid then
            localHumanoid.WalkSpeed = walkSpeed
        end
        local displayKey = action == "FakeAttack" and "Attack" or action
        if action == "Parry" then
            parryAnimationTrack = animationTrack
            if not State.BaitAttack.ParryHold.Value and State.BaitAttack.AutoHoldEnabled.Value then
                task.spawn(function()
                    task.wait(State.BaitAttack.ParryAutoHold.Value)
                    if animationTrack and animationTrack.IsPlaying then
                        animationTrack:Stop(recovery)
                        animationTrack:Destroy()
                        parryAnimationTrack = nil
                    end
                    if localHumanoid then
                        localHumanoid.WalkSpeed = defaultWalkSpeed
                    end
                    isPerformingAction = false
                    if State.BaitAttack[stateKey] then
                        State.BaitAttack[stateKey].Value = false
                    end
                    Core.BulwarkTarget.CombatState = nil
                end)
            elseif not State.BaitAttack.ParryHold.Value then
                task.spawn(function()
                    task.wait(0.4)
                    if animationTrack and animationTrack.IsPlaying then
                        animationTrack:Stop(recovery)
                        animationTrack:Destroy()
                        parryAnimationTrack = nil
                    end
                    if localHumanoid then
                        localHumanoid.WalkSpeed = defaultWalkSpeed
                    end
                    isPerformingAction = false
                    if State.BaitAttack[stateKey] then
                        State.BaitAttack[stateKey].Value = false
                    end
                    Core.BulwarkTarget.CombatState = nil
                end)
            end
        else
            task.spawn(function()
                task.wait(windup)
                if animationTrack and animationTrack.IsPlaying then
                    if action == "FakeAttack" then
                        animationTrack:AdjustSpeed((animationTrack.Length / (settings.Release or 0.3)) * 2)
                        task.wait(settings.Release or 0.3)
                    end
                    if animationTrack and animationTrack.IsPlaying then
                        animationTrack:Stop(recovery)
                        animationTrack:Destroy()
                    end
                    if localHumanoid then
                        localHumanoid.WalkSpeed = defaultWalkSpeed
                    end
                    isPerformingAction = false
                    if State.BaitAttack[stateKey] then
                        State.BaitAttack[stateKey].Value = false
                    end
                    Core.BulwarkTarget.CombatState = nil
                end
            end)
        end
        return true
    end

    -- Принудительная остановка
    local function forceStop()
        local valid, errorMsg = isValidState()
        if not valid then
            notify("BaitAttack", errorMsg, false)
            return false
        end
        isPerformingAction = false
        State.BaitAttack.FakeParry.Value = false
        State.BaitAttack.FakeRiposte.Value = false
        State.BaitAttack.FakeAttack.Value = false
        Core.BulwarkTarget.CombatState = nil

        local stanceValue = localCharacter:FindFirstChild("Stance", true)
        if stanceValue then
            stanceValue.Value = "Idle"
        end
        local args = { [1] = "Idle" }
        local changeStanceEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ToServer"):WaitForChild("ChangeStance")
        if changeStanceEvent and changeStanceEvent:IsA("RemoteEvent") then
            changeStanceEvent:FireServer(unpack(args))
        end
        task.spawn(function()
            local startTime = tick()
            while tick() - startTime < 3 do
                if stanceValue and stanceValue.Value ~= "Idle" then
                    stanceValue.Value = "Idle"
                    if changeStanceEvent and changeStanceEvent:IsA("RemoteEvent") then
                        changeStanceEvent:FireServer(unpack(args))
                    end
                end
                task.wait(0.1)
            end
        end)
        notify("BaitAttack", "Force Stop Activated", true)
        return true
    end

    -- Создание UI для кейбинда
    local function createKeybindFrame(keybind, index, scale)
        local frame = Instance.new("Frame")
        frame.Name = keybind.Name
        frame.Size = UDim2.new(0, 75 * scale, 0, 75 * scale)
        frame.Position = keybindPositions[keybind.Name] or UDim2.new(0, (index - 1) * (90 * scale) + 10, 0, 10)
        frame.BackgroundTransparency = 1
        frame.ClipsDescendants = true

        local topFrame = Instance.new("Frame")
        topFrame.Size = UDim2.new(1, 0, 0.4, 0)
        topFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
        topFrame.BorderSizePixel = 0
        local uiCornerTop = Instance.new("UICorner")
        uiCornerTop.CornerRadius = UDim.new(0, 8 * scale)
        uiCornerTop.Parent = topFrame
        topFrame.Parent = frame

        local maskFrame = Instance.new("Frame")
        maskFrame.Size = UDim2.new(1, 0, 0.5, 0)
        maskFrame.Position = UDim2.new(0, 0, 0.5, 0)
        maskFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 45)
        maskFrame.BorderSizePixel = 0
        maskFrame.Parent = topFrame

        local icon = Instance.new("ImageLabel")
        icon.Size = UDim2.new(0, 22 * scale, 0, 22 * scale)
        icon.Position = UDim2.new(0.5, 0, 0.005, 0)
        icon.AnchorPoint = Vector2.new(0.5, 0.005)
        icon.Image = "rbxassetid://11710306232"
        icon.ImageColor3 = Color3.fromRGB(150, 150, 150)
        icon.ImageTransparency = 0.5
        icon.BackgroundTransparency = 1
        icon.Parent = topFrame

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(1, 0, 0, 15 * scale)
        nameLabel.Position = UDim2.new(0, 0, 0.35, 0)
        nameLabel.Text = keybind.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = false
        nameLabel.TextSize = 16 * scale
        nameLabel.Font = Enum.Font.Gotham
        nameLabel.BackgroundTransparency = 1
        nameLabel.Parent = topFrame

        local bottomFrameContainer = Instance.new("Frame")
        bottomFrameContainer.Size = UDim2.new(1, 0, 0.6, 0)
        bottomFrameContainer.Position = UDim2.new(0, 0, 0.4, 0)
        bottomFrameContainer.BackgroundTransparency = 1
        bottomFrameContainer.ClipsDescendants = true
        bottomFrameContainer.Parent = frame

        local bottomFrame = Instance.new("Frame")
        bottomFrame.Size = UDim2.new(1, 0, 1, 8 * scale)
        bottomFrame.Position = UDim2.new(0, 0, 0, -8 * scale)
        bottomFrame.BackgroundColor3 = Color3.fromRGB(20, 30, 50)
        bottomFrame.BackgroundTransparency = 0.3
        bottomFrame.BorderSizePixel = 0
        local uiCornerBottom = Instance.new("UICorner")
        uiCornerBottom.CornerRadius = UDim.new(0, 8 * scale)
        uiCornerBottom.Parent = bottomFrame
        bottomFrame.Parent = bottomFrameContainer

        local keyLabel = Instance.new("TextLabel")
        keyLabel.Size = UDim2.new(1, 0, 1, 0)
        keyLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        keyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        keyLabel.Text = State.BaitAttack[keybind.State].Value and tostring(State.BaitAttack[keybind.State].Value):match("Enum%.KeyCode%.(.+)") or ""
        keyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        keyLabel.TextScaled = false
        keyLabel.TextSize = 22 * scale
        keyLabel.Font = Enum.Font.Gotham
        keyLabel.BackgroundTransparency = 1
        keyLabel.Parent = bottomFrameContainer

        local function startDragging(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and not UserInputService:GetFocusedTextBox() then
                draggingFrame = frame
                dragStartPos = frame.Position
                dragStartMousePos = input.Position
            end
        end

        local function stopDragging(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                draggingFrame = nil
                dragStartPos = nil
                dragStartMousePos = nil
                keybindPositions[frame.Name] = frame.Position
            end
        end

        topFrame.InputBegan:Connect(startDragging)
        topFrame.InputEnded:Connect(stopDragging)
        bottomFrameContainer.InputBegan:Connect(startDragging)
        bottomFrameContainer.InputEnded:Connect(stopDragging)

        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and draggingFrame == frame then
                local delta = input.Position - dragStartMousePos
                frame.Position = UDim2.new(
                    dragStartPos.X.Scale,
                    dragStartPos.X.Offset + delta.X,
                    dragStartPos.Y.Scale,
                    dragStartPos.Y.Offset + delta.Y
                )
            end
        end)

        return frame, keyLabel
    end

    local function updateKeybindDisplays()
        if not State.BaitAttack.Enabled.Value or not State.BaitAttack.KeybindDisplayEnabled.Value then
            for _, display in pairs(keybindDisplays) do
                keybindPositions[display.Frame.Name] = display.Frame.Position
                display.Frame:Destroy()
            end
            keybindDisplays = {}
            return
        end

        local keybinds = {
            { Name = "Parry", State = "FakeParryKey", Enabled = State.BaitAttack.ParryDisplayEnabled.Value },
            { Name = "Riposte", State = "FakeRiposteKey", Enabled = State.BaitAttack.RiposteDisplayEnabled.Value },
            { Name = "Attack", State = "FakeAttackKey", Enabled = State.BaitAttack.AttackDisplayEnabled.Value },
            { Name = "ForceStop", State = "ForceStopKey", Enabled = State.BaitAttack.ForceStopDisplayEnabled.Value }
        }

        local scale = State.BaitAttack.KeybindDisplayScale.Value
        local screenGui = CoreGui:FindFirstChild("BaitAttackKeybinds")
        if not screenGui then
            screenGui = Instance.new("ScreenGui")
            screenGui.Name = "BaitAttackKeybinds"
            screenGui.Parent = CoreGui
            screenGui.ResetOnSpawn = false
        end

        local visibleKeybinds = {}
        for _, keybind in ipairs(keybinds) do
            if keybind.Enabled then
                table.insert(visibleKeybinds, keybind)
            end
        end

        -- Удаляем менюшки, которые больше не нужны
        for key, display in pairs(keybindDisplays) do
            local found = false
            for _, keybind in ipairs(visibleKeybinds) do
                if keybind.Name == key then
                    found = true
                    break
                end
            end
            if not found then
                keybindPositions[display.Frame.Name] = display.Frame.Position
                display.Frame:Destroy()
                keybindDisplays[key] = nil
            end
        end

        -- Обновляем или создаём менюшки
        for i, keybind in ipairs(visibleKeybinds) do
            if keybindDisplays[keybind.Name] then
                local display = keybindDisplays[keybind.Name]
                if display.Frame and display.Frame.Parent and display.KeyLabel and display.KeyLabel.Parent then
                    display.KeyLabel.Text = State.BaitAttack[keybind.State].Value and tostring(State.BaitAttack[keybind.State].Value):match("Enum%.KeyCode%.(.+)") or ""
                    display.Frame.Size = UDim2.new(0, 75 * scale, 0, 75 * scale)
                    local topFrame = display.Frame:FindFirstChildWhichIsA("Frame")
                    if topFrame then
                        local uiCornerTop = topFrame:FindFirstChildWhichIsA("UICorner")
                        if uiCornerTop then
                            uiCornerTop.CornerRadius = UDim.new(0, 8 * scale)
                        end
                        local icon = topFrame:FindFirstChildWhichIsA("ImageLabel")
                        if icon then
                            icon.Size = UDim2.new(0, 22 * scale, 0, 22 * scale)
                        end
                        local nameLabel = topFrame:FindFirstChildWhichIsA("TextLabel")
                        if nameLabel then
                            nameLabel.Size = UDim2.new(1, 0, 0, 15 * scale)
                            nameLabel.TextSize = 16 * scale
                        end
                    end
                    local bottomFrameContainer = display.Frame:FindFirstChildWhichIsA("Frame", true)
                    if bottomFrameContainer then
                        local bottomFrame = bottomFrameContainer:FindFirstChildWhichIsA("Frame")
                        if bottomFrame then
                            bottomFrame.Size = UDim2.new(1, 0, 1, 8 * scale)
                            bottomFrame.Position = UDim2.new(0, 0, 0, -8 * scale)
                            local uiCornerBottom = bottomFrame:FindFirstChildWhichIsA("UICorner")
                            if uiCornerBottom then
                                uiCornerBottom.CornerRadius = UDim.new(0, 8 * scale)
                            end
                        end
                    end
                    display.KeyLabel.TextSize = 22 * scale
                    if keybindPositions[keybind.Name] then
                        display.Frame.Position = keybindPositions[keybind.Name]
                    end
                end
            else
                local frame, keyLabel = createKeybindFrame(keybind, i, scale)
                frame.Parent = screenGui
                keybindDisplays[keybind.Name] = { Frame = frame, KeyLabel = keyLabel }
            end
        end
    end

    -- Обработка ввода
    local function onInputBegan(input, gameProcessedEvent)
        if gameProcessedEvent then
            return
        end
        local valid, errorMsg = isValidState()
        if not valid then
            return
        end

        local function handleAction(key, stateKey, action, windup, speed, recovery, walkSpeed)
            if State.BaitAttack[key].Value == nil then
                return
            end
            if input.KeyCode == State.BaitAttack[key].Value and not State.BaitAttack[stateKey].Value then
                State.BaitAttack[stateKey].Value = true
                local displayKey = action == "FakeAttack" and "Attack" or action
                if playAnimationWithTiming(action, stateKey, windup, speed, recovery, walkSpeed) then
                    notify("BaitAttack", "Fake " .. action .. " Activated", true)
                    Core.BulwarkTarget.CombatState = "BaitAttack (" .. stateKey .. ")"
                    if action == "Parry" and State.BaitAttack.ParryHold.Value then
                        parryHoldConnection = UserInputService.InputEnded:Connect(function(endInput)
                            if endInput.KeyCode == State.BaitAttack.FakeParryKey.Value then
                                if parryAnimationTrack and parryAnimationTrack.IsPlaying then
                                    parryAnimationTrack:Stop(0.2)
                                    parryAnimationTrack:Destroy()
                                    parryAnimationTrack = nil
                                end
                                if localHumanoid then
                                    localHumanoid.WalkSpeed = defaultWalkSpeed
                                end
                                isPerformingAction = false
                                State.BaitAttack.FakeParry.Value = false
                                Core.BulwarkTarget.CombatState = nil
                                if parryHoldConnection then
                                    parryHoldConnection:Disconnect()
                                    parryHoldConnection = nil
                                end
                            end
                        end)
                    end
                    if action ~= "Parry" or (not State.BaitAttack.ParryHold.Value and State.BaitAttack.AutoHoldEnabled.Value) then
                        task.spawn(function()
                            task.wait(action == "Parry" and State.BaitAttack.ParryAutoHold.Value or 0.5)
                            if State.BaitAttack[stateKey] then
                                State.BaitAttack[stateKey].Value = false
                            end
                            Core.BulwarkTarget.CombatState = nil
                        end)
                    end
                else
                    if State.BaitAttack[stateKey] then
                        State.BaitAttack[stateKey].Value = false
                    end
                end
            end
        end

        handleAction("FakeParryKey", "FakeParry", "Parry", 0.1, 1, 0.2, 7)
        handleAction("FakeRiposteKey", "FakeRiposte", "Riposte", 0.1, 0, 0.7, 1)
        local settings = getLocalWeaponSettings()
        handleAction("FakeAttackKey", "FakeAttack", "FakeAttack", settings and (settings.Windup or 0.3) or 0.3, 0, settings and (settings.Recovery or 0.45) or 0.45, swingWalkSpeed)

        if State.BaitAttack.ForceStopKey.Value and input.KeyCode == State.BaitAttack.ForceStopKey.Value and State.BaitAttack.ForceStopEnabled.Value then
            forceStop()
        end
    end

    -- Запуск и остановка
    local function start()
        if inputConnection then
            inputConnection:Disconnect()
            inputConnection = nil
        end
        if State.BaitAttack.Enabled.Value then
            inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
        end
        updateKeybindDisplays()
    end

    local function stop()
        if inputConnection then
            inputConnection:Disconnect()
            inputConnection = nil
        end
        if parryAnimationTrack and parryAnimationTrack.IsPlaying then
            parryAnimationTrack:Stop(0.2)
            parryAnimationTrack:Destroy()
            parryAnimationTrack = nil
        end
        if parryHoldConnection then
            parryHoldConnection:Disconnect()
            parryHoldConnection = nil
        end
        if localHumanoid then
            for _, track in pairs(localHumanoid:GetPlayingAnimationTracks()) do
                track:Stop(0.2)
                track:Destroy()
            end
            localHumanoid.WalkSpeed = defaultWalkSpeed
        end
        isPerformingAction = false
        State.BaitAttack.FakeParry.Value = false
        State.BaitAttack.FakeRiposte.Value = false
        State.BaitAttack.FakeAttack.Value = false
        Core.BulwarkTarget.CombatState = nil
        for _, display in pairs(keybindDisplays) do
            display.Frame:Destroy()
        end
        keybindDisplays = {}
        updateKeybindDisplays()
    end

    LocalPlayer.CharacterAdded:Connect(function(character)
        localCharacter = character
        localHumanoid = character:WaitForChild("Humanoid", 5)
        if State.BaitAttack.Enabled.Value then
            start()
        end
    end)

    wait(0.7)
    if UI.Tabs and UI.Tabs.Combat then
        local section = UI.Sections.BaitAttack or UI.Tabs.Combat:Section({ Name = "Bait Attack", Side = "Left" })
        UI.Sections.BaitAttack = section
        section:Header({ Name = "Bait Attack" })
        section:SubLabel({ Text = "Plays fake Parry/Riposte/Attack animations without server interaction" })
        section:Toggle({
            Name = "Enabled",
            Default = State.BaitAttack.Enabled.Default,
            Callback = function(value)
                State.BaitAttack.Enabled.Value = value
                if value then
                    start()
                    notify("BaitAttack", "Enabled", true)
                else
                    stop()
                    notify("BaitAttack", "Disabled", true)
                end
            end,
            'BaitAttackEnabled'
        })
        local keybinds = {
            { Name = "Fake Parry Key", State = "FakeParryKey", Id = "FakeParryKeyBA" },
            { Name = "Fake Riposte Key", State = "FakeRiposteKey", Id = "FakeRiposteKeyBA" },
            { Name = "Fake Attack Key", State = "FakeAttackKey", Id = "FakeAttackKeyBA" }
        }
        for _, kb in ipairs(keybinds) do
            section:Keybind({
                Name = kb.Name,
                Default = State.BaitAttack[kb.State].Default,
                Callback = function(value)
                    State.BaitAttack[kb.State].Value = value
                    updateKeybindDisplays()
                end,
                kb.Id
            })
        end
        section:Divider()
        section:Toggle({
            Name = "Check Stance",
            Default = State.BaitAttack.CheckStance.Default,
            Callback = function(value)
                State.BaitAttack.CheckStance.Value = value
                notify("BaitAttack", "Check Stance: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'CheckStanceBA'
        })
        section:SubLabel({ Text = "Prevents bait animations if player's Stance is not Idle or Recovery" })
        section:Divider()
        section:SubLabel({ Text = "Parry" })
        section:Toggle({
            Name = "Hold",
            Default = State.BaitAttack.ParryHold.Default,
            Callback = function(value)
                State.BaitAttack.ParryHold.Value = value
                notify("BaitAttack", "Parry Hold: " .. (value and "Enabled" or "Disabled"), true)
                if not value and parryAnimationTrack and parryAnimationTrack.IsPlaying then
                    parryAnimationTrack:Stop(0.2)
                    parryAnimationTrack:Destroy()
                    parryAnimationTrack = nil
                    if localHumanoid then
                        localHumanoid.WalkSpeed = defaultWalkSpeed
                    end
                    isPerformingAction = false
                    State.BaitAttack.FakeParry.Value = false
                    Core.BulwarkTarget.CombatState = nil
                end
            end,
            'ParryHoldBA'
        })
        section:Toggle({
            Name = "Auto Hold",
            Default = State.BaitAttack.AutoHoldEnabled.Default,
            Callback = function(value)
                State.BaitAttack.AutoHoldEnabled.Value = value
                notify("BaitAttack", "Auto Hold: " .. (value and "Enabled" or "Disabled"), true)
                if not value and parryAnimationTrack and parryAnimationTrack.IsPlaying and not State.BaitAttack.ParryHold.Value then
                    parryAnimationTrack:Stop(0.2)
                    parryAnimationTrack:Destroy()
                    parryAnimationTrack = nil
                    if localHumanoid then
                        localHumanoid.WalkSpeed = defaultWalkSpeed
                    end
                    isPerformingAction = false
                    State.BaitAttack.FakeParry.Value = false
                    Core.BulwarkTarget.CombatState = nil
                end
            end,
            'AutoHoldEnabledBA'
        })
        section:Slider({
            Name = "Auto Hold Duration",
            Minimum = 2,
            Maximum = 10,
            Default = State.BaitAttack.ParryAutoHold.Default,
            Precision = 1,
            Callback = function(value)
                State.BaitAttack.ParryAutoHold.Value = value
                notify("BaitAttack", "Parry Auto Hold set to: " .. value .. " seconds", false)
            end,
            'ParryAutoHoldBA'
        })
        section:Divider()
        section:SubLabel({ Text = "Force Stop" })
        section:Toggle({
            Name = "Enabled",
            Default = State.BaitAttack.ForceStopEnabled.Default,
            Callback = function(value)
                State.BaitAttack.ForceStopEnabled.Value = value
                notify("BaitAttack", "Force Stop: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'ForceStopEnabledBA'
        })
        section:Keybind({
            Name = "Force Stop Key",
            Default = State.BaitAttack.ForceStopKey.Default,
            Callback = function(value)
                State.BaitAttack.ForceStopKey.Value = value
                updateKeybindDisplays()
            end,
            'ForceStopKeyBA'
        })
        section:SubLabel({ Text = "Sets Stance to Idle without stopping animations" })

        local keybindSection = UI.Tabs.Visuals:Section({ Name = "BaitAttackKeybinds", Side = "Right" })
        UI.Sections.BaitAttackKeybinds = keybindSection
        keybindSection:Header({ Name = "BaitAttack KeyBind" })
        keybindSection:SubLabel({ Text = "Displays keybinds for BaitAttack actions on screen" })
        keybindSection:Toggle({
            Name = "Enabled",
            Default = State.BaitAttack.KeybindDisplayEnabled.Default,
            Callback = function(value)
                State.BaitAttack.KeybindDisplayEnabled.Value = value
                updateKeybindDisplays()
                notify("BaitAttack", "Keybind Displays " .. (value and "Enabled" or "Disabled"), true)
            end,
            'KeybindDisplayEnabledBA'
        })
        keybindSection:Slider({
            Name = "Scale",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = State.BaitAttack.KeybindDisplayScale.Default,
            Precision = 1,
            Callback = function(value)
                State.BaitAttack.KeybindDisplayScale.Value = value
                updateKeybindDisplays()
                notify("BaitAttack", "Keybind Display Scale set to: " .. value, false)
            end,
            'KeybindDisplayScaleBA'
        })
        keybindSection:Divider()
        local displayToggles = {
            { Name = "Parry", State = "ParryDisplayEnabled", Id = "ParryDisplayEnabledBA" },
            { Name = "Riposte", State = "RiposteDisplayEnabled", Id = "RiposteDisplayEnabledBA" },
            { Name = "Attack", State = "AttackDisplayEnabled", Id = "AttackDisplayEnabledBA" },
            { Name = "ForceStop", State = "ForceStopDisplayEnabled", Id = "ForceStopDisplayEnabledBA" }
        }
        for _, toggle in ipairs(displayToggles) do
            keybindSection:Toggle({
                Name = toggle.Name,
                Default = State.BaitAttack[toggle.State].Default,
                Callback = function(value)
                    State.BaitAttack[toggle.State].Value = value
                    updateKeybindDisplays()
                    notify("BaitAttack", toggle.Name .. " Keybind Display: " .. (value and "Enabled" or "Disabled"), true)
                end,
                toggle.Id
            })
        end

        updateKeybindDisplays()
    end

    return BaitAttack
end

return BaitAttack