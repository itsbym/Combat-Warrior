--[[
    Airi Hub - Combat Module V3.0 (OVERHAUL)
    Target: Combat Warriors
    Focus: Hitbox Expander, Aimbot, Auto Parry, Anti Parry
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
    local success, result = pcall(function() return Workspace:WaitForChild("PlayerCharacters", 10) end)
    if success then PlayerCharacters = result end
    return PlayerCharacters
end

local function getLocalCharacter()
    local pc = getPlayerCharacters()
    if not pc then return LocalPlayer.Character end
    return pc:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
end

-- ==========================================
-- FILTERING / VALIDATION ENGINE
-- ==========================================
local function isListValid(listStr, targetStr)
    if not listStr or listStr == "" then return false end
    local targets = string.split(string.lower(listStr), ",")
    for _, t in ipairs(targets) do
        if string.find(string.lower(targetStr), string.match(t, "^%s*(.-)%s*$")) then return true end
    end
    return false
end

local function isValidTarget(char, teamCheck, whitelistPlayer, blacklistPlayer, whitelistTeam, blacklistTeam)
    if not char or not char.Parent or char.Name == LocalPlayer.Name then return false end
    
    local player = Players:GetPlayerFromCharacter(char) or Players:FindFirstChild(char.Name)
    if not player then return true end -- NPCs are valid targets

    if blacklistPlayer and isListValid(blacklistPlayer, player.Name) then return true end
    if whitelistPlayer and isListValid(whitelistPlayer, player.Name) then return false end

    if teamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    
    if player.Team then
        local teamName = player.Team.Name
        if whitelistTeam and isListValid(whitelistTeam, teamName) then return false end
    end
    
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    
    return true
end

-- ==========================================
-- NATIVE INPUT SIMULATOR
-- ==========================================
local function simulateParryKey()
    local holdTime = getgenv().AiriConfig.AutoParryDelay or 0.1
    if keypress and keyrelease then
        pcall(keypress, 0x46)
        task.wait(holdTime)
        pcall(keyrelease, 0x46)
    else
        local vim = game:GetService("VirtualInputManager")
        pcall(function()
            vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
            task.wait(holdTime)
            vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
        end)
    end
end

local function simulateAntiParryUnequip()
    local localChar = getLocalCharacter()
    if localChar then
        local humanoid = localChar:FindFirstChild("Humanoid")
        if humanoid then
            pcall(function() humanoid:UnequipTools() end)
        end
    end
end

local autoEquipDebounce = false
local function handleAutoEquip()
    if autoEquipDebounce then return end
    local Config = getgenv().AiriConfig
    if not Config.AutoEquip then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local humanoid = localChar:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end
    
    local hasTool = localChar:FindFirstChildOfClass("Tool")
    if not hasTool then
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            local tool = backpack:FindFirstChildOfClass("Tool")
            if tool then
                autoEquipDebounce = true
                task.delay(Config.AutoEquipDelay, function()
                    if Config.AutoEquip and humanoid.Health > 0 and not localChar:FindFirstChildOfClass("Tool") then
                        pcall(function() humanoid:EquipTool(tool) end)
                    end
                    autoEquipDebounce = false
                end)
            end
        end
    end
end

-- ==========================================
-- AUTO PARRY & ANTI PARRY ENGINE
-- ==========================================
local parryDebounce = false
local function triggerParry(enemyChar)
    if parryDebounce then return end
    
    local Config = getgenv().AiriConfig
    if not Config.AutoParry then return end

    if not isValidTarget(enemyChar, Config.AutoParryTeamCheck, Config.AutoParryWhitelistPlayer, Config.AutoParryBlacklistPlayer, Config.AutoParryWhitelistTeam, Config.AutoParryBlacklistTeam) then return end

    local localChar = getLocalCharacter()
    if not localChar then return end

    local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not enemyRoot or not localRoot then return end

    local dist = (localRoot.Position - enemyRoot.Position).Magnitude
    if dist > Config.AutoParryRange then return end
    
    local enemyPos, onScreen = Camera:WorldToViewportPoint(enemyRoot.Position)
    if not onScreen and Config.AutoParryFOV < 360 then return end
    
    if Config.AutoParryFOV < 360 then
        local mousePos = UserInputService:GetMouseLocation()
        local fovDist = (Vector2.new(enemyPos.X, enemyPos.Y) - mousePos).Magnitude
        if fovDist > Config.AutoParryFOV then return end
    end
    
    if math.random(1, 100) > Config.AutoParryChance then return end

    parryDebounce = true

    task.spawn(function()
        task.wait(math.random(10, 30) / 1000)
        if localRoot and enemyRoot and (localRoot.Position - enemyRoot.Position).Magnitude <= Config.AutoParryRange + 2 then
            simulateParryKey()
        end
        task.delay(0.5, function() parryDebounce = false end)
    end)
end

local antiParryDebounce = false
local function triggerAntiParry(enemyChar)
    if antiParryDebounce then return end
    local Config = getgenv().AiriConfig
    if not Config.AntiParry then return end
    
    local localChar = getLocalCharacter()
    if not localChar then return end

    local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not enemyRoot or not localRoot then return end

    local dist = (localRoot.Position - enemyRoot.Position).Magnitude
    if dist > 20 then return end
    
    antiParryDebounce = true
    simulateAntiParryUnequip()
    task.delay(1, function() antiParryDebounce = false end)
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
            local animName = animationTrack.Animation.Name:lower()
            
            if Config.AutoParry and (Config.AutoParryDetection == "Animation" or Config.AutoParryDetection == "Both") then
                if animName:find("slash") or animName:find("swing") or animName:find("attack") or animName:find("hit") or animName:find("strike") then
                    triggerParry(enemyChar)
                end
            end
            
            if Config.AntiParry then
                if animName:find("parry") or animName:find("block") or animName:find("deflect") then
                    triggerAntiParry(enemyChar)
                end
            end
        end)
        table.insert(Connections, animConn)
    end)
end

-- ==========================================
-- AIMBOT ENGINE
-- ==========================================
local function getClosestForAimbot()
    local Config = getgenv().AiriConfig
    local closestChar = nil
    local shortestDist = Config.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()
    
    local pc = getPlayerCharacters()
    if not pc then return nil end

    for _, char in ipairs(pc:GetChildren()) do
        if isValidTarget(char, Config.AimbotTeamCheck, nil, nil, Config.AimbotWhitelistTeam, Config.AimbotBlacklistTeam) then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
            if root then
                local vector, onScreen = Camera:WorldToViewportPoint(root.Position)
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
-- HITBOX EXPANDER ENGINE 
-- ==========================================
local hue = 0
local OriginalSizes = {}

local function ApplyHitboxExtender(deltaTime)
    local Config = getgenv().AiriConfig
    if not Config then return end

    local pc = getPlayerCharacters()
    if not pc then return end
    
    -- Rainbow sync
    if Config.HitboxColorMode == "Rainbow" then
        hue = hue + (deltaTime * Config.HitboxRainbowSpeed * 0.1)
        if hue >= 1 then hue = 0 end
    end
    
    local currentColor = Config.HitboxColorMode == "Rainbow" and Color3.fromHSV(hue, 1, 1) or Config.HitboxStaticColor

    for _, char in ipairs(pc:GetChildren()) do
        if char.Name ~= LocalPlayer.Name then
            local humanoid = char:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local targetParts = {}
                if Config.HitboxTarget == "Head" then table.insert(targetParts, char:FindFirstChild("Head"))
                elseif Config.HitboxTarget == "Torso" then 
                    table.insert(targetParts, char:FindFirstChild("Torso"))
                    table.insert(targetParts, char:FindFirstChild("UpperTorso"))
                    table.insert(targetParts, char:FindFirstChild("LowerTorso"))
                elseif Config.HitboxTarget == "Arms" then
                    table.insert(targetParts, char:FindFirstChild("Left Arm"))
                    table.insert(targetParts, char:FindFirstChild("Right Arm"))
                    table.insert(targetParts, char:FindFirstChild("LeftUpperArm"))
                    table.insert(targetParts, char:FindFirstChild("RightUpperArm"))
                elseif Config.HitboxTarget == "Legs" then
                    table.insert(targetParts, char:FindFirstChild("Left Leg"))
                    table.insert(targetParts, char:FindFirstChild("Right Leg"))
                    table.insert(targetParts, char:FindFirstChild("LeftUpperLeg"))
                    table.insert(targetParts, char:FindFirstChild("RightUpperLeg"))
                else
                    table.insert(targetParts, char:FindFirstChild("HumanoidRootPart"))
                end

                for _, part in ipairs(targetParts) do
                    if part and part:IsA("BasePart") then
                        if not OriginalSizes[part] then OriginalSizes[part] = part.Size end

                        pcall(function()
                            if Config.HitboxExpander then
                                part.Size = Vector3.new(Config.HitboxExpanderSize, Config.HitboxExpanderSize, Config.HitboxExpanderSize)
                                part.Transparency = Config.HitboxOpacity
                                part.Color = currentColor
                                part.CanCollide = false
                                part.Material = Enum.Material.Neon
                            else
                                part.Size = OriginalSizes[part]
                                part.Transparency = part.Name == "HumanoidRootPart" and 1 or 0
                                part.Material = Enum.Material.Plastic
                            end
                        end)
                    end
                end
            end
        end
    end
end

-- ==========================================
-- MAIN INITIALIZATION
-- ==========================================
function CombatModule.Init()
    print("[Airi Hub] Combat V3.0 initializing...")
    
    local pc = getPlayerCharacters()
    if not pc then
        warn("[Airi Hub] Combat: PlayerCharacters not available")
        return
    end

    for _, char in ipairs(pc:GetChildren()) do pcall(setupAnimationDetection, char) end
    local addedConn = pc.ChildAdded:Connect(function(char) pcall(setupAnimationDetection, char) end)
    table.insert(Connections, addedConn)

    -- Sound Detection for Parry
    local descConn = pc.DescendantAdded:Connect(function(descendant)
        local Config = getgenv().AiriConfig
        if not Config.AutoParry or not (Config.AutoParryDetection == "Sound" or Config.AutoParryDetection == "Both") then return end
        
        if descendant:IsA("Sound") then
            local name = descendant.Name
            if name == "1" or name == "2" or name == "3" or name == "4" then
                if descendant.Parent and descendant.Parent.Name == "Hitbox" then
                    local enemyChar = descendant:FindFirstAncestorOfClass("Model")
                    if enemyChar and enemyChar.Name ~= LocalPlayer.Name then
                        triggerParry(enemyChar)
                    end
                end
            end
        end
    end)
    table.insert(Connections, descConn)

    -- Engine Loop
    local renderConn = RunService.RenderStepped:Connect(function(deltaTime)
        local Config = getgenv().AiriConfig

        -- Hitbox Sub-system
        pcall(ApplyHitboxExtender, deltaTime)
        
        -- Auto Equip Sub-system
        pcall(handleAutoEquip)

        -- Aimbot Sub-system
        if Config.AimbotEnabled then
            local isTriggered = false
            if Config.AimbotMode == "Hold" then
                isTriggered = Config.AimbotEnabled -- Usually tracking is done via direct bool
            elseif Config.AimbotMode == "Trigger" then
                isTriggered = true -- In this simplistic exploit form (usually external input modifies it)
            else
                isTriggered = true
            end

            -- Actually require MouseButton2 if using mouse override, else always true if Enabled
            if Config.AimbotMethod == "Mouse" and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                isTriggered = false
            end
            
            if isTriggered then
                local target = getClosestForAimbot()
                if target and target:FindFirstChild("HumanoidRootPart") then
                    local targetPos = (target:FindFirstChild("Head") or target.HumanoidRootPart).Position
                    local currentCFrame = Camera.CFrame
                    local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
                    if Config.AimbotSmooth > 0 then
                        Camera.CFrame = currentCFrame:Lerp(targetCFrame, math.clamp(Config.AimbotSmooth * deltaTime * 10, 0, 1))
                    else
                        Camera.CFrame = targetCFrame
                    end
                end
            end
        end
    end)
    table.insert(Connections, renderConn)
    
    print("[Airi Hub] Combat V3.0 ACTIVE.")
end

function CombatModule:Unload()
    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)
    
    -- Revert Hitboxes
    for part, originalSize in pairs(OriginalSizes) do
        if part and part.Parent then
            pcall(function()
                part.Size = originalSize
                part.Transparency = part.Name == "HumanoidRootPart" and 1 or 0
                part.Material = Enum.Material.Plastic
            end)
        end
    end
    table.clear(OriginalSizes)
end

return CombatModule