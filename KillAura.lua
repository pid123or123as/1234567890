local KillAura = {}
print('Bulwark KillAura v2.0 Loaded')

function KillAura.Init(UI, Core, notify)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService = game:GetService("RunService")
    local ContextActionService = game:GetService("ContextActionService")
    local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("ToServer")
    local ChangeStance = RemoteEvents:WaitForChild("ChangeStance")
    local Hit = RemoteEvents:WaitForChild("Hit")
    local Kick = RemoteEvents:WaitForChild("Kick")
    local Punch = RemoteEvents:WaitForChild("Punch")

    local LocalPlayer = Players.LocalPlayer

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
            DodgeCooldown = { Value = 0.12, Default = 0.12 },
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
            BaseMultiplier = { Value = 0.08, Default = 0.08 },
            DistanceFactor = { Value = 0.025, Default = 0.025 },
            Delay = { Value = 0.002, Default = 0.002 },
            Blocking = { Value = true, Default = true },
            BlockingAntiStun = { Value = true, Default = true },
            RiposteMouseLockDuration = { Value = 1.5, Default = 1.5 },
            MaxWaitTime = { Value = 1, Default = 1 },
            PredictionTime = { Value = 0.04, Default = 0.04 },
            ResolveAngle = { Value = true, Default = true },
            AngleDelay = { Value = 0.002, Default = 0.002 },
            AdaptiveFactor = { Value = 0.5, Default = 0.5 },
            DragSensitivity = { Value = 0.7, Default = 0.7 }
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
    local lastDodgeTime = 0
    local closestTarget = nil
    local isPerformingAction = false
    local isRiposteActive = false
    local riposteEndTime = 0
    local isDodgePending = false
    local desiredDodgeAction = nil
    local dmgPointHistory = {}
    local trajectoryCache = {}
    local attackHistory = {}

    local INVALID_STANCES = {"windup", "release", "parrying", "unparry", "punching", "kickwindup", "kicking", "flinch", "recovery"}
    local VALID_HUMANOID_STATES = {Enum.HumanoidStateType.Running, Enum.HumanoidStateType.RunningNoPhysics, Enum.HumanoidStateType.None}
    local LATENCY_BUFFER = 0.02
    local PREDICTION_THRESHOLD = 0.15
    local MAX_ADDITIONAL_TARGETS = 3
    local MIN_RELEASE_TIME = 0.03
    local DRAG_VELOCITY_THRESHOLD = 15
    local DRAG_VARIANCE_THRESHOLD = 4

    -- Core Functions
    local function getPlayerStance(player)
        if not player or not player.Character then return nil end
        local stanceValue = player.Character:FindFirstChild("Stance", true)
        return stanceValue and stanceValue:IsA("StringValue") and stanceValue.Value:lower() or nil
    end

    local function getTargetWeaponSettings(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return nil, nil end
        local weapon = targetPlayer.Character:FindFirstChildOfClass("Tool")
        if not weapon then return nil, nil end
        local settingsModule = weapon:FindFirstChild("Settings")
        if not settingsModule then return nil, nil end
        local success, settings = pcall(require, settingsModule)
        return success and settings and type(settings) == "table" and settings.Release and weapon, settings
    end

    local function getWeaponSettings()
        if not localCharacter then return nil end
        local weapon = localCharacter:FindFirstChildOfClass("Tool")
        if not weapon then
            cachedSettings = nil
            lastWeapon = nil
            return nil
        end
        if weapon == lastWeapon and cachedSettings then return cachedSettings end
        
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
        
        local windup = math.max(0.1, settings.Windup - (State.KillAura.Enabled.Value and State.KillAura.MinusWindup.Value or 0))
        local release = math.max(0.1, settings.Release - (State.KillAura.Enabled.Value and State.KillAura.MinusRelease.Value or 0))
        
        cachedSettings = {
            weapon = weapon,
            windupTime = windup,
            releaseTime = release,
            Type = settings.Type or "Unknown"
        }
        lastWeapon = weapon
        return cachedSettings
    end

    local function canTargetPlayer(targetPlayer, range, teamCheck)
        if not (localCharacter and localRootPart and localHumanoid and localHumanoid.Health > 0) then return false end
        if not (targetPlayer and targetPlayer.Character) then return false end
        
        local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetPlayer.Character:FindFirstChild("Humanoid")
        if not (targetRootPart and targetHumanoid) or targetHumanoid.Health <= 0 then return false end
        
        local distance = (localRootPart.Position - targetRootPart.Position).Magnitude
        if distance > range or distance ~= distance then return false end
        
        if teamCheck and targetPlayer.Team and LocalPlayer.Team then
            if targetPlayer.Team == LocalPlayer.Team and LocalPlayer.Team.Name ~= "Spectators" then
                return false
            end
        end
        
        return true
    end

    -- Advanced Prediction System
    local function analyzeDmgPointTrajectory(targetPlayer, weapon)
        if not (weapon and targetPlayer and targetPlayer.Character) then return false, 0 end
        
        local blade = weapon:FindFirstChild("Blade")
        local dmgPoint = blade and blade:FindFirstChild("DmgPoint")
        if not dmgPoint then return false, 0 end

        local currentPos = dmgPoint.WorldPosition
        local currentTime = tick()

        if trajectoryCache[targetPlayer] and currentTime - trajectoryCache[targetPlayer].time < 0.05 then
            return trajectoryCache[targetPlayer].isDrag, trajectoryCache[targetPlayer].velocity
        end

        if not dmgPointHistory[targetPlayer] then dmgPointHistory[targetPlayer] = {} end
        
        table.insert(dmgPointHistory[targetPlayer], {position = currentPos, time = currentTime})
        if #dmgPointHistory[targetPlayer] > 6 then table.remove(dmgPointHistory[targetPlayer], 1) end
        if #dmgPointHistory[targetPlayer] < 3 then return false, 0 end

        local velocities = {}
        for i = 2, #dmgPointHistory[targetPlayer] do
            local current = dmgPointHistory[targetPlayer][i]
            local previous = dmgPointHistory[targetPlayer][i-1]
            local deltaTime = current.time - previous.time
            if deltaTime > 0 then
                local velocity = (current.position - previous.position) / deltaTime
                table.insert(velocities, velocity.Magnitude)
            end
        end

        if #velocities < 2 then return false, 0 end

        local totalVelocity = 0
        for _, vel in ipairs(velocities) do totalVelocity = totalVelocity + vel end
        local avgVelocity = totalVelocity / #velocities

        local variance = 0
        for _, vel in ipairs(velocities) do
            variance = variance + (vel - avgVelocity) ^ 2
        end
        variance = variance / #velocities

        local isDrag = avgVelocity < DRAG_VELOCITY_THRESHOLD and variance > DRAG_VARIANCE_THRESHOLD

        trajectoryCache[targetPlayer] = {
            isDrag = isDrag,
            velocity = avgVelocity,
            time = currentTime
        }

        return isDrag, avgVelocity
    end

    local function predictAttackTrajectory(targetPlayer, weapon, settings)
        if not (weapon and settings and targetPlayer and targetPlayer.Character and localRootPart) then
            return false, 0
        end

        local targetRootPart = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetRootPart then return false, 0 end

        local blade = weapon:FindFirstChild("Blade")
        local dmgPoint = blade and blade:FindFirstChild("DmgPoint")
        if not dmgPoint then return false, 0 end

        local currentPos = dmgPoint.WorldPosition
        local isDrag, dragVelocity = analyzeDmgPointTrajectory(targetPlayer, weapon)
        local targetVelocity = targetRootPart.Velocity

        if isDrag then
            local attackDirection = (localRootPart.Position - currentPos).Unit
            local dragFactor = State.AutoDodge.DragSensitivity.Value
            local predictedPos = currentPos + attackDirection * (settings.Release * 1.3 * dragFactor)
            local distance = (localRootPart.Position - predictedPos).Magnitude
            local timeToHit = distance / math.max(5, dragVelocity)
            return distance <= State.AutoDodge.Range.Value, math.max(MIN_RELEASE_TIME, timeToHit - LATENCY_BUFFER)
        else
            local predictedPos = currentPos + targetVelocity * settings.Release
            local distance = (localRootPart.Position - predictedPos).Magnitude
            local attackSpeed = math.max(10, 1/settings.Release * 12)
            local timeToHit = distance / attackSpeed
            return distance <= State.AutoDodge.Range.Value, math.max(MIN_RELEASE_TIME, timeToHit - LATENCY_BUFFER)
        end
    end

    local function checkDamagePointCollision(targetPlayer, weapon)
        if not (weapon and targetPlayer and targetPlayer.Character and localCharacter) then return false end
        
        local blade = weapon:FindFirstChild("Blade")
        if not blade then return false end

        local damagePoints = {}
        for _, part in pairs(blade:GetChildren()) do
            if part.Name == "DmgPoint" and part:IsA("Attachment") then
                table.insert(damagePoints, part)
            end
        end
        if #damagePoints == 0 then return false end

        local hitboxes = {
            localCharacter:FindFirstChild("Head"),
            localCharacter:FindFirstChild("UpperTorso") or localCharacter:FindFirstChild("Torso"),
            localCharacter:FindFirstChild("LeftArm") or localCharacter:FindFirstChild("Left Arm"),
            localCharacter:FindFirstChild("RightArm") or localCharacter:FindFirstChild("Right Arm"),
            localCharacter:FindFirstChild("LeftLeg") or localCharacter:FindFirstChild("Left Leg"),
            localCharacter:FindFirstChild("RightLeg") or localCharacter:FindFirstChild("Right Leg")
        }

        for _, damagePoint in pairs(damagePoints) do
            for _, hitbox in pairs(hitboxes) do
                if hitbox and hitbox:IsA("BasePart") then
                    local distance = (damagePoint.WorldPosition - hitbox.Position).Magnitude
                    if distance <= (hitbox.Size.Magnitude / 2) + PREDICTION_THRESHOLD then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function predictAttack(targetPlayer)
        if not targetPlayer or not targetPlayer.Character then return false, 0 end
        
        local weapon, settings = getTargetWeaponSettings(targetPlayer)
        if not (weapon and settings) then return false, 0 end

        local stance = getPlayerStance(targetPlayer)
        if stance ~= "release" then return false, 0 end

        if State.AutoDodge.ResolveAngle.Value then
            if checkDamagePointCollision(targetPlayer, weapon) then
                return true, math.max(MIN_RELEASE_TIME, settings.Release - LATENCY_BUFFER - State.AutoDodge.PredictionTime.Value)
            else
                local willHit, waitTime = predictAttackTrajectory(targetPlayer, weapon, settings)
                if willHit then
                    local distance = (localRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
                    local adjustedTime = waitTime * (State.AutoDodge.BaseMultiplier.Value + distance * State.AutoDodge.DistanceFactor.Value)
                    return true, math.max(MIN_RELEASE_TIME, adjustedTime)
                end
            end
        else
            local distance = (localRootPart.Position - targetPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance <= State.AutoDodge.Range.Value then
                local waitTime = settings.Release * (State.AutoDodge.BaseMultiplier.Value + distance * State.AutoDodge.DistanceFactor.Value) - LATENCY_BUFFER
                return true, math.max(MIN_RELEASE_TIME, waitTime)
            end
        end

        return false, 0
    end

    -- AutoDodge System
    local function performDodgeAction(action, waitTime)
        if isPerformingAction or tick() - lastDodgeTime < State.AutoDodge.DodgeCooldown.Value then
            isDodgePending = false
            desiredDodgeAction = nil
            return false
        end

        isPerformingAction = true
        isDodgePending = true
        desiredDodgeAction = action

        if not (localHumanoid and localHumanoid.Health > 0) then
            isPerformingAction = false
            isDodgePending = false
            desiredDodgeAction = nil
            return false
        end

        waitTime = math.min(waitTime, State.AutoDodge.MaxWaitTime.Value)
        if waitTime ~= waitTime then waitTime = 0.15 end
        waitTime = waitTime + State.AutoDodge.PredictionTime.Value

        ChangeStance:FireServer(action)
        
        if action == "Riposte" then
            isRiposteActive = true
            riposteEndTime = tick() + State.AutoDodge.RiposteMouseLockDuration.Value
        end

        task.wait(waitTime)

        if action == "Riposte" then
            ChangeStance:FireServer("RiposteDelay")
            task.wait(0.3)
        else
            ChangeStance:FireServer("UnParry")
            task.wait(0.003)
        end

        ChangeStance:FireServer("Idle")
        
        if action == "Riposte" then
            isRiposteActive = false
        end

        lastDodgeTime = tick()
        isPerformingAction = false
        isDodgePending = false
        desiredDodgeAction = nil
        
        return true
    end

    local function shouldKillAuraPause()
        if not State.AutoDodge.KillAuraSync.Value or not State.AutoDodge.Enabled.Value then return false end
        if not closestTarget then return false end
        
        local stance = getPlayerStance(closestTarget)
        local willHit, _ = predictAttack(closestTarget)
        
        return (willHit and isDodgePending) or 
               (stance == "riposte") or
               (stance and (stance == "parrying" or stance == "block") and isDodgePending)
    end

    -- KillAura System
    local function updateTargetHighlight(targets)
        for player, highlight in pairs(targetHighlights) do
            if not table.find(targets, player) or not player.Character then
                highlight:Destroy()
                targetHighlights[player] = nil
            end
        end

        for _, player in pairs(targets) do
            if player.Character and not targetHighlights[player] then
                local highlight = Instance.new("Highlight")
                highlight.Name = "TargetHighlight"
                highlight.Parent = player.Character
                highlight.Adornee = player.Character
                highlight.FillTransparency = 0.5
                highlight.OutlineTransparency = 0
                targetHighlights[player] = highlight
            end
            
            if targetHighlights[player] then
                local stance = getPlayerStance(player)
                if stance and (stance == "parrying" or stance == "block") and State.KillAura.HighlightBlock.Value then
                    targetHighlights[player].FillColor = State.KillAura.BlockColor.Value
                elseif stance and stance == "riposte" and State.KillAura.HighlightParry.Value then
                    targetHighlights[player].FillColor = State.KillAura.ParryColor.Value
                else
                    targetHighlights[player].FillColor = State.KillAura.DefaultColor.Value
                end
                targetHighlights[player].Enabled = true
            end
        end
    end

    local function removeTargetHighlights()
        for _, highlight in pairs(targetHighlights) do
            highlight:Destroy()
        end
        targetHighlights = {}
    end

    local function performPunch(targetPlayer, targetCharacter, weapon)
        local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
        if not targetHumanoid then return false end
        
        local stance = getPlayerStance(targetPlayer)
        if not stance or not ((stance == "parrying" or stance == "block") and State.KillAura.AntiBlock.Value) then
            return false
        end

        ChangeStance:FireServer("Punching")
        task.wait(State.KillAura.KickDelay.Value)
        
        if not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
            return false
        end

        local targetHandle = targetCharacter:FindFirstChild("HumanoidRootPart")
        if not targetHandle then return false end

        Punch:FireServer(weapon, targetHandle, targetHumanoid)
        return true
    end

    local function performKick(targetPlayer, targetCharacter, weapon)
        local targetHumanoid = targetCharacter:FindFirstChild("Humanoid")
        if not targetHumanoid then return false end
        
        local stance = getPlayerStance(targetPlayer)
        if not stance or stance ~= "riposte" or not State.KillAura.AntiParry.Value then
            return false
        end

        ChangeStance:FireServer("KickWindup")
        task.wait(State.KillAura.KickDelay.Value)
        
        if not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
            return false
        end

        ChangeStance:FireServer("Kicking")
        task.wait(State.KillAura.KickStateDelay.Value)
        
        if not targetCharacter.Parent or not targetCharacter:FindFirstChild("Humanoid") then
            return false
        end

        local targetHandle = targetCharacter:FindFirstChild("CollisionBubble") or targetCharacter:FindFirstChild("HumanoidRootPart")
        if not targetHandle then return false end

        Kick:FireServer(weapon, targetHandle, targetHumanoid)
        return true
    end

    local function getAdditionalTargets(mainTarget)
        local additionalTargets = {}
        local count = 0
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player ~= mainTarget and canTargetPlayer(player, State.KillAura.Range.Value, State.KillAura.TeamCheck.Value) then
                local targetHumanoid = player.Character and player.Character:FindFirstChild("Humanoid")
                if targetHumanoid and targetHumanoid.Health > 0 then
                    local stance = getPlayerStance(player)
                    if not stance or not (stance == "parrying" or stance == "block" or stance == "riposte") then
                        table.insert(additionalTargets, player)
                        count = count + 1
                        if count >= MAX_ADDITIONAL_TARGETS then break end
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
                local targetHumanoid = player.Character and player.Character:FindFirstChild("Humanoid")
                if targetHumanoid and targetHumanoid.Health > 0 then
                    local stance = getPlayerStance(player)
                    if (action == "Punch" and stance and (stance == "parrying" or stance == "block") and State.KillAura.AntiBlock.Value) or
                       (action == "Kick" and stance == "riposte" and State.KillAura.AntiParry.Value) then
                        table.insert(targets, player)
                        count = count + 1
                        if count >= MAX_ADDITIONAL_TARGETS then break end
                    end
                end
            end
        end
        
        return targets
    end

    -- Main Loops
    local function collectDodgeData()
        while true do
            local updateInterval = State.AutoDodge.ResolveAngle.Value and 0.01 or 0.03
            task.wait(updateInterval)
            
            localCharacter = LocalPlayer.Character
            localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
            localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")
            
            if not (localCharacter and localRootPart and localHumanoid and localHumanoid.Health > 0) then
                closestTarget = nil
                continue
            end

            closestTarget = nil
            local minDistance = math.huge
            
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and canTargetPlayer(player, State.AutoDodge.PreRange.Value, State.AutoDodge.TeamCheck.Value) then
                    local distance = (localRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                    if distance < minDistance then
                        minDistance = distance
                        closestTarget = player
                    end
                end
            end
        end
    end

    local function runAutoDodge()
        while true do
            local updateInterval = State.AutoDodge.ResolveAngle.Value and 0.01 or 0.03
            task.wait(updateInterval)
            
            if not State.AutoDodge.Enabled.Value then
                isDodgePending = false
                continue
            end

            if not (localCharacter and localRootPart and localHumanoid and localHumanoid.Health > 0) then
                isDodgePending = false
                continue
            end

            if tick() - lastDodgeTime < State.AutoDodge.DodgeCooldown.Value then
                continue
            end

            if not closestTarget or not canTargetPlayer(closestTarget, State.AutoDodge.Range.Value, State.AutoDodge.TeamCheck.Value) then
                continue
            end

            local willHit, waitTime = predictAttack(closestTarget)
            
            if willHit then
                local action
                if State.AutoDodge.BlockingMode.Value == "Riposte" then
                    action = "Riposte"
                elseif State.AutoDodge.BlockingMode.Value == "Parrying" then
                    action = "Parrying"
                else
                    local totalChance = State.AutoDodge.ParryingChance.Value + State.AutoDodge.RiposteChance.Value
                    action = math.random() < (State.AutoDodge.ParryingChance.Value / totalChance) and "Parrying" or "Riposte"
                end

                if math.random() > State.AutoDodge.MissChance.Value then
                    performDodgeAction(action, waitTime)
                end
            end
        end
    end

    local function runKillAura()
        task.spawn(collectDodgeData)
        task.spawn(runAutoDodge)
        
        while true do
            RunService.Heartbeat:Wait()
            
            if not State.KillAura.Enabled.Value then
                removeTargetHighlights()
                continue
            end

            if shouldKillAuraPause() then
                continue
            end

            localCharacter = LocalPlayer.Character
            localRootPart = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
            localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")
            
            if not (localCharacter and localRootPart and localHumanoid) then
                removeTargetHighlights()
                continue
            end

            local settings = getWeaponSettings()
            if not settings then
                removeTargetHighlights()
                continue
            end

            if tick() - lastAttackTime < State.KillAura.AttackCooldown.Value then
                continue
            end

            local targets = {}
            local closestTargetKA = nil
            local minDistance = math.huge
            
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and canTargetPlayer(player, State.KillAura.Range.Value, State.KillAura.TeamCheck.Value) then
                    local distance = (localRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                    table.insert(targets, player)
                    if distance < minDistance then
                        minDistance = distance
                        closestTargetKA = player
                    end
                end
            end

            if not closestTargetKA then
                removeTargetHighlights()
                continue
            end

            if State.KillAura.MultiTarget.Value then
                updateTargetHighlight(targets)
            else
                updateTargetHighlight({closestTargetKA})
            end

            local targetCharacter = closestTargetKA.Character
            local targetHumanoid = targetCharacter and targetCharacter:FindFirstChild("Humanoid")
            if not (targetCharacter and targetHumanoid) then
                removeTargetHighlights()
                continue
            end

            local attacked = false
            local stance = getPlayerStance(closestTargetKA)

            if stance and State.KillAura.MultiAntiCounter.Value then
                if (stance == "parrying" or stance == "block") and State.KillAura.AntiBlock.Value then
                    local punchTargets = getAntiCounterTargets("Punch")
                    for _, targetPlayer in pairs(punchTargets) do
                        local tCharacter = targetPlayer.Character
                        if tCharacter then
                            attacked = performPunch(targetPlayer, tCharacter, settings.weapon) or attacked
                        end
                    end
                elseif stance == "riposte" and State.KillAura.AntiParry.Value then
                    local kickTargets = getAntiCounterTargets("Kick")
                    for _, targetPlayer in pairs(kickTargets) do
                        local tCharacter = targetPlayer.Character
                        if tCharacter then
                            attacked = performKick(targetPlayer, tCharacter, settings.weapon) or attacked
                        end
                    end
                end
            elseif stance then
                if (stance == "parrying" or stance == "block") and State.KillAura.AntiBlock.Value then
                    attacked = performPunch(closestTargetKA, targetCharacter, settings.weapon)
                elseif stance == "riposte" and State.KillAura.AntiParry.Value then
                    attacked = performKick(closestTargetKA, targetCharacter, settings.weapon)
                end
            end

            if not attacked then
                if State.KillAura.DynamicCooldown.Value then
                    local delays = State.KillAura.DynamicDelays.Value
                    task.wait(delays[math.random(1, #delays)])
                end

                ChangeStance:FireServer("Windup")
                task.wait(settings.windupTime)
                
                if not targetCharacter.Parent or not targetHumanoid or targetHumanoid.Health <= 0 then
                    removeTargetHighlights()
                    continue
                end

                stance = getPlayerStance(closestTargetKA)
                if stance and ((stance == "parrying" or stance == "block") and State.KillAura.AntiBlock.Value or 
                   (stance == "riposte" and State.KillAura.AntiParry.Value)) then
                    removeTargetHighlights()
                    continue
                end

                ChangeStance:FireServer("Release")
                task.wait(settings.releaseTime)
                
                if not targetCharacter.Parent or not targetHumanoid or targetHumanoid.Health <= 0 then
                    removeTargetHighlights()
                    continue
                end

                local targetHandle = targetCharacter:FindFirstChildOfClass("Accessory") and 
                                   targetCharacter:FindFirstChildOfClass("Accessory").Handle or 
                                   targetCharacter:FindFirstChild("HumanoidRootPart")
                if targetHandle then
                    Hit:FireServer(settings.weapon, targetHandle, targetHumanoid)
                    attacked = true

                    if State.KillAura.MultiTarget.Value then
                        local additionalTargets = getAdditionalTargets(closestTargetKA)
                        local multiTargetDelays = State.KillAura.MultiTargetDelays.Value
                        
                        for i, additionalTarget in ipairs(additionalTargets) do
                            local addCharacter = additionalTarget.Character
                            local addHumanoid = addCharacter and addCharacter:FindFirstChild("Humanoid")
                            if addHumanoid and addHumanoid.Health > 0 then
                                local addHandle = addCharacter:FindFirstChildOfClass("Accessory") and 
                                                addCharacter:FindFirstChildOfClass("Accessory").Handle or 
                                                addCharacter:FindFirstChild("HumanoidRootPart")
                                if addHandle then
                                    local delayIndex = (i - 1) % #multiTargetDelays + 1
                                    task.wait(multiTargetDelays[delayIndex])
                                    Hit:FireServer(settings.weapon, addHandle, addHumanoid)
                                end
                            end
                        end
                    end
                end
            end

            if attacked then
                lastAttackTime = tick()
            else
                removeTargetHighlights()
            end
        end
    end

    -- Initialize
    Players.PlayerRemoving:Connect(function(player)
        if targetHighlights[player] then
            targetHighlights[player]:Destroy()
            targetHighlights[player] = nil
        end
        if closestTarget == player then
            closestTarget = nil
        end
    end)

    local function onCharacterAdded(player)
        player.CharacterAdded:Connect(function(character)
            local humanoid = character:WaitForChild("Humanoid", 3)
            if humanoid then
                humanoid.Died:Connect(function()
                    if targetHighlights[player] then
                        targetHighlights[player]:Destroy()
                        targetHighlights[player] = nil
                    end
                    if closestTarget == player then
                        closestTarget = nil
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

    -- UI Setup (simplified)
    local uiElements = {}

    if UI.Tabs and UI.Tabs.Combat then
        UI.Sections.KillAura = UI.Sections.KillAura or UI.Tabs.Combat:Section({ Name = "KillAura", Side = "Left" })
        UI.Sections.KillAura:Header({ Name = "KillAura" })
        uiElements.KillAuraEnabled = UI.Sections.KillAura:Toggle({
            Name = "Enabled",
            Default = State.KillAura.Enabled.Default,
            Callback = function(value)
                State.KillAura.Enabled.Value = value
                Core.BulwarkTarget.isKillAura = value
                notify("KillAura", "KillAura " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "EnabledKA")
        uiElements.KillAuraRange = UI.Sections.KillAura:Slider({
            Name = "Range",
            Minimum = 4,
            Maximum = 20,
            Default = State.KillAura.Range.Default,
            Precision = 0,
            Callback = function(value)
                State.KillAura.Range.Value = value
                notify("KillAura", "Range set to: " .. value)
            end
        }, "RangeKA")
        uiElements.KillAuraAttackCooldown = UI.Sections.KillAura:Slider({
            Name = "Attack Cooldown",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = State.KillAura.AttackCooldown.Default,
            Precision = 2,
            Callback = function(value)
                State.KillAura.AttackCooldown.Value = value
                notify("KillAura", "Attack Cooldown set to: " .. value)
            end
        }, "AttackCooldownKA")
        UI.Sections.KillAura:Toggle({
            Name = "Dynamic Cooldown",
            Default = State.KillAura.DynamicCooldown.Default,
            Callback = function(value)
                State.KillAura.DynamicCooldown.Value = value
                notify("KillAura", "Dynamic Cooldown " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "DynamicCooldownKA")
        UI.Sections.KillAura:Divider()
        UI.Sections.KillAura:Toggle({
            Name = "Anti Block",
            Default = State.KillAura.AntiBlock.Default,
            Callback = function(value)
                State.KillAura.AntiBlock.Value = value
                notify("KillAura", "Anti Block " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "AntiBlockKA")
        UI.Sections.KillAura:Toggle({
            Name = "Anti Parry",
            Default = State.KillAura.AntiParry.Default,
            Callback = function(value)
                State.KillAura.AntiParry.Value = value
                notify("KillAura", "Anti Parry " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "AntiParryKA")
        UI.Sections.KillAura:Toggle({
            Name = "Multi Target",
            Default = State.KillAura.MultiTarget.Default,
            Callback = function(value)
                State.KillAura.MultiTarget.Value = value
                notify("KillAura", "Multi Target " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "MultiTargetKA")
        UI.Sections.KillAura:Toggle({
            Name = "Multi Anti Counter",
            Default = State.KillAura.MultiAntiCounter.Default,
            Callback = function(value)
                State.KillAura.MultiAntiCounter.Value = value
                notify("KillAura", "Multi Anti Counter " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "MultiAntiCounterKA")
        UI.Sections.KillAura:Divider()
        UI.Sections.KillAura:Toggle({
            Name = "Highlight Block",
            Default = State.KillAura.HighlightBlock.Default,
            Callback = function(value)
                State.KillAura.HighlightBlock.Value = value
                notify("KillAura", "Highlight Block " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "HighlightBlockKA")
        UI.Sections.KillAura:Toggle({
            Name = "Highlight Parry",
            Default = State.KillAura.HighlightParry.Default,
            Callback = function(value)
                State.KillAura.HighlightParry.Value = value
                notify("KillAura", "Highlight Parry " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "HighlightParryKA")
        UI.Sections.KillAura:Divider()
        UI.Sections.KillAura:Colorpicker({
            Name = "Parry Color",
            Default = State.KillAura.ParryColor.Default,
            Callback = function(value)
                State.KillAura.ParryColor.Value = value
                notify("KillAura", "Parry Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
            end
        }, "ParryColorKA")
        UI.Sections.KillAura:Colorpicker({
            Name = "Block Color",
            Default = State.KillAura.BlockColor.Default,
            Callback = function(value)
                State.KillAura.BlockColor.Value = value
                notify("KillAura", "Block Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
            end
        }, "BlockColorKA")
        UI.Sections.KillAura:Colorpicker({
            Name = "Default Color",
            Default = State.KillAura.DefaultColor.Default,
            Callback = function(value)
                State.KillAura.DefaultColor.Value = value
                notify("KillAura", "Default Color set to: R=" .. math.floor(value.R * 255) .. ", G=" .. math.floor(value.G * 255) .. ", B=" .. math.floor(value.B * 255))
            end
        }, "DefaultColorKA")

        UI.Sections.ToolExploit = UI.Sections.ToolExploit or UI.Tabs.Combat:Section({ Name = "ToolExploit", Side = "Right" })
        UI.Sections.ToolExploit:Header({ Name = "Tool Exploit" })
        UI.Sections.ToolExploit:SubLabel({ Text = "Only for KillAura, reduces the preparation time for an attack"})
        uiElements.ToolExploitMinusWindup = UI.Sections.ToolExploit:Slider({
            Name = "Minus Windup",
            Minimum = 0.1,
            Maximum = 2,
            Default = State.KillAura.MinusWindup.Default,
            Precision = 1,
            Callback = function(value)
                State.KillAura.MinusWindup.Value = value
                notify("ToolExploit", "Minus Windup set to: " .. value)
            end
        }, "MinusWindupTE")
        uiElements.ToolExploitMinusRelease = UI.Sections.ToolExploit:Slider({
            Name = "Minus Release",
            Minimum = 0.1,
            Maximum = 2,
            Default = State.KillAura.MinusRelease.Default,
            Precision = 1,
            Callback = function(value)
                State.KillAura.MinusRelease.Value = value
                notify("ToolExploit", "Minus Release set to: " .. value)
            end
        }, "MinusReleaseTE")
        UI.Sections.ToolExploit:Divider()
        uiElements.ToolExploitKickDelay = UI.Sections.ToolExploit:Slider({
            Name = "Kick Delay",
            Minimum = 0.01,
            Maximum = 0.2,
            Default = State.KillAura.KickDelay.Default,
            Precision = 3,
            Callback = function(value)
                State.KillAura.KickDelay.Value = value
                notify("ToolExploit", "Kick Delay set to: " .. value)
            end
        }, "KickDelayTE")
        uiElements.ToolExploitKickStateDelay = UI.Sections.ToolExploit:Slider({
            Name = "Kick State Delay",
            Minimum = 0.01,
            Maximum = 0.2,
            Default = State.KillAura.KickStateDelay.Default,
            Precision = 3,
            Callback = function(value)
                State.KillAura.KickStateDelay.Value = value
                notify("ToolExploit", "Kick State Delay set to: " .. value)
            end
        }, "KickStateDelayTE")

        UI.Sections.AutoDodge = UI.Sections.AutoDodge or UI.Tabs.Combat:Section({ Name = "AutoDodge", Side = "Right" })
        UI.Sections.AutoDodge:Header({ Name = "Auto Dodge" })
        UI.Sections.AutoDodge:Toggle({
            Name = "Enabled",
            Default = State.AutoDodge.Enabled.Default,
            Callback = function(value)
                State.AutoDodge.Enabled.Value = value
                Core.BulwarkTarget.isAutoDodge = value
                notify("AutoDodge", "AutoDodge " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "EnabledAD")
        uiElements.AutoDodgeRange = UI.Sections.AutoDodge:Slider({
            Name = "Range",
            Minimum = 4,
            Maximum = 16,
            Default = State.AutoDodge.Range.Default,
            Precision = 0,
            Callback = function(value)
                State.AutoDodge.Range.Value = value
                notify("AutoDodge", "Range set to: " .. value)
            end
        }, "RangeAD")
        uiElements.AutoDodgePreRange = UI.Sections.AutoDodge:Slider({
            Name = "PreRange",
            Minimum = 8,
            Maximum = 32,
            Default = State.AutoDodge.PreRange.Default,
            Precision = 0,
            Callback = function(value)
                State.AutoDodge.PreRange.Value = value
                notify("AutoDodge", "PreRange set to: " .. value)
            end
        }, "PreRangeAD")
        uiElements.AutoDodgeDodgeCooldown = UI.Sections.AutoDodge:Slider({
            Name = "Dodge Cooldown",
            Minimum = 0.1,
            Maximum = 0.5,
            Default = State.AutoDodge.DodgeCooldown.Default,
            Precision = 1,
            Callback = function(value)
                State.AutoDodge.DodgeCooldown.Value = value
                notify("AutoDodge", "Dodge Cooldown set to: " .. value)
            end
        }, "DodgeCooldownAD")
        uiElements.AutoDodgePredictionTime = UI.Sections.AutoDodge:Slider({
            Name = "Prediction Time",
            Minimum = 0,
            Maximum = 0.5,
            Default = State.AutoDodge.PredictionTime.Default,
            Precision = 2,
            Callback = function(value)
                State.AutoDodge.PredictionTime.Value = value
                notify("AutoDodge", "Prediction Time set to: " .. value)
            end
        }, "PredictionTimeAD")
        uiElements.AutoDodgeAdaptiveFactor = UI.Sections.AutoDodge:Slider({
            Name = "Adaptive Factor",
            Minimum = 0.1,
            Maximum = 1,
            Default = State.AutoDodge.AdaptiveFactor.Default,
            Precision = 2,
            Callback = function(value)
                State.AutoDodge.AdaptiveFactor.Value = value
                notify("AutoDodge", "Adaptive Factor set to: " .. value)
            end
        }, "AdaptiveFactorAD")
        UI.Sections.AutoDodge:Divider()
        UI.Sections.AutoDodge:Dropdown({
            Name = "Blocking Mode",
            Options = {"Parrying", "Riposte", "Chance"},
            Default = State.AutoDodge.BlockingMode.Default,
            Callback = function(value)
                State.AutoDodge.BlockingMode.Value = value
                notify("AutoDodge", "Blocking Mode set to: " .. value)
            end
        }, "BlockingModeAD")
        UI.Sections.AutoDodge:Toggle({
            Name = "Team Check",
            Default = State.AutoDodge.TeamCheck.Default,
            Callback = function(value)
                State.AutoDodge.TeamCheck.Value = value
                notify("AutoDodge", "Team Check " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "TeamCheckAD")
        UI.Sections.AutoDodge:Toggle({
            Name = "KillAura Sync",
            Default = State.AutoDodge.KillAuraSync.Default,
            Callback = function(value)
                State.AutoDodge.KillAuraSync.Value = value
                notify("AutoDodge", "KillAura Sync " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "KillAuraSyncAD")
        UI.Sections.AutoDodge:Toggle({
            Name = "Idle Spoof",
            Default = State.AutoDodge.IdleSpoof.Default,
            Callback = function(value)
                State.AutoDodge.IdleSpoof.Value = value
                notify("AutoDodge", "Idle Spoof " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "IdleSpoofAD")
        UI.Sections.AutoDodge:SubLabel({ Text = "[❗] Recommend use Idle Spoof ONLY with Block mode, parry mode may cause crashes "})
        UI.Sections.AutoDodge:Toggle({
            Name = "Use Client Idle",
            Default = State.AutoDodge.UseClientIdle.Default,
            Callback = function(value)
                State.AutoDodge.UseClientIdle.Value = value
                notify("AutoDodge", "Use Client Idle " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "UseClientIdleAD")
        UI.Sections.AutoDodge:Toggle({
            Name = "Resolve Angle",
            Default = State.AutoDodge.ResolveAngle.Default,
            Callback = function(value)
                State.AutoDodge.ResolveAngle.Value = value
                notify("AutoDodge", "Resolve Angle " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "ResolveAngleAD")
        UI.Sections.AutoDodge:Divider()
        uiElements.AutoDodgeParryingChance = UI.Sections.AutoDodge:Slider({
            Name = "Block Chance",
            Minimum = 0,
            Maximum = 100,
            Precision = 0,
            Suffix = "%",
            Default = State.AutoDodge.ParryingChance.Default,
            Callback = function(value)
                State.AutoDodge.ParryingChance.Value = value
                notify("AutoDodge", "Parrying Chance set to: " .. value .. "%")
            end
        }, "ParryingChanceAD")
        uiElements.AutoDodgeRiposteChance = UI.Sections.AutoDodge:Slider({
            Name = "Parry Chance",
            Minimum = 0,
            Maximum = 100,
            Precision = 0,
            Suffix = "%",
            Default = State.AutoDodge.RiposteChance.Default,
            Callback = function(value)
                State.AutoDodge.RiposteChance.Value = value
                notify("AutoDodge", "Parry Chance set to: " .. value .. "%")
            end
        }, "RiposteChanceAD")
        uiElements.AutoDodgeMissChance = UI.Sections.AutoDodge:Slider({
            Name = "Miss Chance",
            Minimum = 0,
            Maximum = 1,
            Default = State.AutoDodge.MissChance.Default,
            Precision = 1,
            Callback = function(value)
                State.AutoDodge.MissChance.Value = value
                notify("AutoDodge", "Miss Chance set to: " .. value)
            end
        }, "MissChanceAD")
        UI.Sections.AutoDodge:Divider()
        UI.Sections.AutoDodge:Toggle({
            Name = "Legit Block",
            Default = State.AutoDodge.LegitBlock.Default,
            Callback = function(value)
                State.AutoDodge.LegitBlock.Value = value
                notify("AutoDodge", "Legit Block " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "LegitBlockAD")
        UI.Sections.AutoDodge:Toggle({
            Name = "Legit Parry",
            Default = State.AutoDodge.LegitParry.Default,
            Callback = function(value)
                State.AutoDodge.LegitParry.Value = value
                notify("AutoDodge", "Legit Parry " .. (value and "Enabled" or "Disabled"), true)
            end
        }, "LegitParryAD")

        local configSection = UI.Tabs.Config:Section({ Name = "KillAura Sync", Side = "Right" })
        configSection:Header({ Name = "KillAura Settings Sync" })
        configSection:Button({
            Name = "Sync Config",
            Callback = function()
                State.KillAura.Range.Value = uiElements.KillAuraRange:GetValue()
                State.KillAura.AttackCooldown.Value = uiElements.KillAuraAttackCooldown:GetValue()
                State.KillAura.MinusWindup.Value = uiElements.ToolExploitMinusWindup:GetValue()
                State.KillAura.MinusRelease.Value = uiElements.ToolExploitMinusRelease:GetValue()
                State.KillAura.KickDelay.Value = uiElements.ToolExploitKickDelay:GetValue()
                State.KillAura.KickStateDelay.Value = uiElements.ToolExploitKickStateDelay:GetValue()
                State.AutoDodge.Range.Value = uiElements.AutoDodgeRange:GetValue()
                State.AutoDodge.PreRange.Value = uiElements.AutoDodgePreRange:GetValue()
                State.AutoDodge.DodgeCooldown.Value = uiElements.AutoDodgeDodgeCooldown:GetValue()
                State.AutoDodge.PredictionTime.Value = uiElements.AutoDodgePredictionTime:GetValue()
                State.AutoDodge.AdaptiveFactor.Value = uiElements.AutoDodgeAdaptiveFactor:GetValue()
                State.AutoDodge.ParryingChance.Value = uiElements.AutoDodgeParryingChance:GetValue()
                State.AutoDodge.RiposteChance.Value = uiElements.AutoDodgeRiposteChance:GetValue()
                State.AutoDodge.MissChance.Value = uiElements.AutoDodgeMissChance:GetValue()

                notify("KillAura", "Config synchronized!", true)
            end
        }, "KillAuraSync")
    end
end

return KillAura
