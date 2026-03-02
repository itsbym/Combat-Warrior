--[[
    Airi Hub - Combat Module V2.8 (CRASH FIXED)
    Target: Combat Warriors
    Focus: Zero Geometry, Instant Reaction, Native Input
    
    CHANGELOG V2.8:
    - FIX: PlayerCharacters wrapped with pcall (WaitForChild)
    - FIX: All setupAnimationDetection calls wrapped with pcall
    - FIX: getClosestToCursor uses safe getPlayerCharacters()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CombatModule = {}
local Connections = {}

-- Safe WaitForChild for PlayerCharacters
local PlayerCharacters = nil
local function getPlayerCharacters()
    if PlayerCharacters then return PlayerCharacters end
    local success, result = pcall(function()
        return Workspace:WaitForChild("PlayerCharacters", 10)
    end)
    if success then
        PlayerCharacters = result
    else
        warn("[Airi Hub] PlayerCharacters not found: " .. tostring(result))
    end
    return PlayerCharacters
end

local function getLocalCharacter()
    local pc = getPlayerCharacters()
    if not pc then return LocalPlayer.Character end
    return pc:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
end

-- ==========================================
-- NATIVE INPUT SIMULATOR
-- ==========================================
local function simulateParryKey()
    local holdTime = getgenv().AiriConfig.AutoParryDelay or 0.1
    if keypress and keyrelease then
        pcall(keypress, 0x46) -- 0x46 = 'F'
        task.wait(holdTime)
        pcall(keyrelease, 0x46)
    else
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
        task.wait(holdTime)
        vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    end
end

-- ==========================================
-- RAW AUTO PARRY ENGINE
-- ==========================================
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

    -- Batas jarak wajar agar tidak parry musuh di ujung map
    local dist = (localRoot.Position - enemyRoot.Position).Magnitude
    if dist > Config.ParryRange then return end

    parryDebounce = true

    task.spawn(function()
        -- Micro-delay (10-30ms) agar sinkron dengan hitbox animasi
        task.wait(math.random(10, 30) / 1000)
        
        -- Validasi jarak terakhir
        if localRoot and enemyRoot and (localRoot.Position - enemyRoot.Position).Magnitude <= Config.ParryRange + 2 then
            simulateParryKey()
        end
        
        -- Cooldown parry
        task.delay(0.5, function()
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
    
    local pc = getPlayerCharacters()
    if not pc then return nil end

    for _, char in ipairs(pc:GetChildren()) do
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
    print("[Airi Hub] Combat V2.8 initializing...")
    
    local pc = getPlayerCharacters()
    if not pc then
        warn("[Airi Hub] Combat: PlayerCharacters not available")
        return
    end

    for _, char in ipairs(pc:GetChildren()) do
        pcall(setupAnimationDetection, char)
    end

    local addedConn = pc.ChildAdded:Connect(function(char)
        pcall(setupAnimationDetection, char)
    end)
    table.insert(Connections, addedConn)

    local descConn = PlayerCharacters.DescendantAdded:Connect(function(descendant)
        local Config = getgenv().AiriConfig
        if not Config.AutoParry or not Config.UseSound then return end
        
        local pc = getPlayerCharacters()
        if not pc then return end
        
        if descendant:IsA("Sound") then
            local name = descendant.Name
            if name == "1" or name == "2" or name == "3" or name == "4" then
                if descendant.Parent and descendant.Parent.Name == "Hitbox" then
                    local enemyChar = descendant:FindFirstAncestorOfClass("Model")
                    if enemyChar and enemyChar.Parent == pc and enemyChar.Name ~= LocalPlayer.Name then
                        triggerParry(enemyChar)
                    end
                end
            end
        end
    end)
    table.insert(Connections, descConn)

    local renderConn = RunService.RenderStepped:Connect(function(deltaTime)
        local Config = getgenv().AiriConfig

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
    
    print("[Airi Hub] Combat V2.8 ACTIVE.")
end

function CombatModule:Unload()
    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)
end

return CombatModule