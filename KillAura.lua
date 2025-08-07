local KillAura = {}
print('1')

function KillAura.Init(UI, Core, notify)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local ContextActionService = game:GetService("ContextActionService")
    local Animation = game:GetService("Animation")
    local UserInputService = game:GetService("UserInputService")
    local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ToServer")
    local ChangeStance = RemoteEvents:WaitForChild("ChangeStance")
    local Hit = RemoteEvents:WaitForChild("Hit")
    local Kick = RemoteEvents:WaitForChild("Kick")
    local Punch = RemoteEvents:WaitForChild("Punch")

    local LocalPlayer = Players.LocalPlayer
    local ClientModule = require(ReplicatedStorage:WaitForChild("ClientModule"))

    local State = {
        KillAura = {
            Enabled = { Value = false, Default = false },
            Range = { Value = 10, Default = 10 },
            AttackCooldown = { Value = 0.24, Default = 0.24 },
            AntiBlock = { Value = true, Default = true },
            AntiParry = { Value = true, Default = true },
            MultiTarget = { Value = false, Default = false },
            MultiAntiCounter = { Value = false, Default = false },
            HighlightBlock = { Value = true, Default = true },
            HighlightParry = { Value = true, Default = true },
            TeamCheck = { Value = true, Default = true },
            DynamicCooldown = { Value = false, Default = false },
            DynamicDelays = { Value = {0.05, 0.1, 0.15, 0.2}, Default = {0.05, 0.1, 0.15, 0.2} },
            MultiTargetDelays = { Value = {0.15, 0.2, 0.25, 0.3}, Default = {0.15, 0.2, 0.25, 0.3} },
            ParryColor = { Value = Color3.fromRGB(0, 162, 255), Default = Color3.fromRGB(0, 162, 255) },
            BlockColor = { Value = Color3.fromRGB(0, 255, 0), Default = Color3.fromRGB(0, 255, 0) },
            DefaultColor = { Value = Color3.fromRGB(255, 0, 0), Default = Color3.fromRGB(255, 0, 0) },
            MinusWindup = { Value = 0.9, Default = 0.9 },
            MinusRelease = { Value = 1.4, Default = 1.4 },
            KickDelay = { Value = 0.01, Default = 0.01 },
            KickStateDelay = { Value = 0, Default = 0 }
        },
        AutoDodge = {
            Enabled = { Value = false, Default = false },
            Range = { Value = 10, Default = 10 },
            PreRange = { Value = 20, Default = 20 },
            DodgeCooldown = { Value = 0.15, Default = 0.15 }, -- Уменьшено для более быстрого реагирования
            TeamCheck = { Value = true, Default = true },
            KillAuraSync = { Value = false, Default = false },
            IdleSpoof = { Value = false, Default = false },
            UseClientIdle = { Value = false, Default = false },
            BlockingMode = { Value = "Chance", Default = "Chance" },
            ParryingChance = { Value = 50, Default = 50 },
            RiposteChance = { Value = 50, Default = 50 },
            MissChance = { Value = 0, Default = 0 },
            LegitBlock = { Value = true, Default = true },
            LegitParry = { Value = true, Default = true },
            BaseMultiplier = { Value = 0.1, Default = 0.1 }, -- Уменьшено для ускорения реакции
            DistanceFactor = { Value = 0.02, Default = 0.02 }, -- Уменьшено для более точной реакции
            Delay = { Value = 0.01, Default = 0.01 }, -- Уменьшено для минимальной задержки
            Blocking = { Value = true, Default = true },
            BlockingAntiStun = { Value = true, Default = true },
            RiposteMouseLockDuration = { Value = 1.2, Default = 1.2 }, -- Уменьшено для сокращения времени блокировки
            MaxWaitTime = { Value = 1.5, Default = 1.5 }, -- Уменьшено для более быстрого цикла
            PredictionTime = { Value = 0.05, Default = 0.05 }, -- Уменьшено для быстрого предсказания
            ResolveAngle = { Value = true, Default = true }, -- Включено по умолчанию для улучшенного анализа
            AngleDelay = { Value = 0.05, Default = 0.05 } -- Уменьшено для более быстрого анализа углов
        }
    }

    local targetHighlights = {}
    local currentTarget = nil
    local cachedSettings = nil
    local lastWeapon = nil
    local lastAttackTime = 0
    local localCharacter = nil
    local localRootPart = nil
    local localHumanoid = nil
    local lastNotificationTime = 0
    local notificationDelay = 5
    local lastDodgeTime = 0
    local closestTarget = nil
    local lastStance = nil
    local lastTargetWeapon = nil
    local lastReleaseTime = nil
    local isPerformingAction = false
    local isRiposteActive = false
    local riposteEndTime = 0
    local isDodgePending = false
    local desiredDodgeAction = nil

    local INVALID_STANCES = {"windup", "release", "parrying", "unparry", "punching", "kickwindup", "kicking", "flinch", "recovery"}
    local VALID_HUMANOID_STATES = {Enum.HumanoidStateType.Running, Enum.HumanoidStateType.None}
    local LATENCY_BUFFER = 0.02 -- Уменьшено для более быстрого реагирования
    local PREDICTION_THRESHOLD = 0.3 -- Уменьшено для более точного предсказания
    local MAX_ADDITIONAL_TARGETS = 5
    local ANGLE_THRESHOLD = 45 -- Порог угла для определения байта (в градусах)

    local function getPlayerStance(player)
        if not player or not player.Character then
            return nil
        end
        local character = player.Character
        local stanceValue = character:FindFirstChild("Stance", true)
        if stanceValue and stanceValue:IsA("StringValue") then
            return stanceValue.Value:lower()
        end
        return nil
    end

    local function getTargetWeaponSettings(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then
            return nil, nil
        end
        local character = targetPlayer.Character
        local weapon
        for _, child in pairs(character:GetChildren()) do
            if child:IsA("Tool") then
                weapon = child
                break
            end
        end
        if not weapon then
            return nil, nil
        end
        local settingsModule = weapon:FindFirstChild("Settings")
        if not settingsModule then
            return nil, nil
        end
        local settings = require(settingsModule)
        if not settings or type(settings) ~= "table" or not settings.Release or type(settings.Release) ~= "number" or settings.Release <= 0 then
            return nil, nil
        end
        return weapon, settings
    end

    local function getWeaponSettings()
        if not localCharacter then
            return nil
        end
        local weapon
        for _, child in pairs(localCharacter:GetChildren()) do
            if child:IsA("Tool") then
                weapon = child
                break
            end
        end
        if not weapon then
            cachedSettings = nil
            lastWeapon = nil
            return nil
        end
        if weapon == lastWeapon and cachedSettings then
            return cachedSettings
        end
        local settingsModule = weapon:FindFirstChild("Settings")
        if not settingsModule then
            cachedSettings = nil
            lastWeapon = nil
            return nil
        end
        local success, settings = pcall(require, settingsModule)
        if not success or not settings or not settings.Windup or not settings.Release then
            cachedSettings = nil
            lastWeapon = nil
            return nil
        end
        if State.KillAura.Enabled.Value then
            settings.Windup = math.max(0, settings.Windup - State.KillAura.MinusWindup.Value)
            settings.Release = math.max(0, settings.Release - State.KillAura.MinusRelease.Value)
        end
        cachedSettings = {
            weapon = weapon,
            windupTime = settings.Windup,
            releaseTime = settings.Release,
            Type = settings.Type or "Unknown"
        }
        lastWeapon = weapon
        return cachedSettings
    end

    local function getLocalWeaponSettings()
        if not localCharacter then
            return nil, nil
        end
        local weapon
        for _, child in pairs(localCharacter:GetChildren()) do
            if child:IsA("Tool") then
                weapon = child
                break
            end
        end
        if not weapon then
            return nil, nil
        end
        local settingsModule = weapon:FindFirstChild("Settings")
        if not settingsModule then
            return nil, nil
        end
        local settings = require(settingsModule)
        if not settings or type(settings) ~= "table" or not settings.Type then
            return nil, nil
        end
        return settings, weapon
    end

    local function getDistanceToPlayer(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then
            return math.huge
        end
        local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRootPart and localRootPart then
            local distance = (localRootPart.Position - targetRootPart.Position).Magnitude
            if distance == math.huge or distance ~= distance then
                return math.huge
            end
            return distance
        end
        return math.huge
    end

    local function getDmgPointDistance(targetPlayer, weapon)
        if not (weapon and targetPlayer and targetPlayer.Character and localRootPart and localRootPart.Position) then
            return math.huge
        end
        local blade = weapon:FindFirstChild("Blade")
        if not blade or not blade:IsA("MeshPart") then
            return math.huge
        end
        local dmgPoint = blade:FindFirstChild("DmgPoint")
        if not dmgPoint or not dmgPoint:IsA("Attachment") then
            return math.huge
        end
        local distance = (localRootPart.Position - dmgPoint.WorldPosition).Magnitude
        if distance == math.huge or distance ~= distance then
            return math.huge
        end
        return distance
    end

    local function canTargetPlayer(targetPlayer, range, teamCheck)
        if not (localCharacter and localRootPart and localHumanoid and localHumanoid.Health > 0 and targetPlayer and targetPlayer.Character) then
            return false
        end
        local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
        if not (targetRootPart and targetHumanoid) or targetHumanoid.Health <= 0 or targetHumanoid:GetState() ~= Enum.HumanoidStateType.Running then
            return false
        end
        local distance = (localRootPart.Position - targetRootPart.Position).Magnitude
        if distance > range or distance == math.huge or distance ~= distance then
            return false
        end
        if teamCheck and targetPlayer.Team and LocalPlayer.Team then
            local localTeamName = LocalPlayer.Team.Name
            local targetTeamName = targetPlayer.Team.Name
            if localTeamName == targetTeamName and localTeamName ~= "Spectators" then
                return false
            elseif localTeamName == "Spectators" then
                return true
            elseif localTeamName == "Guesmand" then
                return targetTeamName == "Spectators" or targetTeamName == "Sunderland"
            elseif localTeamName == "Sunderland" then
                return targetTeamName == "Guesmand" or targetTeamName == "Spectators"
            end
            return false
        end
        return true
    end

    local function isBaitAttack(targetPlayer, weapon)
        if not (State.AutoDodge.ResolveAngle.Value and weapon and targetPlayer and targetPlayer.Character and localRootPart) then
            return false
        end
        local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRootPart then
            return false
        end
        local blade = weapon:FindFirstChild("Blade")
        if not blade or not blade:IsA("MeshPart") then
            return false
        end
        local dmgPoint = blade:FindFirstChild("DmgPoint")
        if not dmgPoint or not dmgPoint:IsA("Attachment") then
            return false
        end
        local directionToPlayer = (localRootPart.Position - dmgPoint.WorldPosition).Unit
        local targetLookDirection = targetRootPart.CFrame.LookVector
        local angle = math.deg(math.acos(directionToPlayer:Dot(targetLookDirection)))
        return angle > ANGLE_THRESHOLD -- Если угол больше порога, это байт
    end

    local function checkDamagePointCollision(targetPlayer, weapon)
        if not (State.AutoDodge.ResolveAngle.Value and weapon and targetPlayer and targetPlayer.Character and localCharacter) then
            return false
        end
        local blade = weapon:FindFirstChild("Blade")
        if not blade or not blade:IsA("MeshPart") then
            return false
        end
        local damagePoints = {}
        for _, part in pairs(blade:GetChildren()) do
            if part.Name == "DmgPoint" and part:IsA("Attachment") then
                table.insert(damagePoints, part)
            end
        end
        if #damagePoints == 0 then
            return false
        end
        local hitboxes = {
            localCharacter:FindFirstChild("Head"),
            localCharacter:FindFirstChild("Torso"),
            localCharacter:FindFirstChild("Left Arm"),
            localCharacter:FindFirstChild("Right Arm"),
            localCharacter:FindFirstChild("Left Leg"),
            localCharacter:FindFirstChild("Right Leg")
        }
        for _, damagePoint in pairs(damagePoints) do
            for _, hitbox in pairs(hitboxes) do
                if hitbox and hitbox:IsA("BasePart") then
                    local distance = (damagePoint.WorldPosition - hitbox.Position).Magnitude
                    local hitboxSize = hitbox.Size.Magnitude / 2
                    if distance <= hitboxSize + PREDICTION_THRESHOLD then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function predictAttack(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then
            return false, 0
        end
        local weapon, settings = getTargetWeaponSettings(targetPlayer)
        if not (weapon and settings and settings.Release) then
            return false, 0
        end
        local stance = getPlayerStance(targetPlayer)
        if stance ~= "release" then
            return false, 0
        end
        if isBaitAttack(targetPlayer, weapon) then
            return false, 0 -- Игнорируем байт-атаки
        end
        local releaseTime = math.max(0.05, settings.Release - 0.05) -- Уменьшено минимальное время
        if State.AutoDodge.ResolveAngle.Value then
            if checkDamagePointCollision(targetPlayer, weapon) then
                return true, math.max(0, releaseTime - LATENCY_BUFFER - State.AutoDodge.PredictionTime.Value)
            else
                local distance = getDmgPointDistance(targetPlayer, weapon)
                if distance <= State.AutoDodge.Range.Value then
                    return true, releaseTime * (State.AutoDodge.BaseMultiplier.Value + distance * State.AutoDodge.DistanceFactor.Value) - LATENCY_BUFFER
                end
            end
        else
            local distance = getDmgPointDistance(targetPlayer, weapon)
            if distance <= State.AutoDodge.Range.Value then
                return true, releaseTime * (State.AutoDodge.BaseMultiplier.Value + distance * State.AutoDodge.DistanceFactor.Value) - LATENCY_BUFFER
            end
        end
        return false, 0
    end

    local function performDodgeAction(action, waitTime)
        if isPerformingAction or tick() - lastDodgeTime < State.AutoDodge.DodgeCooldown.Value then
            isDodgePending = false
            desiredDodgeAction = nil
            Core.BulwarkTarget.CombatState = nil
            return false
        end
        isPerformingAction = true
        isDodgePending = true
        desiredDodgeAction = action
        if not (localHumanoid and localHumanoid.Health > 0) then
            isPerformingAction = false
            isDodgePending = false
            desiredDodgeAction = nil
            Core.BulwarkTarget.CombatState = nil
            return false
        end
        if not table.find(VALID_HUMANOID_STATES, localHumanoid:GetState()) then
            isPerformingAction = false
            isDodgePending = false
            desiredDodgeAction = nil
            Core.BulwarkTarget.CombatState = nil
            return false
        end
        local localWeapon
        for _, child in pairs(localCharacter:GetChildren()) do
            if child:IsA("Tool") then
                localWeapon = child
                break
            end
        end
        if not localWeapon then
            isPerformingAction = false
            isDodgePending = false
            desiredDodgeAction = nil
            Core.BulwarkTarget.CombatState = nil
            return false
        end
        local localStance = getPlayerStance(LocalPlayer)
        if localStance and table.find(INVALID_STANCES, localStance) and not State.AutoDodge.IdleSpoof.Value then
            isPerformingAction = false
            isDodgePending = false
            desiredDodgeAction = nil
            Core.BulwarkTarget.CombatState = nil
            return false
        end
        waitTime = math.min(waitTime, State.AutoDodge.MaxWaitTime.Value)
        if waitTime == math.huge or waitTime ~= waitTime then
            waitTime = 0.2
        end
        waitTime = waitTime + State.AutoDodge.PredictionTime.Value

        local animationTrack
        local settings, weapon = getLocalWeaponSettings()
        if settings then
            local animationsModule = ReplicatedStorage:FindFirstChild("ClientModule") and ReplicatedStorage.ClientModule:FindFirstChild("WeaponAnimations")
            local animations = animationsModule and require(animationsModule)[settings.Type]
            if action == "Parrying" and State.AutoDodge.LegitBlock.Value and animations and animations.Parry then
                local animation = Instance.new("Animation")
                animation.AnimationId = "rbxassetid://" .. animations.Parry
                animationTrack = localHumanoid:LoadAnimation(animation)
                animationTrack:Play(0.05) -- Ускорен запуск анимации
                animationTrack:AdjustSpeed(1.2) -- Ускорена анимация
                localHumanoid.WalkSpeed = 7
            elseif action == "Riposte" and State.AutoDodge.LegitParry.Value and animations and animations.Riposte then
                ChangeStance:FireServer("Riposte")
                local animation = Instance.new("Animation")
                animation.AnimationId = "rbxassetid://" .. animations.Riposte
                animationTrack = localHumanoid:LoadAnimation(animation)
                animationTrack:Play(0.05) -- Ускорен запуск
                animationTrack:AdjustSpeed(0)
                localHumanoid.WalkSpeed = 1
                isRiposteActive = true
                riposteEndTime = tick() + waitTime + State.AutoDodge.RiposteMouseLockDuration.Value
                task.spawn(function()
                    task.wait(0.3) -- Уменьшено время ожидания
                    if animationTrack and animationTrack.IsPlaying and animationTrack.TimePosition == 0 then
                        animationTrack:Stop(0.5) -- Ускорен останов
                    end
                end)
            end
        end

        if action ~= "Riposte" then
            ChangeStance:FireServer(action)
        end
        task.wait(waitTime)
        if State.AutoDodge.IdleSpoof.Value then
            local currentStance = getPlayerStance(LocalPlayer)
            if currentStance and table.find(INVALID_STANCES, currentStance) then
                ChangeStance:FireServer("Idle")
                if State.AutoDodge.UseClientIdle.Value and settings and settings.Type then
                    local animationsModule = ReplicatedStorage:FindFirstChild("ClientModule") and ReplicatedStorage.ClientModule:FindFirstChild("WeaponAnimations")
                    local animations = animationsModule and require(animationsModule)[settings.Type]
                    if animations and animations.Idle then
                        local idleAnimation = Instance.new("Animation")
                        idleAnimation.AnimationId = "rbxassetid://" .. animations.Idle
                        local idleAnimTrack = localHumanoid:LoadAnimation(idleAnimation)
                        idleAnimTrack:Play(0.05)
                        idleAnimTrack:AdjustSpeed(1)
                        task.spawn(function()
                            task.wait(0.3)
                            if idleAnimTrack and idleAnimTrack.IsPlaying then
                                idleAnimTrack:Stop(0.1)
                                idleAnimTrack:Destroy()
                            end
                        end)
                    end
                end
                task.wait(0.03) -- Уменьшена задержка
                if desiredDodgeAction and not isPerformingAction then
                    ChangeStance:FireServer(desiredDodgeAction)
                end
            end
        end
        if action == "Riposte" then
            ChangeStance:FireServer("RiposteDelay")
            task.wait(0.5) -- Уменьшено время ожидания
        else
            ChangeStance:FireServer("UnParry")
            task.wait(0.005) -- Минимизирована задержка
        end

        if animationTrack then
            animationTrack:Stop(action == "Parrying" and 0.1 or 0.5) -- Ускорен останов анимации
            animationTrack:Destroy()
        end
        localHumanoid.WalkSpeed = 9

        ChangeStance:FireServer("Idle")
        if action == "Riposte" then
            task.wait(State.AutoDodge.RiposteMouseLockDuration.Value)
            isRiposteActive = false
        end
        lastDodgeTime = tick()
        isPerformingAction = false
        isDodgePending = false
        desiredDodgeAction = nil
        Core.BulwarkTarget.CombatState = nil
        return true
    end

    local function updateTargetHighlight(targets)
        for player, highlight in pairs(targetHighlights) do
            if not table.find(targets, player) or not player.Character then
                highlight:Destroy()
                targetHighlights[player] = nil
            end
        end
        for _, player in pairs(targets) do
            if not player.Character then
                continue
            end
            local highlight = targetHighlights[player]
            if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = "TargetHighlight"
                highlight.Parent = player.Character
                highlight.Adornee = player.Character
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                targetHighlights[player] = highlight
            end
            local stance = getPlayerStance(player)
            if stance and (stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.HighlightBlock.Value then
                highlight.FillColor = State.KillAura.BlockColor.Value
                highlight.Enabled = true
            elseif stance and stance == "riposte" and State.KillAura.HighlightParry.Value then
                highlight.FillColor = State.KillAura.ParryColor.Value
                highlight.Enabled = true
            else
                highlight.FillColor = State.KillAura.DefaultColor.Value
                highlight.Enabled = true
            end
        end
        if #targets > 0 then
            Core.BulwarkTarget.CurrentTarget = targets[1].Name
            Core.BulwarkTarget.KillAuraTarget = targets[1].Name
        else
            Core.BulwarkTarget.CurrentTarget = nil
            Core.BulwarkTarget.KillAuraTarget = nil
        end
    end

    local function removeTargetHighlights()
        for _, highlight in pairs(targetHighlights) do
            highlight:Destroy()
        end
        targetHighlights = {}
        currentTarget = nil
        Core.BulwarkTarget.CurrentTarget = nil
        Core.BulwarkTarget.KillAuraTarget = nil
    end

    local function blockMouseButton1()
        ContextActionService:BindActionAtPriority("BlockMouseButton1", function()
            return Enum.ContextActionResult.Sink
        end, false, Enum.ContextActionPriority.High.Value, Enum.UserInputType.MouseButton1)
        task.spawn(function()
            while isRiposteActive and tick() <= riposteEndTime do
                task.wait()
            end
            isRiposteActive = false
            ContextActionService:UnbindAction("BlockMouseButton1")
        end)
    end

    local function performPunch(targetPlayer, targetCharacter, weapon)
        local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
        if not targetHumanoid then
            return false
        end
        local stance = getPlayerStance(targetPlayer)
        if not stance or not ((stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value) then
            return false
        end
        Core.BulwarkTarget.CombatState = "KillAura (Punch)"
        Core.BulwarkTarget.KillAuraTarget = targetPlayer.Name
        ChangeStance:FireServer("Punching")
        task.wait(State.KillAura.KickDelay.Value)
        if not targetCharacter or not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        stance = getPlayerStance(targetPlayer)
        if not stance or not ((stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value) then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        local targetHandle = targetCharacter:FindFirstChild("HumanoidRootPart")
        if not (weapon and targetHandle) then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        Punch:FireServer(weapon, targetHandle, targetHumanoid)
        Core.BulwarkTarget.CombatState = nil
        Core.BulwarkTarget.KillAuraTarget = nil
        return true
    end

    local function performKick(targetPlayer, targetCharacter, weapon)
        local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
        if not targetHumanoid then
            return false
        end
        local stance = getPlayerStance(targetPlayer)
        if not stance or stance ~= "riposte" or not State.KillAura.AntiParry.Value then
            return false
        end
        Core.BulwarkTarget.CombatState = "KillAura (Kick)"
        Core.BulwarkTarget.KillAuraTarget = targetPlayer.Name
        ChangeStance:FireServer("KickWindup")
        task.wait(State.KillAura.KickDelay.Value)
        if not targetCharacter or not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        stance = getPlayerStance(targetPlayer)
        if not stance or stance ~= "riposte" or not State.KillAura.AntiParry.Value then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        ChangeStance:FireServer("Kicking")
        task.wait(State.KillAura.KickStateDelay.Value)
        if not targetCharacter or not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        stance = getPlayerStance(targetPlayer)
        if not stance or stance ~= "riposte" or not State.KillAura.AntiParry.Value then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        local targetHandle = targetCharacter:FindFirstChild("CollisionBubble") or targetCharacter:FindFirstChild("HumanoidRootPart")
        if not targetHandle then
            Core.BulwarkTarget.CombatState = nil
            Core.BulwarkTarget.KillAuraTarget = nil
            return false
        end
        Kick:FireServer(weapon, targetHandle, targetHumanoid)
        Core.BulwarkTarget.CombatState = nil
        Core.BulwarkTarget.KillAuraTarget = nil
        return true
    end

    local function getAdditionalTargets(mainTarget)
        local additionalTargets = {}
        local count = 0
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player ~= mainTarget and canTargetPlayer(player, State.KillAura.Range.Value, State.KillAura.TeamCheck.Value) then
                local targetCharacter = player.Character
                local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
                if targetCharacter and targetHumanoid and targetHumanoid.Health > 0 then
                    local stance = getPlayerStance(player)
                    if not (stance and ((stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value or (stance == "riposte" and State.KillAura.AntiParry.Value))) then
                        table.insert(additionalTargets, player)
                        count = count + 1
                        if count >= MAX_ADDITIONAL_TARGETS then
                            break
                        end
                    end
                end
            end
        end
        return additionalTargets
    end

    local function getAntiCounterTargets(action)
        local targets = {}
        local count = 0
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and canTargetPlayer(player, State.KillAura.Range.Value, State.KillAura.TeamCheck.Value) then
                local targetCharacter = player.Character
                local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
                if targetCharacter and targetHumanoid and targetHumanoid.Health > 0 then
                    local stance = getPlayerStance(player)
                    if (action == "Punch" and stance and (stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value) or
                       (action == "Kick" and stance == "riposte" and State.KillAura.AntiParry.Value) then
                        table.insert(targets, player)
                        count = count + 1
                        if count >= MAX_ADDITIONAL_TARGETS then
                            break
                        end
                    end
                end
            end
        end
        return targets
    end

    local function collectDodgeData()
        while true do
            task.wait(State.AutoDodge.Delay.Value)
            localCharacter = LocalPlayer.Character
            localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
            localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")
            if not (localCharacter and localRootPart and localHumanoid and localHumanoid.Health > 0) then
                closestTarget = nil
                lastStance = nil
                lastTargetWeapon = nil
                lastReleaseTime = nil
                Core.BulwarkTarget.UniversalTarget = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
                continue
            end
            closestTarget = nil
            local minDistance = math.huge
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and canTargetPlayer(player, State.AutoDodge.PreRange.Value, State.AutoDodge.TeamCheck.Value) then
                    local distance = getDistanceToPlayer(player)
                    if distance < minDistance then
                        minDistance = distance
                        closestTarget = player
                    end
                end
            end
            if closestTarget then
                Core.BulwarkTarget.UniversalTarget = closestTarget.Name
                Core.BulwarkTarget.AutoDodgeTarget = closestTarget.Name
                local weapon, settings = getTargetWeaponSettings(closestTarget)
                if weapon and settings and settings.Release then
                    lastTargetWeapon = weapon
                    lastReleaseTime = math.max(0.05, settings.Release - 0.05)
                else
                    lastTargetWeapon = nil
                    lastReleaseTime = nil
                end
            else
                lastTargetWeapon = nil
                lastReleaseTime = nil
                Core.BulwarkTarget.UniversalTarget = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
            end
        end
    end

    local function runAutoDodge()
        while true do
            task.wait(State.AutoDodge.Delay.Value)
            if not State.AutoDodge.Enabled.Value then
                Core.BulwarkTarget.isAutoDodge = false
                isDodgePending = false
                desiredDodgeAction = nil
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
                continue
            end
            Core.BulwarkTarget.isAutoDodge = true
            if not (localCharacter and localRootPart and localHumanoid and localHumanoid.Health > 0) then
                isDodgePending = false
                desiredDodgeAction = nil
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
                continue
            end
            if tick() - lastDodgeTime < State.AutoDodge.DodgeCooldown.Value then
                isDodgePending = false
                desiredDodgeAction = nil
                continue
            end
            if not closestTarget or not closestTarget.Character or not canTargetPlayer(closestTarget, State.AutoDodge.Range.Value, State.AutoDodge.TeamCheck.Value) then
                lastStance = nil
                isDodgePending = false
                desiredDodgeAction = nil
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
                continue
            end
            local targetCharacter = closestTarget.Character
            local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
            if not (targetCharacter and targetHumanoid and targetHumanoid.Health > 0) then
                lastStance = nil
                isDodgePending = false
                desiredDodgeAction = nil
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
                continue
            end
            local willHit, waitTime = predictAttack(closestTarget)
            if willHit then
                local totalChance = State.AutoDodge.ParryingChance.Value + State.AutoDodge.RiposteChance.Value
                local normalizedParryChance = totalChance > 0 and (State.AutoDodge.ParryingChance.Value / totalChance) or 0.5
                local rand = math.random()
                local action
                if rand < State.AutoDodge.MissChance.Value then
                    lastStance = getPlayerStance(closestTarget)
                    isDodgePending = false
                    desiredDodgeAction = nil
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.AutoDodgeTarget = nil
                    continue
                elseif State.AutoDodge.BlockingMode.Value == "Riposte" then
                    action = "Riposte"
                elseif State.AutoDodge.BlockingMode.Value == "Parrying" then
                    action = "Parrying"
                elseif State.AutoDodge.BlockingMode.Value == "Chance" then
                    action = rand < normalizedParryChance * (1 - State.AutoDodge.MissChance.Value) and "Parrying" or "Riposte"
                end
                if State.AutoDodge.IdleSpoof.Value then
                    local currentStance = getPlayerStance(LocalPlayer)
                    if currentStance and table.find(INVALID_STANCES, currentStance) then
                        ChangeStance:FireServer("Idle")
                        if State.AutoDodge.UseClientIdle.Value then
                            local settings, weapon = getLocalWeaponSettings()
                            if settings and settings.Type then
                                local animationsModule = ReplicatedStorage:FindFirstChild("ClientModule") and ReplicatedStorage.ClientModule:FindFirstChild("WeaponAnimations")
                                local animations = animationsModule and require(animationsModule)[settings.Type]
                                if animations and animations.Idle then
                                    local idleAnimation = Instance.new("Animation")
                                    idleAnimation.AnimationId = "rbxassetid://" .. animations.Idle
                                    local idleAnimTrack = localHumanoid:LoadAnimation(idleAnimation)
                                    idleAnimTrack:Play(0.05)
                                    idleAnimTrack:AdjustSpeed(1)
                                    task.spawn(function()
                                        task.wait(0.3)
                                        if idleAnimTrack and idleAnimTrack.IsPlaying then
                                            idleAnimTrack:Stop(0.1)
                                            idleAnimTrack:Destroy()
                                        end
                                    end)
                                end
                            end
                        end
                        task.wait(0.03)
                    end
                end
                if performDodgeAction(action, waitTime) then
                    lastDodgeTime = tick()
                    lastStance = getPlayerStance(closestTarget)
                end
            elseif getPlayerStance(closestTarget) == "punching" and State.AutoDodge.Blocking.Value and State.AutoDodge.BlockingAntiStun.Value then
                Core.BulwarkTarget.CombatState = "AutoDodge (AntiStun)"
                ChangeStance:FireServer("UnParry")
                task.wait(0.005)
                ChangeStance:FireServer("Idle")
                if State.AutoDodge.UseClientIdle.Value then
                    local settings, weapon = getLocalWeaponSettings()
                    if settings and settings.Type then
                        local animationsModule = ReplicatedStorage:FindFirstChild("ClientModule") and ReplicatedStorage.ClientModule:FindFirstChild("WeaponAnimations")
                        local animations = animationsModule and require(animationsModule)[settings.Type]
                        if animations and animations.Idle then
                            local idleAnimation = Instance.new("Animation")
                            idleAnimation.AnimationId = "rbxassetid://" .. animations.Idle
                            local idleAnimTrack = localHumanoid:LoadAnimation(idleAnimation)
                            idleAnimTrack:Play(0.05)
                            idleAnimTrack:AdjustSpeed(1)
                            task.spawn(function()
                                task.wait(0.3)
                                if idleAnimTrack and idleAnimTrack.IsPlaying then
                                    idleAnimTrack:Stop(0.1)
                                    idleAnimTrack:Destroy()
                                end
                            end)
                        end
                    end
                end
                localHumanoid.WalkSpeed = 9
                lastDodgeTime = tick()
                isDodgePending = false
                desiredDodgeAction = nil
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.AutoDodgeTarget = nil
            else
                lastStance = getPlayerStance(closestTarget)
            end
        end
    end

    local function runKillAura()
        task.spawn(collectDodgeData)
        task.spawn(runAutoDodge)
        while true do
            RunService.Heartbeat:Wait()
            if not State.KillAura.Enabled.Value then
                Core.BulwarkTarget.isKillAura = false
                removeTargetHighlights()
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
                continue
            end
            Core.BulwarkTarget.isKillAura = true
            localCharacter = LocalPlayer.Character
            localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
            localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")
            if not (localCharacter and localRootPart and localHumanoid) then
                removeTargetHighlights()
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
                continue
            end
            local settings = getWeaponSettings()
            if not settings or not settings.weapon then
                removeTargetHighlights()
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
                continue
            end
            if tick() - lastAttackTime < State.KillAura.AttackCooldown.Value then
                continue
            end
            local closestKillAuraTarget = nil
            local minDistance = math.huge
            local allTargets = {}
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and canTargetPlayer(player, State.KillAura.Range.Value, State.KillAura.TeamCheck.Value) then
                    local distance = getDistanceToPlayer(player)
                    table.insert(allTargets, player)
                    if distance < minDistance then
                        minDistance = distance
                        closestKillAuraTarget = player
                    end
                end
            end
            if not closestKillAuraTarget then
                removeTargetHighlights()
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
                continue
            end
            if State.KillAura.MultiTarget.Value then
                updateTargetHighlight(allTargets)
            else
                updateTargetHighlight({closestKillAuraTarget})
            end
            local targetCharacter = closestKillAuraTarget.Character
            local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
            if not (targetCharacter and targetHumanoid) then
                removeTargetHighlights()
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
                continue
            end
            local stance = getPlayerStance(closestKillAuraTarget)
            if State.AutoDodge.KillAuraSync.Value and stance == "release" and State.AutoDodge.Enabled.Value and isDodgePending then
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
                continue
            end
            local attacked = false
            if stance and State.KillAura.MultiAntiCounter.Value then
                if (stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value then
                    local punchTargets = getAntiCounterTargets("Punch")
                    for _, targetPlayer in pairs(punchTargets) do
                        local tCharacter = targetPlayer.Character
                        if tCharacter and tCharacter.Parent and tCharacter:FindFirstChild("Humanoid") then
                            attacked = performPunch(targetPlayer, tCharacter, settings.weapon) or attacked
                        end
                    end
                elseif stance == "riposte" and State.KillAura.AntiParry.Value then
                    local kickTargets = getAntiCounterTargets("Kick")
                    for _, targetPlayer in pairs(kickTargets) do
                        local tCharacter = targetPlayer.Character
                        if tCharacter and tCharacter.Parent and tCharacter:FindFirstChild("Humanoid") then
                            attacked = performKick(targetPlayer, tCharacter, settings.weapon) or attacked
                        end
                    end
                end
            elseif stance then
                if (stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value then
                    attacked = performPunch(closestKillAuraTarget, targetCharacter, settings.weapon)
                elseif stance == "riposte" and State.KillAura.AntiParry.Value then
                    attacked = performKick(closestKillAuraTarget, targetCharacter, settings.weapon)
                end
            end
            if not attacked then
                if State.KillAura.DynamicCooldown.Value then
                    local delays = State.KillAura.DynamicDelays.Value
                    local randomDelay = delays[math.random(1, #delays)]
                    task.wait(randomDelay)
                end
                Core.BulwarkTarget.CombatState = "KillAura (Attack)"
                Core.BulwarkTarget.KillAuraTarget = closestKillAuraTarget.Name
                ChangeStance:FireServer("Windup")
                task.wait(settings.windupTime)
                if not targetCharacter or not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
                    removeTargetHighlights()
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                stance = getPlayerStance(closestKillAuraTarget)
                if State.AutoDodge.KillAuraSync.Value and stance == "release" and State.AutoDodge.Enabled.Value and isDodgePending then
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                if stance and ((stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value or (stance == "riposte" and State.KillAura.AntiParry.Value)) then
                    removeTargetHighlights()
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                ChangeStance:FireServer("Release")
                task.wait(settings.releaseTime)
                if not targetCharacter or not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
                    removeTargetHighlights()
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                stance = getPlayerStance(closestKillAuraTarget)
                if State.AutoDodge.KillAuraSync.Value and stance == "release" and State.AutoDodge.Enabled.Value and isDodgePending then
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                if stance and ((stance == "parrying" or stance == "block" or stance == "blocking") and State.KillAura.AntiBlock.Value or (stance == "riposte" and State.KillAura.AntiParry.Value)) then
                    removeTargetHighlights()
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                local targetHandle = targetCharacter:FindFirstChildOfClass("Accessory") and 
                    targetCharacter:FindFirstChildOfClass("Accessory"):FindFirstChild("Handle") or 
                    targetCharacter:FindFirstChild("HumanoidRootPart")
                if not targetHandle then
                    removeTargetHighlights()
                    Core.BulwarkTarget.CombatState = nil
                    Core.BulwarkTarget.KillAuraTarget = nil
                    continue
                end
                Hit:FireServer(settings.weapon, targetHandle, targetHumanoid)
                if State.KillAura.MultiTarget.Value then
                    local additionalTargets = getAdditionalTargets(closestKillAuraTarget)
                    local multiTargetDelays = State.KillAura.MultiTargetDelays.Value
                    for i, additionalTarget in ipairs(additionalTargets) do
                        local addCharacter = additionalTarget.Character
                        local addHumanoid = addCharacter and addCharacter:FindFirstChild("Humanoid")
                        if addCharacter and addHumanoid and addHumanoid.Health > 0 then
                            local addHandle = addCharacter:FindFirstChildOfClass("Accessory") and 
                                addCharacter:FindFirstChildOfClass("Accessory"):FindFirstChild("Handle") or 
                                addCharacter:FindFirstChild("HumanoidRootPart")
                            if addHandle then
                                local delayIndex = (i - 1) % #multiTargetDelays + 1
                                task.wait(multiTargetDelays[delayIndex])
                                Core.BulwarkTarget.KillAuraTarget = additionalTarget.Name
                                Hit:FireServer(settings.weapon, addHandle, addHumanoid)
                            end
                        end
                    end
                end
                attacked = true
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
            end
            if attacked then
                lastAttackTime = tick()
            else
                removeTargetHighlights()
                Core.BulwarkTarget.CombatState = nil
                Core.BulwarkTarget.KillAuraTarget = nil
            end
        end
    end

    Players.PlayerRemoving:Connect(function(player)
        if targetHighlights[player] then
            targetHighlights[player]:Destroy()
            targetHighlights[player] = nil
        end
        if closestTarget == player then
            closestTarget = nil
            lastStance = nil
            lastTargetWeapon = nil
            lastReleaseTime = nil
            isDodgePending = false
            desiredDodgeAction = nil
            Core.BulwarkTarget.UniversalTarget = nil
            Core.BulwarkTarget.AutoDodgeTarget = nil
        end
    end)

    local function onCharacterAdded(player)
        player.CharacterAdded:Connect(function(character)
            local humanoid = character:WaitForChild("Humanoid", 5)
            if humanoid then
                humanoid.Died:Connect(function()
                    if targetHighlights[player] then
                        targetHighlights[player]:Destroy()
                        targetHighlights[player] = nil
                    end
                    if closestTarget == player then
                        closestTarget = nil
                        lastStance = nil
                        lastTargetWeapon = nil
                        lastReleaseTime = nil
                        isDodgePending = false
                        desiredDodgeAction = nil
                        Core.BulwarkTarget.UniversalTarget = nil
                        Core.BulwarkTarget.AutoDodgeTarget = nil
                    end
                end)
            end
        end)
    end

    for _, player in pairs(Players:GetPlayers()) do
        onCharacterAdded(player)
    end
    Players.PlayerAdded:Connect(onCharacterAdded)

    task.spawn(runKillAura)

    if UI.Tabs and UI.Tabs.Combat then
        UI.Sections.KillAura = UI.Sections.KillAura or UI.Tabs.Combat:Section({ Name = "KillAura", Side = "Left" })
        UI.Sections.KillAura:Header({ Name = "KillAura" })
        UI.Sections.KillAura:Toggle({
            Name = "Enabled",
            Default = State.KillAura.Enabled.Default,
            Callback = function(value)
                State.KillAura.Enabled.Value = value
                Core.BulwarkTarget.isKillAura = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "KillAura " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'EnabledKA'
        })
        UI.Sections.KillAura:Slider({
            Name = "Range",
            Minimum = 4,
            Maximum = 20,
            Default = State.KillAura.Range.Default,
            Precision = 0,
            Callback = function(value)
                State.KillAura.Range.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Range set to: " .. value)
                end
            end,
            'RangeKA'
        })
        UI.Sections.KillAura:Slider({
            Name = "Attack Cooldown",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = State.KillAura.AttackCooldown.Default,
            Precision = 2,
            Callback = function(value)
                State.KillAura.AttackCooldown.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Attack Cooldown set to: " .. value)
                end
            end,
            'AttackCooldownKA'
        })
        UI.Sections.KillAura:Toggle({
            Name = "Dynamic Cooldown",
            Default = State.KillAura.DynamicCooldown.Default,
            Callback = function(value)
                State.KillAura.DynamicCooldown.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Dynamic Cooldown " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'DynamicCooldownKA'
        })
        UI.Sections.KillAura:Divider()
        UI.Sections.KillAura:Toggle({
            Name = "Anti Block",
            Default = State.KillAura.AntiBlock.Default,
            Callback = function(value)
                State.KillAura.AntiBlock.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Anti Block " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'AntiBlockKA'
        })
        UI.Sections.KillAura:Toggle({
            Name = "Anti Parry",
            Default = State.KillAura.AntiParry.Default,
            Callback = function(value)
                State.KillAura.AntiParry.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Anti Parry " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'AntiParryKA'
        })
        UI.Sections.KillAura:Toggle({
            Name = "Multi Target",
            Default = State.KillAura.MultiTarget.Default,
            Callback = function(value)
                State.KillAura.MultiTarget.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Multi Target " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'MultiTargetKA'
        })
        UI.Sections.KillAura:Toggle({
            Name = "Multi Anti Counter",
            Default = State.KillAura.MultiAntiCounter.Default,
            Callback = function(value)
                State.KillAura.MultiAntiCounter.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Multi Anti Counter " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'MultiAntiCounterKA'
        })
        UI.Sections.KillAura:Divider()
        UI.Sections.KillAura:Toggle({
            Name = "Highlight Block",
            Default = State.KillAura.HighlightBlock.Default,
            Callback = function(value)
                State.KillAura.HighlightBlock.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Highlight Block " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'HighlightBlockKA'
        })
        UI.Sections.KillAura:Toggle({
            Name = "Highlight Parry",
            Default = State.KillAura.HighlightParry.Default,
            Callback = function(value)
                State.KillAura.HighlightParry.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Highlight Parry " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'HighlightParryKA'
        })
        UI.Sections.KillAura:Divider()
        UI.Sections.KillAura:Colorpicker({
            Name = "Parry Color",
            Default = State.KillAura.ParryColor.Default,
            Callback = function(value)
                State.KillAura.ParryColor.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Parry Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            end,
            'ParryColorKA'
        })
        UI.Sections.KillAura:Colorpicker({
            Name = "Block Color",
            Default = State.KillAura.BlockColor.Default,
            Callback = function(value)
                State.KillAura.BlockColor.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Block Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            end,
            'BlockColorKA'
        })
        UI.Sections.KillAura:Colorpicker({
            Name = "Default Color",
            Default = State.KillAura.DefaultColor.Default,
            Callback = function(value)
                State.KillAura.DefaultColor.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("KillAura", "Default Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
                end
            end,
            'DefaultColorKA'
        })

        UI.Sections.ToolExploit = UI.Sections.ToolExploit or UI.Tabs.Combat:Section({ Name = "ToolExploit", Side = "Right" })
        UI.Sections.ToolExploit:Header({ Name = "Tool Exploit" })
        UI.Sections.ToolExploit:SubLabel({ Text = "Only for KillAura, reduces the preparation time for an attack"})
        UI.Sections.ToolExploit:Slider({
            Name = "Minus Windup",
            Minimum = 0.1,
            Maximum = 2,
            Default = State.KillAura.MinusWindup.Default,
            Precision = 1,
            Callback = function(value)
                State.KillAura.MinusWindup.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("ToolExploit", "Minus Windup set to: " .. value)
                end
            end,
            'MinusWindupTE'
        })
        UI.Sections.ToolExploit:Slider({
            Name = "Minus Release",
            Minimum = 0.1,
            Maximum = 2,
            Default = State.KillAura.MinusRelease.Default,
            Precision = 1,
            Callback = function(value)
                State.KillAura.MinusRelease.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("ToolExploit", "Minus Release set to: " .. value)
                end
            end,
            'MinusReleaseTE'
        })
        UI.Sections.ToolExploit:Divider()
        UI.Sections.ToolExploit:Slider({
            Name = "Kick Delay",
            Minimum = 0.01,
            Maximum = 0.2,
            Default = State.KillAura.KickDelay.Default,
            Precision = 3,
            Callback = function(value)
                State.KillAura.KickDelay.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("ToolExploit", "Kick Delay set to: " .. value)
                end
            end,
            'KickDelayTE'
        })
        UI.Sections.ToolExploit:Slider({
            Name = "Kick State Delay",
            Minimum = 0.01,
            Maximum = 0.2,
            Default = State.KillAura.KickStateDelay.Default,
            Precision = 3,
            Callback = function(value)
                State.KillAura.KickStateDelay.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("ToolExploit", "Kick State Delay set to: " .. value)
                end
            end,
            'KickStateDelayTE'
        })

        UI.Sections.AutoDodge = UI.Sections.AutoDodge or UI.Tabs.Combat:Section({ Name = "AutoDodge", Side = "Right" })
        UI.Sections.AutoDodge:Header({ Name = "Auto Dodge" })
        UI.Sections.AutoDodge:Toggle({
            Name = "Enabled",
            Default = State.AutoDodge.Enabled.Default,
            Callback = function(value)
                State.AutoDodge.Enabled.Value = value
                Core.BulwarkTarget.isAutoDodge = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "AutoDodge " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'EnabledAD'
        })
        UI.Sections.AutoDodge:Slider({
            Name = "Range",
            Minimum = 4,
            Maximum = 16,
            Default = State.AutoDodge.Range.Default,
            Precision = 0,
            Callback = function(value)
                State.AutoDodge.Range.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Range set to: " .. value)
                end
            end,
            'RangeAD'
        })
        UI.Sections.AutoDodge:Slider({
            Name = "PreRange",
            Minimum = 8,
            Maximum = 32,
            Default = State.AutoDodge.PreRange.Default,
            Precision = 0,
            Callback = function(value)
                State.AutoDodge.PreRange.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "PreRange set to: " .. value)
                end
            end,
            'PreRangeAD'
        })
        UI.Sections.AutoDodge:Slider({
            Name = "Dodge Cooldown",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = State.AutoDodge.DodgeCooldown.Default,
            Precision = 1,
            Callback = function(value)
                State.AutoDodge.DodgeCooldown.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Dodge Cooldown set to: " .. value)
                end
            end,
            'DodgeCooldownAD'
        })
        UI.Sections.AutoDodge:Slider({
            Name = "Prediction Time",
            Minimum = 0,
            Maximum = 0.5,
            Default = State.AutoDodge.PredictionTime.Default,
            Precision = 2,
            Callback = function(value)
                State.AutoDodge.PredictionTime.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Prediction Time set to: " .. value)
                end
            end,
            'PredictionTimeAD'
        })
        UI.Sections.AutoDodge:Divider()
        UI.Sections.AutoDodge:Toggle({
            Name = "Team Check",
            Default = State.AutoDodge.TeamCheck.Default,
            Callback = function(value)
                State.AutoDodge.TeamCheck.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Team Check " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'TeamCheckAD'
        })
        UI.Sections.AutoDodge:Toggle({
            Name = "KillAura Sync",
            Default = State.AutoDodge.KillAuraSync.Default,
            Callback = function(value)
                State.AutoDodge.KillAuraSync.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "KillAura Sync " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'KillAuraSyncAD'
        })
        UI.Sections.AutoDodge:Toggle({
            Name = "Idle Spoof",
            Default = State.AutoDodge.IdleSpoof.Default,
            Callback = function(value)
                State.AutoDodge.IdleSpoof.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Idle Spoof " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'IdleSpoofAD'
        })
        UI.Sections.AutoDodge:SubLabel({ Text = "[❗] Recommend use Idle Spoof ONLY with Block mode, parry mode may cause crashes "})
        UI.Sections.AutoDodge:Toggle({
            Name = "Use Client Idle",
            Default = State.AutoDodge.UseClientIdle.Default,
            Callback = function(value)
                State.AutoDodge.UseClientIdle.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Use Client Idle " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'UseClientIdleAD'
        })
        UI.Sections.AutoDodge:Toggle({
            Name = "Resolve Angle",
            Default = State.AutoDodge.ResolveAngle.Default,
            Callback = function(value)
                State.AutoDodge.ResolveAngle.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Resolve Angle " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'ResolveAngleAD'
        })
        UI.Sections.AutoDodge:Divider()
        UI.Sections.AutoDodge:Slider({
            Name = "Block Chance",
            Minimum = 0,
            Maximum = 100,
            Precision = 0,
            Suffix = "%",
            Default = State.AutoDodge.ParryingChance.Default,
            Callback = function(value)
                State.AutoDodge.ParryingChance.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Parrying Chance set to: " .. value .. "%")
                end
            end,
            'ParryingChanceAD'
        })
        UI.Sections.AutoDodge:Slider({
            Name = "Parry Chance",
            Minimum = 0,
            Maximum = 100,
            Precision = 0,
            Suffix = "%",
            Default = State.AutoDodge.RiposteChance.Default,
            Callback = function(value)
                State.AutoDodge.RiposteChance.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Parry Chance set to: " .. value .. "%")
                end
            end,
            'RiposteChanceAD'
        })
        UI.Sections.AutoDodge:Slider({
            Name = "Miss Chance",
            Minimum = 0,
            Maximum = 1,
            Default = State.AutoDodge.MissChance.Default,
            Precision = 1,
            Callback = function(value)
                State.AutoDodge.MissChance.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Miss Chance set to: " .. value)
                end
            end,
            'MissChanceAD'
        })
        UI.Sections.AutoDodge:Divider()
        UI.Sections.AutoDodge:Toggle({
            Name = "Legit Block",
            Default = State.AutoDodge.LegitBlock.Default,
            Callback = function(value)
                State.AutoDodge.LegitBlock.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Legit Block " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'LegitBlockAD'
        })
        UI.Sections.AutoDodge:Toggle({
            Name = "Legit Parry",
            Default = State.AutoDodge.LegitParry.Default,
            Callback = function(value)
                State.AutoDodge.LegitParry.Value = value
                if tick() - lastNotificationTime >= notificationDelay then
                    lastNotificationTime = tick()
                    notify("AutoDodge", "Legit Parry " .. (value and "Enabled" or "Disabled"), true)
                end
            end,
            'LegitParryAD'
        })
    end
end

return KillAura
