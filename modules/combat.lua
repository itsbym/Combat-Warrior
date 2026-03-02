--[[
    Airi Hub - Combat Module V2.3 (SERVER-SAFE)
    Target: Combat Warriors
    Focus: Ping-Compensated & Humanized Auto Parry, Safe Aimbot
    
    CHANGELOG V2.3:
    - DITAMBAHKAN: Humanizer Delay (30-120ms) pada Auto Parry agar tidak terdeteksi server sebagai bot (0ms reaction).
    - DITAMBAHKAN: Facing Check (Dot Product) - hanya parry jika musuh menghadap ke arah kita.
    - DIHAPUS: Hitbox Expander dimatikan total di level engine karena memicu Server-Side Reach Ban (Error 267).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CombatModule = {}
local Connections = {}

local PlayerCharacters = Workspace:WaitForChild("PlayerCharacters")

-- FOV Circle setup
local FOVCircle
if Drawing then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Visible = false
        FOVCircle.Color = Color3.fromRGB(255, 255, 255)
        FOVCircle.Thickness = 1
        FOVCircle.Filled = false
        FOVCircle.Transparency = 1
    end)
end

local function getLocalCharacter()
    return PlayerCharacters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
end

-- ==========================================
-- SMART AUTO PARRY ENGINE (SERVER SAFE)
-- ==========================================

-- Cek apakah musuh menghadap ke kita (mencegah parry saat musuh serang orang lain)
local function isFacing(enemyChar, localChar)
    local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not enemyRoot or not localRoot then return false end
    
    local dirToPlayer = (localRoot.Position - enemyRoot.Position).Unit
    local enemyLook = enemyRoot.CFrame.LookVector
    local dotProduct = enemyLook:Dot(dirToPlayer)
    
    -- > 0.3 berarti musuh melihat ke arah kita (sudut ~70 derajat)
    return dotProduct > 0.3
end

local parryDebounce = false
local function triggerParry(enemyChar)
    if parryDebounce then return end
    
    local Config = getgenv().AiriConfig
    if not Config.AutoParry then return end

    local localChar = getLocalCharacter()
    if not localChar then return end

    local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not enemyRoot or not localRoot then return end

    -- 1. Distance Check
    local dist = (localRoot.Position - enemyRoot.Position).Magnitude
    if dist > Config.ParryRange then return end

    -- 2. Facing Check
    if not isFacing(enemyChar, localChar) then return end

    parryDebounce = true

    -- 3. Humanizer & Ping Compensation (MENCEGAH SERVER BAN)
    -- Server mendeteksi reaksi 0ms. Kita tambahkan delay acak layaknya manusia.
    local humanizerDelay = math.random(30, 120) / 1000
    
    task.spawn(function()
        task.wait(humanizerDelay)
        
        -- Validasi ulang jarak setelah delay (berjaga jika musuh dash menjauh)
        if localRoot and enemyRoot then
            local newDist = (localRoot.Position - enemyRoot.Position).Magnitude
            if newDist <= Config.ParryRange + 3 then
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(Config.AutoParryDelay or 0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end
        end
        
        -- Cooldown parry agar tidak spam
        task.delay(0.6, function()
            parryDebounce = false
        end)
    end)
end

local function setupAnimationDetection(enemyChar)
    if enemyChar.Name == LocalPlayer.Name then return end
    
    task.spawn(function()
        local humanoid = enemyChar:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        
        local animator = humanoid:WaitForChild("Animator", 10)
        if not animator then return end
        
        local animConn = animator.AnimationPlayed:Connect(function(animationTrack)
            local Config = getgenv().AiriConfig
            if not Config.AutoParry or not Config.UseAnimation then return end
            
            local animName = animationTrack.Animation.Name:lower()
            if animName:find("slash") or animName:find("swing") or animName:find("attack") then
                triggerParry(enemyChar)
            end
        end)
        table.insert(Connections, animConn)
    end)
end

-- ==========================================
-- SAFE AIMBOT ENGINE
-- ==========================================
local function getClosestToCursor(config)
    local closestChar = nil
    local shortestDist = config.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, char in ipairs(PlayerCharacters:GetChildren()) do
        if char.Name ~= LocalPlayer.Name and char:FindFirstChild("HumanoidRootPart") then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local vector, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
                
                if onScreen then
                    local dist = (Vector2.new(vector.X, vector.Y) - mousePos).Magnitude
                    if dist < shortestDist then
                        closestChar = char
                        shortestDist = dist
                    end
                end
            end
        end
    end
    return closestChar
end

-- ==========================================
-- MAIN INITIALIZATION
-- ==========================================
function CombatModule.Init()
    print("[Airi Hub] Combat V2.3 initializing...")

    for _, char in ipairs(PlayerCharacters:GetChildren()) do
        setupAnimationDetection(char)
    end

    local addedConn = PlayerCharacters.ChildAdded:Connect(setupAnimationDetection)
    table.insert(Connections, addedConn)

    local descConn = PlayerCharacters.DescendantAdded:Connect(function(descendant)
        local Config = getgenv().AiriConfig
        if not Config.AutoParry or not Config.UseSound then return end
        
        if descendant:IsA("Sound") then
            local name = descendant.Name
            if name == "1" or name == "2" or name == "3" or name == "4" then
                if descendant.Parent and descendant.Parent.Name == "Hitbox" then
                    local enemyChar = descendant:FindFirstAncestorOfClass("Model")
                    if enemyChar and enemyChar.Parent == PlayerCharacters and enemyChar.Name ~= LocalPlayer.Name then
                        triggerParry(enemyChar)
                    end
                end
            end
        end
    end)
    table.insert(Connections, descConn)

    local renderConn = RunService.RenderStepped:Connect(function(deltaTime)
        local Config = getgenv().AiriConfig

        if FOVCircle then
            if Config.AimbotEnabled and Config.ShowFOV then
                FOVCircle.Visible = true
                FOVCircle.Radius = Config.AimbotFOV
                FOVCircle.Position = UserInputService:GetMouseLocation()
            else
                FOVCircle.Visible = false
            end
        end

        if Config.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local target = getClosestToCursor(Config)
            if target and target:FindFirstChild("HumanoidRootPart") then
                local targetPos = target.HumanoidRootPart.Position
                local currentCFrame = Camera.CFrame
                local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
                Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.AimbotSmooth * deltaTime * 10)
            end
        end
    end)
    table.insert(Connections, renderConn)
    
    print("[Airi Hub] Combat V2.3 ACTIVE.")
end

function CombatModule:Unload()
    if FOVCircle then FOVCircle:Remove() end
    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)
end

return CombatModule
