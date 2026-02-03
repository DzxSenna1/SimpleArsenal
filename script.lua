--// SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--// CONFIG
local ESP_ENABLED = false
local AIMBOT_ENABLED = false
local ENEMY_COLOR = Color3.fromRGB(255,70,70)
local LINE_COLOR = Color3.fromRGB(255,255,255)
local SKELETON_COLOR = Color3.fromRGB(0,255,0)
local CONTRAST_COLOR = Color3.fromRGB(255,0,0) -- destaque vermelho
local MAX_DIST = 700
local BONE_DIST_LIMIT = 700
local HP_BAR_THICKNESS = 4 -- menor que antes
local RECT_THICKNESS = 1 -- borda mais fina
local AIM_FOV =500  -- campo de visão do aimbot
local AIM_SMOOTH = 1 -- força do puxão fixada em 1
local function isVisible(targetPart, character)
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.IgnoreWater = true

    local result = workspace:Raycast(origin, direction, params)

    if not result then
        return true
    end

    return result.Instance:IsDescendantOf(character)
end

--// CACHE
local ESP_CACHE = {}

------------------------------------------------
-- UI BUTTONS
------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "ESP_UI"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ESP BUTTON
local espButton = Instance.new("TextButton")
espButton.Size = UDim2.fromOffset(140,40)
espButton.Position = UDim2.new(0,10,0,10)
espButton.BackgroundColor3 = Color3.fromRGB(30,30,30)
espButton.TextColor3 = Color3.new(1,1,1)
espButton.Text = "ESP: OFF"
espButton.Font = Enum.Font.SourceSansBold
espButton.TextSize = 16
espButton.Parent = gui

-- AIMBOT BUTTON
local aimbotButton = Instance.new("TextButton")
aimbotButton.Size = UDim2.fromOffset(140,40)
aimbotButton.Position = UDim2.new(0,10,0,60)
aimbotButton.BackgroundColor3 = Color3.fromRGB(30,30,30)
aimbotButton.TextColor3 = Color3.new(1,1,1)
aimbotButton.Text = "Aimbot: OFF"
aimbotButton.Font = Enum.Font.SourceSansBold
aimbotButton.TextSize = 16
aimbotButton.Parent = gui

------------------------------------------------
-- TEAM CHECK (NPC = enemy)
------------------------------------------------
local function isEnemy(player)
    if player == LocalPlayer then return false end

    -- se algum não tiver Team, considera inimigo
    if not player.Team or not LocalPlayer.Team then
        return true
    end

    return player.Team ~= LocalPlayer.Team
end


------------------------------------------------
-- DRAWING HELPERS
------------------------------------------------
local function createLine(color, thickness)
    local line = Drawing.new("Line")
    line.Visible = false
    line.Color = color
    line.Thickness = thickness or 1.5
    return line
end

local function createSquare(color, filled, thickness)
    local square = Drawing.new("Square")
    square.Visible = false
    square.Color = color
    square.Filled = filled or false
    square.Thickness = thickness or 2
    return square
end

------------------------------------------------
-- CREATE ESP
------------------------------------------------
local function createESP(player)
    if not player.Character then return end
    if ESP_CACHE[player] then return end

    local char = player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then return end

    local snapline = createLine(LINE_COLOR, 1.5)
    local rect = createSquare(ENEMY_COLOR, false, RECT_THICKNESS)
    local contrastRect = createSquare(CONTRAST_COLOR, false, RECT_THICKNESS)
    local hpBarBG = createSquare(Color3.fromRGB(40,40,40), true, HP_BAR_THICKNESS)
    local hpBar = createSquare(Color3.fromRGB(0,255,0), true, HP_BAR_THICKNESS)

    local bones = {}
    local bonePairs = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LowerTorso", "RightUpperLeg"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"}
    }

    for _, pair in ipairs(bonePairs) do
        local partA = char:FindFirstChild(pair[1])
        local partB = char:FindFirstChild(pair[2])
        if partA and partB then
            table.insert(bones, {partA = partA, partB = partB, line = createLine(SKELETON_COLOR, 1.5)})
        end
    end

    ESP_CACHE[player] = {
        rect = rect,
        contrastRect = contrastRect,
        hpBarBG = hpBarBG,
        hpBar = hpBar,
        root = root,
        bones = bones,
        humanoid = humanoid,
        char = char,
        snapline = snapline
    }

    humanoid.Died:Connect(function()
        if ESP_CACHE[player] then
            if ESP_CACHE[player].snapline then ESP_CACHE[player].snapline:Remove() end
            if ESP_CACHE[player].rect then ESP_CACHE[player].rect:Remove() end
            if ESP_CACHE[player].contrastRect then ESP_CACHE[player].contrastRect:Remove() end
            if ESP_CACHE[player].hpBar then ESP_CACHE[player].hpBar:Remove() end
            if ESP_CACHE[player].hpBarBG then ESP_CACHE[player].hpBarBG:Remove() end
            for _, b in pairs(ESP_CACHE[player].bones) do
                if b.line then b.line:Remove() end
            end
            ESP_CACHE[player] = nil
        end
    end)
end

------------------------------------------------
-- CLEAR ESP
------------------------------------------------
local function clearESP()
    for _, data in pairs(ESP_CACHE) do
        if data.snapline then data.snapline:Remove() end
        if data.rect then data.rect:Remove() end
        if data.contrastRect then data.contrastRect:Remove() end
        if data.hpBar then data.hpBar:Remove() end
        if data.hpBarBG then data.hpBarBG:Remove() end
        for _, b in pairs(data.bones) do
            if b.line then b.line:Remove() end
        end
    end
    table.clear(ESP_CACHE)
end

------------------------------------------------
-- BUTTON TOGGLE FUNCTIONS
------------------------------------------------
local function toggleESP()
    ESP_ENABLED = not ESP_ENABLED
    espButton.Text = ESP_ENABLED and "ESP: ON" or "ESP: OFF"
    if ESP_ENABLED then
        StarterGui:SetCore("SendNotification", {Title="ESP Ativado", Text="ESP ligado!", Duration=3})
        for _, player in ipairs(Players:GetPlayers()) do
            if isEnemy(player) then
                createESP(player)
            end
        end
    else
        StarterGui:SetCore("SendNotification", {Title="ESP Desativado", Text="ESP desligado!", Duration=3})
        clearESP()
    end
end

local function toggleAimbot()
    AIMBOT_ENABLED = not AIMBOT_ENABLED
    aimbotButton.Text = AIMBOT_ENABLED and "Aimbot: ON" or "Aimbot: OFF"
    StarterGui:SetCore("SendNotification", {Title="Aimbot", Text=AIMBOT_ENABLED and "Aimbot ativado!" or "Aimbot desligado!", Duration=3})
end

espButton.MouseButton1Click:Connect(toggleESP)
aimbotButton.MouseButton1Click:Connect(toggleAimbot)

------------------------------------------------
-- AUTO REBUILD ON RESPAWN
------------------------------------------------
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if ESP_ENABLED and isEnemy(player) then createESP(player) end
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        if ESP_ENABLED and isEnemy(player) then createESP(player) end
    end)
end

------------------------------------------------
-- UPDATE LOOP ~90 FPS
------------------------------------------------
local lastUpdate = 0
local UPDATE_INTERVAL = 0.008 -- ~125 FPS

RunService.RenderStepped:Connect(function(dt)
    lastUpdate = lastUpdate + dt
    if lastUpdate < UPDATE_INTERVAL then return end
    lastUpdate = 0

    local camPos = Camera.CFrame.Position
    local viewport = Camera.ViewportSize
    local targetParts = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg"}

    -- ESP UPDATE
    if ESP_ENABLED then
        for _, player in ipairs(Players:GetPlayers()) do
            if not isEnemy(player) then continue end
            if not ESP_CACHE[player] then createESP(player) end
            local data = ESP_CACHE[player]
            if not data or not player.Character then continue end
            local humanoid = data.humanoid
            local root = data.root
            if not humanoid or not root then continue end

            local char = data.char
            local screenPoints = {}
            for _, name in ipairs(targetParts) do
                local part = char:FindFirstChild(name)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        table.insert(screenPoints, Vector2.new(screenPos.X, screenPos.Y))
                    end
                end
            end

            if #screenPoints > 0 then
                local minX, maxX = screenPoints[1].X, screenPoints[1].X
                local minY, maxY = screenPoints[1].Y, screenPoints[1].Y
                for _, p in ipairs(screenPoints) do
                    minX = math.min(minX, p.X)
                    maxX = math.max(maxX, p.X)
                    minY = math.min(minY, p.Y)
                    maxY = math.max(maxY, p.Y)
                end

                -- retângulo normal
                data.rect.Position = Vector2.new(minX, minY)
                data.rect.Size = Vector2.new(maxX - minX, maxY - minY)
                data.rect.Visible = true

                -- retângulo contraste vermelho
                data.contrastRect.Position = Vector2.new(minX-1, minY-1)
                data.contrastRect.Size = Vector2.new(maxX - minX +2, maxY - minY +2)
                data.contrastRect.Visible = true

                -- barra de vida menor
                local height = maxY - minY
                data.hpBarBG.Size = Vector2.new(HP_BAR_THICKNESS, height)
                data.hpBarBG.Position = Vector2.new(minX - HP_BAR_THICKNESS - 2, minY)
                data.hpBarBG.Visible = true

                local hpPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
                data.hpBar.Size = Vector2.new(HP_BAR_THICKNESS, height * hpPercent)
                data.hpBar.Position = Vector2.new(minX - HP_BAR_THICKNESS - 2, minY + height * (1 - hpPercent))
                data.hpBar.Visible = true

                local rectCenter = data.rect.Position + data.rect.Size/2
                data.snapline.From = Vector2.new(viewport.X/2, viewport.Y)
                data.snapline.To = rectCenter
                data.snapline.Visible = true
            else
                data.rect.Visible = false
                data.contrastRect.Visible = false
                data.hpBar.Visible = false
                data.hpBarBG.Visible = false
                data.snapline.Visible = false
            end

            -- bones
            local dist = (camPos - root.Position).Magnitude
            if dist <= BONE_DIST_LIMIT then
                for _, b in pairs(data.bones) do
                    local posA, visA = Camera:WorldToViewportPoint(b.partA.Position)
                    local posB, visB = Camera:WorldToViewportPoint(b.partB.Position)
                    if visA and visB then
                        b.line.From = Vector2.new(posA.X, posA.Y)
                        b.line.To = Vector2.new(posB.X, posB.Y)
                        b.line.Visible = true
                    else
                        b.line.Visible = false
                    end
                end
            else
                for _, b in pairs(data.bones) do
                    b.line.Visible = false
                end
            end
        end
    end

    -- AIMBOT UPDATE
    if AIMBOT_ENABLED then
        local closestDist = AIM_FOV
        local targetPos
        for _, player in ipairs(Players:GetPlayers()) do
            if not isEnemy(player) then continue end
            if not player.Character then continue end
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local head = player.Character:FindFirstChild("Head")
           if humanoid and head then
    if not isVisible(head, player.Character) then continue end

    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
    if onScreen then
                    local mousePos = Vector2.new(Mouse.X, Mouse.Y)
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        targetPos = head.Position
                    end
                end
            end
        end
        if targetPos then
            local camCFrame = Camera.CFrame
            local direction = (targetPos - camCFrame.Position).Unit
            local newCFrame = CFrame.new(camCFrame.Position, camCFrame.Position + direction)
            Camera.CFrame = camCFrame:Lerp(newCFrame, AIM_SMOOTH)
        end
    end
end)
