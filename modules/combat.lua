--[[
    Airi Hub - Combat Module
    Target: Combat Warriors
    Focus: High Accuracy Auto Parry, Hitbox Expander, Smooth Aimbot, Stamina Bypass
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Global Config Initializer (Fallback if not set by main script)
getgenv().AiriConfig = getgenv().AiriConfig or {
    -- Combat & Parry
    AutoParry = false,
    AutoParryDelay = 0.1, -- Ditambahkan dari main.lua
    AntiParry = false,
    HitboxExpander = false,
    HitboxSize = 1,
    
    -- Movement
    InfStamina = false,
    NoJumpDelay = false,
    NoDodgeDelay = false,
    
    -- Visuals (ESP)
    ESPEnabled = false,
    ESPOpacity = 1,
    
    -- Aimbot
    AimbotEnabled = false,
    AimbotSmooth = 0.5,
    AimbotFOV = 100,
    ShowFOV = true -- Tambahan lokal untuk debugging visual
}

local CombatModule = {}

-- Fungsi Toggle yang dipanggil oleh main.lua
function CombatModule.ToggleAutoParry(state)
    getgenv().AiriConfig.AutoParry = state
end

function CombatModule.ToggleAntiParry(state)
    getgenv().AiriConfig.AntiParry = state
end

function CombatModule.ToggleHitbox(state)
    getgenv().AiriConfig.HitboxExpander = state
end

function CombatModule.ToggleAimbot(state)
    getgenv().AiriConfig.AimbotEnabled = state
end

-- Variables
local PlayerCharacters = Workspace:WaitForChild("PlayerCharacters")
local OriginalSizes = setmetatable({}, {__mode = "k"})
local OriginalTransparency = setmetatable({}, {__mode = "k"})

-- FOV Circle setup
local FOVCircle = Drawing.new("Circle")
FOVCircle.Visible = false
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Thickness = 1
FOVCircle.Filled = false
FOVCircle.Transparency = 1

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
    task.wait(0.05)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
    
    -- Short delay to prevent spamming
    task.delay(0.5, function()
        parryDebounce = false
    end)
end

-- 1. AUTO PARRY: Sound Detection (High Accuracy Trigger)
PlayerCharacters.DescendantAdded:Connect(function(descendant)
    local Config = getgenv().AiriConfig.Combat
    if not Config.AutoParry or not Config.UseSound then return end
    
    if descendant:IsA("Sound") then
        local name = descendant.Name
        -- Pattern match for attack sounds: "1", "2", "3", "4"
        if name == "1" or name == "2" or name == "3" or name == "4" then
            -- Verify it's within a Hitbox instance
            if descendant.Parent and descendant.Parent.Name == "Hitbox" then
                local enemyChar = descendant:FindFirstAncestorOfClass("Model")
                
                -- Ensure it's an actual enemy character
                if enemyChar and enemyChar.Parent == PlayerCharacters and enemyChar.Name ~= LocalPlayer.Name then
                    local localChar = getLocalCharacter()
                    if localChar and localChar:FindFirstChild("HumanoidRootPart") and enemyChar:FindFirstChild("HumanoidRootPart") then
                        local dist = (localChar.HumanoidRootPart.Position - enemyChar.HumanoidRootPart.Position).Magnitude
                        
                        -- Range Check
                        if dist <= Config.ParryRange then
                            triggerParry()
                        end
                    end
                end
            end
        end
    end
end)

-- 1. AUTO PARRY: Animation Detection (Secondary Verification)
local function setupAnimationDetection(enemyChar)
    if enemyChar.Name == LocalPlayer.Name then return end
    
    -- Wait for components to load
    task.spawn(function()
        local humanoid = enemyChar:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        
        local animator = humanoid:WaitForChild("Animator", 10)
        if not animator then return end
        
        animator.AnimationPlayed:Connect(function(animationTrack)
            local Config = getgenv().AiriConfig.Combat
            if not Config.AutoParry or not Config.UseAnimation then return end
            
            local animName = animationTrack.Animation.Name:lower()
            -- Match core slash animations
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
    end)
end

-- Init animation hooks for existing players
for _, char in ipairs(PlayerCharacters:GetChildren()) do
    setupAnimationDetection(char)
end

-- Init animation hooks for new players
PlayerCharacters.ChildAdded:Connect(setupAnimationDetection)


-- 2. HITBOX EXPANDER: Logic & Restoration
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


-- 3. AIMBOT: Target Selection based on FOV and Cursor Proximity
local function getClosestToCursor(config)
    local closestChar = nil
    local shortestDist = config.FOV
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


-- ⚙️ Main RenderStepped Loop (Smooth Aimbot & FOV Drawing)
RunService.RenderStepped:Connect(function(deltaTime)
    local Config = getgenv().AiriConfig.Combat

    -- Update FOV Drawing
    if Config.AimbotEnabled and Config.ShowFOV then
        FOVCircle.Visible = true
        FOVCircle.Radius = Config.AimbotFOV
        FOVCircle.Position = UserInputService:GetMouseLocation()
    else
        FOVCircle.Visible = false
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

-- 4. STAMINA BYPASS (No Math.Huge)
-- Hooking internal OOP objects using Garbage Collection scanning
task.spawn(function()
    if not getgc then return end
    
    local success, err = pcall(function()
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" then
                -- Disable Drain completely by overwriting the class method
                if rawget(obj, "enableDrain") and type(rawget(obj, "enableDrain")) == "function" then
                    obj.enableDrain = function() return end
                end
                
                -- Force instant recovery
                if rawget(obj, "_maxStamina") and rawget(obj, "gainPerSecond") then
                    obj.gainPerSecond = 9999
                    obj.gainDelay = 0
                end
            end
        end
    end)
    
    if not success then
        warn("[Airi Hub] Failed to hook stamina via GC: ", tostring(err))
    end
end)

-- Module Cleanup Logic
function CombatModule:Unload()
    FOVCircle:Remove()
    for part, _ in pairs(OriginalSizes) do
        resetHitbox(part)
    end
end

return CombatModule
