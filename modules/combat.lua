--[[
    Airi Hub - Combat Module
    Target: Combat Warriors
    Focus: High Accuracy Auto Parry, Hitbox Expander, Smooth Aimbot
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

-- Variables
local PlayerCharacters = Workspace:WaitForChild("PlayerCharacters")
local OriginalSizes = setmetatable({}, {__mode = "k"})
local OriginalTransparency = setmetatable({}, {__mode = "k"})

-- FOV Circle setup dengan Safe Check untuk executor yang tidak mensupport Drawing (misal: executor Android)
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

-- Utility: Get Local Character
local function getLocalCharacter()
    return PlayerCharacters:FindFirstChild(LocalPlayer.Name)
end

-- Utility: Trigger Parry
local parryDebounce = false
local function triggerParry()
    if parryDebounce then return end
    parryDebounce = true
    
    -- Simulate 'F' key press via VirtualInputManager
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
    task.wait(getgenv().AiriConfig.AutoParryDelay)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    
    -- Short delay to prevent spamming
    task.delay(0.5, function()
        parryDebounce = false
    end)
end

-- HITBOX EXPANDER: Logic & Restoration
local function resetHitbox(part)
    if not part then return end
    if OriginalSizes[part] then
        part.Size = OriginalSizes[part]
        OriginalSizes[part] = nil
    end
    if OriginalTransparency[part] then
        part.Transparency = OriginalTransparency[part]
        OriginalTransparency[part] = nil
    end
    part.CanCollide = true
end

local function applyHitbox(char, config)
    if char.Name == LocalPlayer.Name then return end
    
    local part = char:FindFirstChild(config.HitboxPart)
    if part then
        -- Cache original properties
        if not OriginalSizes[part] then
            OriginalSizes[part] = part.Size
            OriginalTransparency[part] = part.Transparency
        end
        
        -- Expand safely
        part.Size = Vector3.new(config.HitboxSize, config.HitboxSize, config.HitboxSize)
        part.Transparency = 0.65 -- Visual indicator that it's expanded
        part.CanCollide = false  -- Prevent getting stuck on expanded hitboxes
    end
end

-- AIMBOT: Target Selection based on FOV and Cursor Proximity
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

-- 1. AUTO PARRY: Animation Detection
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
            if animName:find("slash") then
                local localChar = getLocalCharacter()
                if localChar and localChar:FindFirstChild("HumanoidRootPart") and enemyChar:FindFirstChild("HumanoidRootPart") then
                    local dist = (localChar.HumanoidRootPart.Position - enemyChar.HumanoidRootPart.Position).Magnitude
                    
                    if dist <= Config.ParryRange then
                        triggerParry()
                    end
                end
            end
        end)
        table.insert(Connections, animConn)
    end)
end

-- ==========================================
-- MAIN INITIALIZATION
-- ==========================================
function CombatModule.Init()
    -- Init animation hooks for existing players
    for _, char in ipairs(PlayerCharacters:GetChildren()) do
        setupAnimationDetection(char)
    end

    -- Init animation hooks for new players
    local addedConn = PlayerCharacters.ChildAdded:Connect(setupAnimationDetection)
    table.insert(Connections, addedConn)

    -- AUTO PARRY: Sound Detection
    local descConn = PlayerCharacters.DescendantAdded:Connect(function(descendant)
        local Config = getgenv().AiriConfig
        if not Config.AutoParry or not Config.UseSound then return end
        
        if descendant:IsA("Sound") then
            local name = descendant.Name
            if name == "1" or name == "2" or name == "3" or name == "4" then
                if descendant.Parent and descendant.Parent.Name == "Hitbox" then
                    local enemyChar = descendant:FindFirstAncestorOfClass("Model")
                    
                    if enemyChar and enemyChar.Parent == PlayerCharacters and enemyChar.Name ~= LocalPlayer.Name then
                        local localChar = getLocalCharacter()
                        if localChar and localChar:FindFirstChild("HumanoidRootPart") and enemyChar:FindFirstChild("HumanoidRootPart") then
                            local dist = (localChar.HumanoidRootPart.Position - enemyChar.HumanoidRootPart.Position).Magnitude
                            
                            if dist <= Config.ParryRange then
                                triggerParry()
                            end
                        end
                    end
                end
            end
        end
    end)
    table.insert(Connections, descConn)

    -- ⚙️ Main RenderStepped Loop (Smooth Aimbot & Hitbox Drawing)
    local renderConn = RunService.RenderStepped:Connect(function(deltaTime)
        local Config = getgenv().AiriConfig

        -- Update FOV Drawing
        if FOVCircle then
            if Config.AimbotEnabled and Config.ShowFOV then
                FOVCircle.Visible = true
                FOVCircle.Radius = Config.AimbotFOV
                FOVCircle.Position = UserInputService:GetMouseLocation()
            else
                FOVCircle.Visible = false
            end
        end

        -- Update Hitboxes
        for _, char in ipairs(PlayerCharacters:GetChildren()) do
            if char.Name ~= LocalPlayer.Name then
                local hitboxPart = Config.HitboxPart or "HumanoidRootPart"
                local partTarget = char:FindFirstChild(hitboxPart)
                local alternatePart = (hitboxPart == "Head") and char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                
                if Config.HitboxExpander then
                    applyHitbox(char, Config)
                    resetHitbox(alternatePart) 
                else
                    resetHitbox(partTarget)
                    resetHitbox(alternatePart)
                end
            end
        end

        -- Update Aimbot (Requires Right Click / MouseButton2)
        if Config.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local target = getClosestToCursor(Config)
            if target and target:FindFirstChild(Config.HitboxPart or "HumanoidRootPart") then
                local targetPos = target[Config.HitboxPart or "HumanoidRootPart"].Position
                local currentCFrame = Camera.CFrame
                local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
                
                -- Smooth interpolation (Lerp)
                Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.AimbotSmooth * deltaTime * 10)
            end
        end
    end)
    table.insert(Connections, renderConn)
end

-- Module Cleanup Logic
function CombatModule:Unload()
    if FOVCircle then
        FOVCircle:Remove()
    end
    
    for _, conn in ipairs(Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)

    for part, _ in pairs(OriginalSizes) do
        resetHitbox(part)
    end
end

return CombatModule
