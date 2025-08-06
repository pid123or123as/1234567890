local TargetESP = {}

function TargetESP.Init(UI, Core, notify)
    local Players = Core.Services.Players
    local RunService = Core.Services.RunService
    local Workspace = Core.Services.Workspace
    local camera = Workspace.CurrentCamera

    local LocalPlayer = Core.PlayerData.LocalPlayer
    local localCharacter = LocalPlayer.Character

    local State = {
        TargetESP = {
            TargetESPActive = { Value = false, Default = false },
            TargetESPMethod = { Value = "All", Default = "All", Options = {"All", "KillAura", "AutoDodge"} },
            TargetESPRadius = { Value = 1.7, Default = 1.7 },
            TargetESPParts = { Value = 30, Default = 30 },
            TargetESPGradientSpeed = { Value = 4, Default = 4 },
            TargetESPGradient = { Value = true, Default = true },
            TargetESPColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            TargetESPYOffset = { Value = 0, Default = 0 },
            AnimateCircle = { Value = "None", Default = "None", Options = {"None", "Orbit", "Jello", "OrbitSwirl"} },
            AnimationSpeed = { Value = 2, Default = 2 }, -- Новая настройка скорости анимации
            OrbitTilt = { Value = 0.7, Default = 0.7 } -- Новая настройка наклона для Orbit и OrbitSwirl
        }
    }

    local targetESPQuads = {}
    local targetESPBlurQuads = {}
    local targetESPOppositeQuads = {}
    local lastTarget = nil

    local function destroyParts(parts)
        for _, part in ipairs(parts) do
            if part and part.Destroy then
                part:Destroy()
            end
        end
        table.clear(parts)
    end

    local function interpolateColor(color1, color2, factor)
        return Color3.new(
            color1.R + (color2.R - color1.R) * factor,
            color1.G + (color2.G - color1.G) * factor,
            color1.B + (color2.B - color1.B) * factor
        )
    end

    local function getTargetRootPart()
        local method = State.TargetESP.TargetESPMethod.Value
        local targetName = nil

        if method == "All" then
            targetName = Core.BulwarkTarget.CurrentTarget
        elseif method == "KillAura" then
            targetName = Core.BulwarkTarget.KillAuraTarget
        elseif method == "AutoDodge" then
            targetName = Core.BulwarkTarget.AutoDodgeTarget
        end

        if targetName and Players:FindFirstChild(targetName) then
            local targetPlayer = Players:FindFirstChild(targetName)
            return targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        end
        return nil
    end

    local function createTargetESP()
        local rootPart = getTargetRootPart()
        if not rootPart then return end

        destroyParts(targetESPQuads)
        destroyParts(targetESPBlurQuads)
        destroyParts(targetESPOppositeQuads)

        local partsCount = State.TargetESP.TargetESPParts.Value
        for i = 1, partsCount do
            local quad = Drawing.new("Quad")
            quad.Visible = false
            quad.Thickness = (State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl") and 1.5 or 1
            quad.Filled = false
            quad.Color = State.TargetESP.TargetESPGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / partsCount) or
                State.TargetESP.TargetESPColor.Value
            table.insert(targetESPQuads, quad)

            local oppositeQuad = Drawing.new("Quad")
            oppositeQuad.Visible = false
            oppositeQuad.Thickness = (State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl") and 1.5 or 1
            oppositeQuad.Filled = false
            oppositeQuad.Color = quad.Color
            table.insert(targetESPOppositeQuads, oppositeQuad)
        end

        if State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl" then
            for i = 1, partsCount do
                local blurQuad = Drawing.new("Quad")
                blurQuad.Visible = false
                blurQuad.Thickness = 1.5
                blurQuad.Filled = true
                blurQuad.Color = targetESPQuads[i].Color
                blurQuad.Transparency = 0.3
                table.insert(targetESPBlurQuads, blurQuad)
            end
        end -- Jello и None не создают Blur-круги
    end

    local function updateTargetESP()
        if not State.TargetESP.TargetESPActive.Value then
            destroyParts(targetESPQuads)
            destroyParts(targetESPBlurQuads)
            destroyParts(targetESPOppositeQuads)
            return
        end

        local rootPart = getTargetRootPart()
        if not rootPart then
            destroyParts(targetESPQuads)
            destroyParts(targetESPBlurQuads)
            destroyParts(targetESPOppositeQuads)
            lastTarget = nil
            return
        end

        local currentTargetName
        if State.TargetESP.TargetESPMethod.Value == "All" then
            currentTargetName = Core.BulwarkTarget.CurrentTarget
        elseif State.TargetESP.TargetESPMethod.Value == "KillAura" then
            currentTargetName = Core.BulwarkTarget.KillAuraTarget
        elseif State.TargetESP.TargetESPMethod.Value == "AutoDodge" then
            currentTargetName = Core.BulwarkTarget.AutoDodgeTarget
        end

        if currentTargetName ~= lastTarget then
            lastTarget = currentTargetName
            createTargetESP()
        end

        local t = tick()
        local yOffset
        if State.TargetESP.AnimateCircle.Value == "Jello" then
            yOffset = math.sin(t * State.TargetESP.AnimationSpeed.Value) * 2.75 - 0.25 -- От -3 до 2.5
        elseif State.TargetESP.AnimateCircle.Value == "Orbit" then
            yOffset = math.sin(t * State.TargetESP.AnimationSpeed.Value) * 0.5
        else
            yOffset = State.TargetESP.TargetESPYOffset.Value
        end

        local center = Vector3.new(rootPart.Position.X, rootPart.Position.Y + yOffset, rootPart.Position.Z)
        local screenCenter, onScreenCenter = camera:WorldToViewportPoint(center)
        if not (onScreenCenter and screenCenter.Z > 0) then
            for _, quad in ipairs(targetESPQuads) do
                quad.Visible = false
            end
            for _, blurQuad in ipairs(targetESPBlurQuads) do
                blurQuad.Visible = false
            end
            for _, oppositeQuad in ipairs(targetESPOppositeQuads) do
                oppositeQuad.Visible = false
            end
            return
        end

        local espRadius = State.TargetESP.TargetESPRadius.Value
        local partsCount = #targetESPQuads
        for i, quad in ipairs(targetESPQuads) do
            local angleOffset
            if State.TargetESP.AnimateCircle.Value == "Jello" then
                angleOffset = math.sin(t * State.TargetESP.AnimationSpeed.Value) * 0.2
            elseif State.TargetESP.AnimateCircle.Value == "OrbitSwirl" then
                angleOffset = t * (State.TargetESP.AnimationSpeed.Value * 0.75)
            else
                angleOffset = 0
            end

            local angle1 = ((i - 1) / partsCount) * 2 * math.pi + angleOffset
            local angle2 = (i / partsCount) * 2 * math.pi + angleOffset
            local oppositeAngle1 = -angle1
            local oppositeAngle2 = -angle2

            local depthOffset = (State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl") and
                                (math.cos(t * State.TargetESP.AnimationSpeed.Value + (i / partsCount) * 2 * math.pi) * State.TargetESP.OrbitTilt.Value) or 0
            local point1 = center + Vector3.new(math.cos(angle1) * espRadius, depthOffset, math.sin(angle1) * espRadius)
            local point2 = center + Vector3.new(math.cos(angle2) * espRadius, depthOffset, math.sin(angle2) * espRadius)

            local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
            local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

            if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                if State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl" then
                    local point3 = center + Vector3.new(math.cos(angle1) * espRadius * 0.95, depthOffset, math.sin(angle1) * espRadius * 0.95)
                    local point4 = center + Vector3.new(math.cos(angle2) * espRadius * 0.95, depthOffset, math.sin(angle2) * espRadius * 0.95)
                    local screenPoint3, onScreen3 = camera:WorldToViewportPoint(point3)
                    local screenPoint4, onScreen4 = camera:WorldToViewportPoint(point4)

                    if onScreen3 and onScreen4 and screenPoint3.Z > 0 and screenPoint4.Z > 0 then
                        quad.PointA = Vector2.new(screenPoint3.X, screenPoint3.Y)
                        quad.PointB = Vector2.new(screenPoint4.X, screenPoint4.Y)
                        quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                        quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                        quad.Visible = true
                    else
                        quad.Visible = false
                    end
                else
                    quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                    quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                    quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                    quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                    quad.Visible = true
                end

                if State.TargetESP.TargetESPGradient.Value then
                    local factor = (math.sin(t * State.TargetESP.TargetESPGradientSpeed.Value + (i / partsCount) * 2 * math.pi) + 1) / 2
                    quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    quad.Color = State.TargetESP.TargetESPColor.Value
                end

                local oppositeQuad = targetESPOppositeQuads[i]
                local oppPoint1 = center + Vector3.new(math.cos(oppositeAngle1) * espRadius, -depthOffset, math.sin(oppositeAngle1) * espRadius)
                local oppPoint2 = center + Vector3.new(math.cos(oppositeAngle2) * espRadius, -depthOffset, math.sin(oppositeAngle2) * espRadius)

                local screenOppPoint1, onScreenOpp1 = camera:WorldToViewportPoint(oppPoint1)
                local screenOppPoint2, onScreenOpp2 = camera:WorldToViewportPoint(oppPoint2)

                if onScreenOpp1 and onScreenOpp2 and screenOppPoint1.Z > 0 and screenOppPoint2.Z > 0 then
                    if State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl" then
                        local oppPoint3 = center + Vector3.new(math.cos(oppositeAngle1) * espRadius * 0.95, -depthOffset, math.sin(oppositeAngle1) * espRadius * 0.95)
                        local oppPoint4 = center + Vector3.new(math.cos(oppositeAngle2) * espRadius * 0.95, -depthOffset, math.sin(oppositeAngle2) * espRadius * 0.95)
                        local screenOppPoint3, onScreenOpp3 = camera:WorldToViewportPoint(oppPoint3)
                        local screenOppPoint4, onScreenOpp4 = camera:WorldToViewportPoint(oppPoint4)

                        if onScreenOpp3 and onScreenOpp4 and screenOppPoint3.Z > 0 and screenOppPoint4.Z > 0 then
                            oppositeQuad.PointA = Vector2.new(screenOppPoint3.X, screenOppPoint3.Y)
                            oppositeQuad.PointB = Vector2.new(screenOppPoint4.X, screenOppPoint4.Y)
                            oppositeQuad.PointC = Vector2.new(screenOppPoint2.X, screenOppPoint2.Y)
                            oppositeQuad.PointD = Vector2.new(screenOppPoint1.X, screenOppPoint1.Y)
                            oppositeQuad.Visible = true
                        else
                            oppositeQuad.Visible = false
                        end
                    else
                        oppositeQuad.PointA = Vector2.new(screenOppPoint1.X, screenOppPoint1.Y)
                        oppositeQuad.PointB = Vector2.new(screenOppPoint2.X, screenOppPoint2.Y)
                        oppositeQuad.PointC = Vector2.new(screenOppPoint2.X, screenOppPoint2.Y)
                        oppositeQuad.PointD = Vector2.new(screenOppPoint1.X, screenOppPoint1.Y)
                        oppositeQuad.Visible = true
                    end
                    oppositeQuad.Color = quad.Color
                else
                    oppositeQuad.Visible = false
                end
            else
                quad.Visible = false
                if targetESPOppositeQuads[i] then
                    targetESPOppositeQuads[i].Visible = false
                end
            end
        end

        if State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl" then
            for i, blurQuad in ipairs(targetESPBlurQuads) do
                local angle1 = ((i - 1) / partsCount) * 2 * math.pi + (State.TargetESP.AnimateCircle.Value == "OrbitSwirl" and (t * (State.TargetESP.AnimationSpeed.Value * 0.75)) or 0)
                local angle2 = (i / partsCount) * 2 * math.pi + (State.TargetESP.AnimateCircle.Value == "OrbitSwirl" and (t * (State.TargetESP.AnimationSpeed.Value * 0.75)) or 0)
                local blurOffset = 0.05
                local blurCenter = Vector3.new(rootPart.Position.X, rootPart.Position.Y + yOffset - blurOffset, rootPart.Position.Z)
                local blurPoint1 = blurCenter + Vector3.new(math.cos(angle1) * espRadius, depthOffset, math.sin(angle1) * espRadius)
                local blurPoint2 = blurCenter + Vector3.new(math.cos(angle2) * espRadius, depthOffset, math.sin(angle2) * espRadius)
                local blurPoint3 = blurCenter + Vector3.new(math.cos(angle1) * espRadius * 0.95, depthOffset, math.sin(angle1) * espRadius * 0.95)
                local blurPoint4 = blurCenter + Vector3.new(math.cos(angle2) * espRadius * 0.95, depthOffset, math.sin(angle2) * espRadius * 0.95)

                local screenBlurPoint1, onScreenBlur1 = camera:WorldToViewportPoint(blurPoint1)
                local screenBlurPoint2, onScreenBlur2 = camera:WorldToViewportPoint(blurPoint2)
                local screenBlurPoint3, onScreenBlur3 = camera:WorldToViewportPoint(blurPoint3)
                local screenBlurPoint4, onScreenBlur4 = camera:WorldToViewportPoint(blurPoint4)

                if onScreenBlur1 and onScreenBlur2 and onScreenBlur3 and onScreenBlur4 and screenBlurPoint1.Z > 0 and screenBlurPoint2.Z > 0 and screenBlurPoint3.Z > 0 and screenBlurPoint4.Z > 0 then
                    blurQuad.PointA = Vector2.new(screenBlurPoint3.X, screenBlurPoint3.Y)
                    blurQuad.PointB = Vector2.new(screenBlurPoint4.X, screenBlurPoint4.Y)
                    blurQuad.PointC = Vector2.new(screenBlurPoint2.X, screenBlurPoint2.Y)
                    blurQuad.PointD = Vector2.new(screenBlurPoint1.X, screenBlurPoint1.Y)
                    blurQuad.Visible = true
                    blurQuad.Color = targetESPQuads[i].Color
                else
                    blurQuad.Visible = false
                end
            end
        end
    end

    local function toggleTargetESP(value)
        State.TargetESP.TargetESPActive.Value = value
        if value then
            createTargetESP()
            notify("TargetESP", "Target ESP Enabled", true)
        else
            destroyParts(targetESPQuads)
            destroyParts(targetESPBlurQuads)
            destroyParts(targetESPOppositeQuads)
            lastTarget = nil
            notify("TargetESP", "Target ESP Disabled", true)
        end
    end

    local connection
    connection = RunService.RenderStepped:Connect(function()
        if localCharacter and State.TargetESP.TargetESPActive.Value then
            updateTargetESP()
        else
            destroyParts(targetESPQuads)
            destroyParts(targetESPBlurQuads)
            destroyParts(targetESPOppositeQuads)
            lastTarget = nil
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(character)
        localCharacter = character
    end)

    if UI.Tabs and UI.Tabs.Visuals then
        local targetESPSection = UI.Sections.TargetESP or UI.Tabs.Visuals:Section({ Name = "TargetESP", Side = "Right" })
        UI.Sections.TargetESP = targetESPSection
        targetESPSection:Header({ Name = "Target ESP" })
        targetESPSection:SubLabel({ Text = "Displays a circle above the target player" })
        targetESPSection:Toggle({
            Name = "Enabled",
            Default = State.TargetESP.TargetESPActive.Default,
            Callback = function(value)
                toggleTargetESP(value)
            end,
            'TargetESPEnabled'
        })
        targetESPSection:Divider()
        targetESPSection:Dropdown({
            Name = "Method",
            Default = State.TargetESP.TargetESPMethod.Default,
            Options = State.TargetESP.TargetESPMethod.Options,
            Callback = function(value)
                State.TargetESP.TargetESPMethod.Value = value
                lastTarget = nil
                if State.TargetESP.TargetESPActive.Value then
                    createTargetESP()
                end
                notify("TargetESP", "Method set to: " .. value, false)
            end,
            'TargetESPMethod'
        })
        targetESPSection:Slider({
            Name = "Radius",
            Minimum = 0.5,
            Maximum = 4.0,
            Default = State.TargetESP.TargetESPRadius.Default,
            Precision = 1,
            Callback = function(value)
                State.TargetESP.TargetESPRadius.Value = value
                if State.TargetESP.TargetESPActive.Value then
                    createTargetESP()
                end
                notify("TargetESP", "Target ESP Radius set to: " .. value, false)
            end,
            'TargetESPRadius'
        })
        targetESPSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 100,
            Default = State.TargetESP.TargetESPParts.Default,
            Precision = 0,
            Callback = function(value)
                State.TargetESP.TargetESPParts.Value = value
                if State.TargetESP.TargetESPActive.Value then
                    createTargetESP()
                end
                notify("TargetESP", "Target ESP Parts set to: " .. value, false)
            end,
            'TargetESPParts'
        })
        targetESPSection:Divider()
        targetESPSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.TargetESP.TargetESPGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.TargetESP.TargetESPGradientSpeed.Value = value
                notify("TargetESP", "Target ESP Gradient Speed set to: " .. value, false)
            end,
            'TargetESPGradientSpeed'
        })
        targetESPSection:Toggle({
            Name = "Gradient",
            Default = State.TargetESP.TargetESPGradient.Default,
            Callback = function(value)
                State.TargetESP.TargetESPGradient.Value = value
                if State.TargetESP.TargetESPActive.Value then
                    createTargetESP()
                end
                notify("TargetESP", "Target ESP Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'TargetESPGradient'
        })
        targetESPSection:Colorpicker({
            Name = "Color",
            Default = State.TargetESP.TargetESPColor.Default,
            Callback = function(value)
                State.TargetESP.TargetESPColor.Value = value
                if State.TargetESP.TargetESPActive.Value and not State.TargetESP.TargetESPGradient.Value then
                    createTargetESP()
                end
                notify("TargetESP", "Target ESP Color updated", false)
            end,
            'TargetESPColor'
        })
        targetESPSection:Divider()
        targetESPSection:Slider({
            Name = "Y Offset",
            Minimum = -5,
            Maximum = 5,
            Default = State.TargetESP.TargetESPYOffset.Default,
            Precision = 2,
            Callback = function(value)
                if State.TargetESP.AnimateCircle.Value == "None" then
                    State.TargetESP.TargetESPYOffset.Value = value
                    if State.TargetESP.TargetESPActive.Value then
                        createTargetESP()
                    end
                    notify("TargetESP", "Target ESP Y Offset set to: " .. value, false)
                end
            end,
            'TargetESPYOffset'
        })
        targetESPSection:Divider()
        targetESPSection:Dropdown({
            Name = "Animate Circle",
            Default = State.TargetESP.AnimateCircle.Default,
            Options = State.TargetESP.AnimateCircle.Options,
            Callback = function(value)
                State.TargetESP.AnimateCircle.Value = value
                if State.TargetESP.TargetESPActive.Value then
                    createTargetESP()
                end
                notify("TargetESP", "Animate Circle set to: " .. value, false)
            end,
            'AnimateCircle'
        })
        targetESPSection:Slider({
            Name = "Animation Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.TargetESP.AnimationSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.TargetESP.AnimationSpeed.Value = value
                notify("TargetESP", "Animation Speed set to: " .. value, false)
            end,
            'AnimationSpeed'
        })
        targetESPSection:Slider({
            Name = "Orbit Tilt",
            Minimum = 0.1,
            Maximum = 2,
            Default = State.TargetESP.OrbitTilt.Default,
            Precision = 2,
            Callback = function(value)
                State.TargetESP.OrbitTilt.Value = value
                if State.TargetESP.TargetESPActive.Value and (State.TargetESP.AnimateCircle.Value == "Orbit" or State.TargetESP.AnimateCircle.Value == "OrbitSwirl") then
                    createTargetESP()
                end
                notify("TargetESP", "Orbit Tilt set to: " .. value, false)
            end,
            'OrbitTilt'
        })
    end

    function TargetESP:Destroy()
        destroyParts(targetESPQuads)
        destroyParts(targetESPBlurQuads)
        destroyParts(targetESPOppositeQuads)
        if connection then
            connection:Disconnect()
        end
    end

    return TargetESP
end

return TargetESP