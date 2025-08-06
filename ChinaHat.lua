local ChinaHat = {}

function ChinaHat.Init(UI, Core, notify)
    local Players = Core.Services.Players
    local RunService = Core.Services.RunService
    local Workspace = Core.Services.Workspace
    local camera = Workspace.CurrentCamera

    local LocalPlayer = Core.PlayerData.LocalPlayer
    local localCharacter = LocalPlayer.Character
    local localHumanoid = localCharacter and localCharacter:FindFirstChild("Humanoid")

    local State = {
        ChinaHat = {
            HatActive = { Value = false, Default = false },
            HatScale = { Value = 0.85, Default = 0.85 },
            HatParts = { Value = 50, Default = 50 },
            HatGradientSpeed = { Value = 4, Default = 4 },
            HatGradient = { Value = true, Default = true },
            HatColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            HatYOffset = { Value = 1.6, Default = 1.6 },
            OutlineCircle = { Value = false, Default = false }
        },
        Circle = {
            CircleActive = { Value = false, Default = false },
            CircleRadius = { Value = 1.7, Default = 1.7 },
            CircleParts = { Value = 30, Default = 30 },
            CircleGradientSpeed = { Value = 4, Default = 4 },
            CircleGradient = { Value = true, Default = true },
            CircleColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            JumpAnimate = { Value = false, Default = false },
            CircleYOffset = { Value = -3, Default = -3 }
        },
        Nimb = {
            NimbActive = { Value = false, Default = false },
            NimbRadius = { Value = 1.7, Default = 1.7 },
            NimbParts = { Value = 30, Default = 30 },
            NimbGradientSpeed = { Value = 4, Default = 4 },
            NimbGradient = { Value = true, Default = true },
            NimbColor = { Value = Color3.fromRGB(0, 0, 255), Default = Color3.fromRGB(0, 0, 255) },
            NimbYOffset = { Value = 2.7, Default = 2.7 }
        }
    }

    local hatLines = {}
    local hatCircleQuads = {}
    local circleQuads = {}
    local nimbQuads = {}
    local jumpAnimationActive = false
    local renderConnection
    local humanoidConnection

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

    local function createHat()
        if not localCharacter or not localCharacter:FindFirstChild("Head") then return end
        destroyParts(hatLines)
        destroyParts(hatCircleQuads)
        local head = localCharacter.Head
        for i = 1, State.ChinaHat.HatParts.Value do
            local line = Drawing.new("Line")
            line.Visible = false
            line.Thickness = 0.06
            line.Transparency = 0.5
            line.Color = State.ChinaHat.HatGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.ChinaHat.HatParts.Value) or
                State.ChinaHat.HatColor.Value
            table.insert(hatLines, line)
        end
        if State.ChinaHat.OutlineCircle.Value then
            for i = 1, State.ChinaHat.HatParts.Value do
                local quad = Drawing.new("Quad")
                quad.Visible = false
                quad.Thickness = 1
                quad.Filled = false
                quad.Color = State.ChinaHat.HatGradient.Value and
                    interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.ChinaHat.HatParts.Value) or
                    State.ChinaHat.HatColor.Value
                table.insert(hatCircleQuads, quad)
            end
        end
    end

    local function createCircle()
        if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return end
        destroyParts(circleQuads)
        for i = 1, State.Circle.CircleParts.Value do
            local quad = Drawing.new("Quad")
            quad.Visible = false
            quad.Thickness = 1
            quad.Filled = false
            quad.Color = State.Circle.CircleGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.Circle.CircleParts.Value) or
                State.Circle.CircleColor.Value
            table.insert(circleQuads, quad)
        end
    end

    local function createNimb()
        if not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then return end
        destroyParts(nimbQuads)
        for i = 1, State.Nimb.NimbParts.Value do
            local quad = Drawing.new("Quad")
            quad.Visible = false
            quad.Thickness = 1
            quad.Filled = false
            quad.Color = State.Nimb.NimbGradient.Value and
                interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, i / State.Nimb.NimbParts.Value) or
                State.Nimb.NimbColor.Value
            table.insert(nimbQuads, quad)
        end
    end

    local function updateHat()
        if not State.ChinaHat.HatActive.Value or not localCharacter or not localCharacter:FindFirstChild("Head") then
            destroyParts(hatLines)
            destroyParts(hatCircleQuads)
            return
        end
        local head = localCharacter.Head
        local y = head.Position.Y + State.ChinaHat.HatYOffset.Value
        local t = tick()
        local hatHeight = 2.15 * State.ChinaHat.HatScale.Value
        local hatRadius = 1.95 * State.ChinaHat.HatScale.Value

        for i, line in ipairs(hatLines) do
            local angle = (i / State.ChinaHat.HatParts.Value) * 2 * math.pi
            local x = math.cos(angle) * hatRadius
            local z = math.sin(angle) * hatRadius
            local basePosition = Vector3.new(head.Position.X, y, head.Position.Z)
            local topPosition = Vector3.new(head.Position.X + x, y - hatHeight / 3, head.Position.Z + z)
            local offset = 0.03
            local direction = (topPosition - basePosition).Unit
            local endPoint = topPosition + direction * offset

            local screenStart, onScreenStart = camera:WorldToViewportPoint(basePosition)
            local screenEnd, onScreenEnd = camera:WorldToViewportPoint(endPoint)

            if onScreenStart and onScreenEnd and screenStart.Z > 0 and screenEnd.Z > 0 then
                line.From = Vector2.new(screenStart.X, screenStart.Y)
                line.To = Vector2.new(screenEnd.X, screenEnd.Y)
                line.Visible = true
                if State.ChinaHat.HatGradient.Value then
                    local factor = (math.sin(t * State.ChinaHat.HatGradientSpeed.Value + (i / State.ChinaHat.HatParts.Value) * 2 * math.pi) + 1) / 2
                    line.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    line.Color = State.ChinaHat.HatColor.Value
                end
            else
                line.Visible = false
            end
        end

        if State.ChinaHat.OutlineCircle.Value and #hatCircleQuads > 0 then
            local topCenter = Vector3.new(0, 0, 0)
            local visibleEnds = 0
            for i, line in ipairs(hatLines) do
                if line.Visible then
                    local angle = (i / State.ChinaHat.HatParts.Value) * 2 * math.pi
                    x = math.cos(angle) * hatRadius
                    z = math.sin(angle) * hatRadius
                    local topPosition = Vector3.new(head.Position.X + x, y - hatHeight / 3, head.Position.Z + z)
                    topCenter = topCenter + topPosition
                    visibleEnds = visibleEnds + 1
                end
            end
            if visibleEnds > 0 then
                topCenter = topCenter / visibleEnds
            else
                topCenter = Vector3.new(head.Position.X, y - hatHeight / 3, head.Position.Z)
            end

            local screenCenter, onScreenCenter = camera:WorldToViewportPoint(topCenter)
            if onScreenCenter and screenCenter.Z > 0 then
                local circleRadius = 2.0 * State.ChinaHat.HatScale.Value
                for i, quad in ipairs(hatCircleQuads) do
                    local angle1 = ((i - 1) / #hatCircleQuads) * 2 * math.pi
                    local angle2 = (i / #hatCircleQuads) * 2 * math.pi
                    local point1 = topCenter + Vector3.new(math.cos(angle1) * circleRadius, 0, math.sin(angle1) * circleRadius)
                    local point2 = topCenter + Vector3.new(math.cos(angle2) * circleRadius, 0, math.sin(angle2) * circleRadius)
                    local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
                    local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

                    if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                        quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                        quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                        quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                        quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                        quad.Visible = true
                        if State.ChinaHat.HatGradient.Value then
                            local factor = (math.sin(t * State.ChinaHat.HatGradientSpeed.Value + (i / #hatCircleQuads) * 2 * math.pi) + 1) / 2
                            quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                        else
                            quad.Color = State.ChinaHat.HatColor.Value
                        end
                    else
                        quad.Visible = false
                    end
                end
            else
                for _, quad in ipairs(hatCircleQuads) do
                    quad.Visible = false
                end
            end
        end
    end

    local function updateCircle()
        if not State.Circle.CircleActive.Value or not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then
            destroyParts(circleQuads)
            return
        end
        local rootPart = localCharacter.HumanoidRootPart
        local t = tick()
        local center = Vector3.new(rootPart.Position.X, rootPart.Position.Y + State.Circle.CircleYOffset.Value, rootPart.Position.Z)
        local screenCenter, onScreenCenter = camera:WorldToViewportPoint(center)
        if not (onScreenCenter and screenCenter.Z > 0) then
            for _, quad in ipairs(circleQuads) do
                quad.Visible = false
            end
            return
        end

        local circleRadius = State.Circle.CircleRadius.Value
        local partsCount = #circleQuads
        for i, quad in ipairs(circleQuads) do
            local angle1 = ((i - 1) / partsCount) * 2 * math.pi
            local angle2 = (i / partsCount) * 2 * math.pi
            local point1 = center + Vector3.new(math.cos(angle1) * circleRadius, 0, math.sin(angle1) * circleRadius)
            local point2 = center + Vector3.new(math.cos(angle2) * circleRadius, 0, math.sin(angle2) * circleRadius)
            local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
            local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

            if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.Visible = true
                if State.Circle.CircleGradient.Value then
                    local factor = (math.sin(t * State.Circle.CircleGradientSpeed.Value + (i / partsCount) * 2 * math.pi) + 1) / 2
                    quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    quad.Color = State.Circle.CircleColor.Value
                end
            else
                quad.Visible = false
            end
        end
    end

    local function updateNimb()
        if not State.Nimb.NimbActive.Value or not localCharacter or not localCharacter:FindFirstChild("HumanoidRootPart") then
            destroyParts(nimbQuads)
            return
        end
        local rootPart = localCharacter.HumanoidRootPart
        local t = tick()
        local center = Vector3.new(rootPart.Position.X, rootPart.Position.Y + State.Nimb.NimbYOffset.Value, rootPart.Position.Z)
        local screenCenter, onScreenCenter = camera:WorldToViewportPoint(center)
        if not (onScreenCenter and screenCenter.Z > 0) then
            for _, quad in ipairs(nimbQuads) do
                quad.Visible = false
            end
            return
        end

        local nimbRadius = State.Nimb.NimbRadius.Value
        local partsCount = #nimbQuads
        for i, quad in ipairs(nimbQuads) do
            local angle1 = ((i - 1) / partsCount) * 2 * math.pi
            local angle2 = (i / partsCount) * 2 * math.pi
            local point1 = center + Vector3.new(math.cos(angle1) * nimbRadius, 0, math.sin(angle1) * nimbRadius)
            local point2 = center + Vector3.new(math.cos(angle2) * nimbRadius, 0, math.sin(angle2) * nimbRadius)
            local screenPoint1, onScreen1 = camera:WorldToViewportPoint(point1)
            local screenPoint2, onScreen2 = camera:WorldToViewportPoint(point2)

            if onScreen1 and onScreen2 and screenPoint1.Z > 0 and screenPoint2.Z > 0 then
                quad.PointA = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.PointB = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointC = Vector2.new(screenPoint2.X, screenPoint2.Y)
                quad.PointD = Vector2.new(screenPoint1.X, screenPoint1.Y)
                quad.Visible = true
                if State.Nimb.NimbGradient.Value then
                    local factor = (math.sin(t * State.Nimb.NimbGradientSpeed.Value + (i / partsCount) * 2 * math.pi) + 1) / 2
                    quad.Color = interpolateColor(Core.GradientColors.Color1.Value, Core.GradientColors.Color2.Value, factor)
                else
                    quad.Color = State.Nimb.NimbColor.Value
                end
            else
                quad.Visible = false
            end
        end
    end

    local function animateJump()
        if not State.Circle.JumpAnimate.Value or #circleQuads == 0 or jumpAnimationActive then return end
        jumpAnimationActive = true
        local t = 0
        local duration = 0.55
        local initialRadius = State.Circle.CircleRadius.Value
        local maxRadius = initialRadius * 1.6
        while t < duration do
            local dt = RunService.RenderStepped:Wait()
            t = t + dt
            local factor = t / duration
            State.Circle.CircleRadius.Value = initialRadius + (maxRadius - initialRadius) * math.sin(factor * math.pi)
            updateCircle()
        end
        State.Circle.CircleRadius.Value = initialRadius
        jumpAnimationActive = false
    end

    local function toggleHat(value)
        State.ChinaHat.HatActive.Value = value
        if value then
            createHat()
            notify("ChinaHat", "Hat Enabled", true)
        else
            destroyParts(hatLines)
            destroyParts(hatCircleQuads)
            notify("ChinaHat", "Hat Disabled", true)
        end
    end

    local function toggleCircle(value)
        State.Circle.CircleActive.Value = value
        if value then
            createCircle()
            notify("Circle", "Circle Enabled", true)
        else
            destroyParts(circleQuads)
            notify("Circle", "Circle Disabled", true)
        end
    end

    local function toggleNimb(value)
        State.Nimb.NimbActive.Value = value
        if value then
            createNimb()
            notify("Nimb", "Nimb Enabled", true)
        else
            destroyParts(nimbQuads)
            notify("Nimb", "Nimb Disabled", true)
        end
    end

    local function onStateChanged(oldState, newState)
        if State.Circle.JumpAnimate.Value and newState == Enum.HumanoidStateType.Jumping and not jumpAnimationActive then
            animateJump()
        end
    end

    local function connectHumanoid(character)
        if humanoidConnection then
            humanoidConnection:Disconnect()
        end
        localCharacter = character
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            localHumanoid = humanoid
            humanoidConnection = humanoid.StateChanged:Connect(onStateChanged)
        end
        -- Воссоздаем элементы, если они активны
        if State.ChinaHat.HatActive.Value then
            createHat()
        end
        if State.Circle.CircleActive.Value then
            createCircle()
        end
        if State.Nimb.NimbActive.Value then
            createNimb()
        end
    end

    renderConnection = RunService.RenderStepped:Connect(function()
        if localCharacter then
            updateHat()
            updateCircle()
            updateNimb()
        else
            -- Не уничтожаем части, а просто скрываем их
            for _, line in ipairs(hatLines) do
                line.Visible = false
            end
            for _, quad in ipairs(hatCircleQuads) do
                quad.Visible = false
            end
            for _, quad in ipairs(circleQuads) do
                quad.Visible = false
            end
            for _, quad in ipairs(nimbQuads) do
                quad.Visible = false
            end
        end
    end)

    LocalPlayer.CharacterAdded:Connect(connectHumanoid)
    if localCharacter then
        connectHumanoid(localCharacter)
    end

    if UI.Tabs and UI.Tabs.Visuals then
        local chinaHatSection = UI.Sections.ChinaHat or UI.Tabs.Visuals:Section({ Name = "ChinaHat", Side = "Left" })
        UI.Sections.ChinaHat = chinaHatSection
        chinaHatSection:Header({ Name = "China Hat" })
        chinaHatSection:SubLabel({ Text = "Displays a hat above the player head" })
        chinaHatSection:Toggle({
            Name = "Enabled",
            Default = State.ChinaHat.HatActive.Default,
            Callback = function(value)
                toggleHat(value)
            end,
            'HatEnabled'
        })
        chinaHatSection:Divider()
        chinaHatSection:Slider({
            Name = "Scale",
            Minimum = 0.5,
            Maximum = 2.0,
            Default = State.ChinaHat.HatScale.Default,
            Precision = 2,
            Callback = function(value)
                State.ChinaHat.HatScale.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Scale set to: " .. value, false)
            end,
            'HatScale'
        })
        chinaHatSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 150,
            Default = State.ChinaHat.HatParts.Value,
            Precision = 0,
            Callback = function(value)
                State.ChinaHat.HatParts.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Parts set to: " .. value, false)
            end,
            'HatParts'
        })
        chinaHatSection:Divider()
        chinaHatSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.ChinaHat.HatGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.ChinaHat.HatGradientSpeed.Value = value
                notify("ChinaHat", "Hat Gradient Speed set to: " .. value, false)
            end,
            'HatGradientSpeed'
        })
        chinaHatSection:Toggle({
            Name = "Gradient",
            Default = State.ChinaHat.HatGradient.Default,
            Callback = function(value)
                State.ChinaHat.HatGradient.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'HatGradient'
        })
        chinaHatSection:Colorpicker({
            Name = "Color",
            Default = State.ChinaHat.HatColor.Default,
            Callback = function(value)
                State.ChinaHat.HatColor.Value = value
                if State.ChinaHat.HatActive.Value and not State.ChinaHat.HatGradient.Value then
                    createHat()
                end
                notify("ChinaHat", "Hat Color updated", false)
            end,
            'HatColor'
        })
        chinaHatSection:Divider()
        chinaHatSection:Slider({
            Name = "Y Offset",
            Minimum = -5,
            Maximum = 5,
            Default = State.ChinaHat.HatYOffset.Default,
            Precision = 2,
            Callback = function(value)
                State.ChinaHat.HatYOffset.Value = value
                notify("ChinaHat", "Hat Y Offset set to: " .. value, false)
            end,
            'HatYOffset'
        })
        chinaHatSection:Toggle({
            Name = "Outline Circle",
            Default = State.ChinaHat.OutlineCircle.Default,
            Callback = function(value)
                State.ChinaHat.OutlineCircle.Value = value
                if State.ChinaHat.HatActive.Value then
                    createHat()
                end
                notify("ChinaHat", "Outline Circle: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'OutlineCircle'
        })

        local circleSection = UI.Sections.Circle or UI.Tabs.Visuals:Section({ Name = "Circle", Side = "Left" })
        UI.Sections.Circle = circleSection
        circleSection:Header({ Name = "Circle" })
        circleSection:SubLabel({ Text = "Displays a circle at the player feet" })
        circleSection:Toggle({
            Name = "Enabled",
            Default = State.Circle.CircleActive.Default,
            Callback = function(value)
                toggleCircle(value)
            end,
            'CircleEnabled'
        })
        circleSection:Divider()
        circleSection:Slider({
            Name = "Radius",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = State.Circle.CircleRadius.Default,
            Precision = 1,
            Callback = function(value)
                State.Circle.CircleRadius.Value = value
                if State.Circle.CircleActive.Value then
                    createCircle()
                end
                notify("Circle", "Circle Radius set to: " .. value, false)
            end,
            'CircleRadius'
        })
        circleSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 100,
            Default = State.Circle.CircleParts.Default,
            Precision = 0,
            Callback = function(value)
                State.Circle.CircleParts.Value = value
                if State.Circle.CircleActive.Value then
                    createCircle()
                end
                notify("Circle", "Circle Parts set to: " .. value, false)
            end,
            'CircleParts'
        })
        circleSection:Divider()
        circleSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.Circle.CircleGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.Circle.CircleGradientSpeed.Value = value
                notify("Circle", "Circle Gradient Speed set to: " .. value, false)
            end,
            'CircleGradientSpeed'
        })
        circleSection:Toggle({
            Name = "Gradient",
            Default = State.Circle.CircleGradient.Default,
            Callback = function(value)
                State.Circle.CircleGradient.Value = value
                if State.Circle.CircleActive.Value then
                    createCircle()
                end
                notify("Circle", "Circle Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'CircleGradient'
        })
        circleSection:Colorpicker({
            Name = "Color",
            Default = State.Circle.CircleColor.Default,
            Callback = function(value)
                State.Circle.CircleColor.Value = value
                if State.Circle.CircleActive.Value and not State.Circle.CircleGradient.Value then
                    createCircle()
                end
                notify("Circle", "Circle Color updated", false)
            end,
            'CircleColor'
        })
        circleSection:Divider()
        circleSection:Toggle({
            Name = "Jump Animate",
            Default = State.Circle.JumpAnimate.Default,
            Callback = function(value)
                State.Circle.JumpAnimate.Value = value
                notify("Circle", "Jump Animation: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'JumpAnimate'
        })

        local nimbSection = UI.Sections.Nimb or UI.Tabs.Visuals:Section({ Name = "Nimb", Side = "Right" })
        UI.Sections.Nimb = nimbSection
        nimbSection:Header({ Name = "Nimb" })
        nimbSection:SubLabel({ Text = "Displays a circle above the player head" })
        nimbSection:Toggle({
            Name = "Nimb Enabled",
            Default = State.Nimb.NimbActive.Default,
            Callback = function(value)
                toggleNimb(value)
            end,
            'NimbEnabled'
        })
        nimbSection:Divider()
        nimbSection:Slider({
            Name = "Radius",
            Minimum = 1.0,
            Maximum = 3.0,
            Default = State.Nimb.NimbRadius.Default,
            Precision = 1,
            Callback = function(value)
                State.Nimb.NimbRadius.Value = value
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Radius set to: " .. value, false)
            end,
            'NimbRadius'
        })
        nimbSection:Slider({
            Name = "Parts",
            Minimum = 20,
            Maximum = 100,
            Default = State.Nimb.NimbParts.Default,
            Precision = 0,
            Callback = function(value)
                State.Nimb.NimbParts.Value = value
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Parts set to: " .. value, false)
            end,
            'NimbParts'
        })
        nimbSection:Divider()
        nimbSection:Slider({
            Name = "Gradient Speed",
            Minimum = 1,
            Maximum = 10,
            Default = State.Nimb.NimbGradientSpeed.Default,
            Precision = 1,
            Callback = function(value)
                State.Nimb.NimbGradientSpeed.Value = value
                notify("Nimb", "Nimb Gradient Speed set to: " .. value, false)
            end,
            'NimbGradientSpeed'
        })
        nimbSection:Toggle({
            Name = "Gradient",
            Default = State.Nimb.NimbGradient.Default,
            Callback = function(value)
                State.Nimb.NimbGradient.Value = value
                if State.Nimb.NimbActive.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Gradient: " .. (value and "Enabled" or "Disabled"), true)
            end,
            'NimbGradient'
        })
        nimbSection:Colorpicker({
            Name = "Color",
            Default = State.Nimb.NimbColor.Default,
            Callback = function(value)
                State.Nimb.NimbColor.Value = value
                if State.Nimb.NimbActive.Value and not State.Nimb.NimbGradient.Value then
                    createNimb()
                end
                notify("Nimb", "Nimb Color updated", false)
            end,
            'NimbColor'
        })
        nimbSection:Divider()
        nimbSection:Slider({
            Name = "Y Offset",
            Minimum = 1,
            Maximum = 3,
            Default = State.Nimb.NimbYOffset.Default,
            Precision = 2,
            Callback = function(value)
                State.Nimb.NimbYOffset.Value = value
                notify("Nimb", "Nimb Y Offset set to: " .. value, false)
            end,
            'NimbYOffset'
        })
    end

    function ChinaHat:Destroy()
        destroyParts(hatLines)
        destroyParts(hatCircleQuads)
        destroyParts(circleQuads)
        destroyParts(nimbQuads)
        if renderConnection then
            renderConnection:Disconnect()
        end
        if humanoidConnection then
            humanoidConnection:Disconnect()
        end
    end

    return ChinaHat
end

return ChinaHat