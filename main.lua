-- Inisialisasi Global Config
getgenv().AiriConfig = getgenv().AiriConfig or {
    AutoParry = false, AutoParryDelay = 0.1, AntiParry = false,
    UseSound = true, UseAnimation = true, ParryRange = 15,
    HitboxExpander = false, HitboxSize = 1, HitboxPart = "HumanoidRootPart",
    InfStamina = false, NoJumpDelay = false, NoDodgeDelay = false, NoFallDamage = true, AntiRagdoll = false,
    ESPEnabled = false, ESPOpacity = 1, ESPBox = true, ESPBoxStyle = "Normal",
    ESPChams = false, ESPSkeleton = false, ESPTracers = false, ESPNames = true, ESPDistances = true, ESPHealthBar = true,
    AimbotEnabled = false, AimbotSmooth = 0.5, AimbotFOV = 100, ShowFOV = true
}
local Config = getgenv().AiriConfig

print("[Airi Hub] Starting Engine...")

-- Helper murni GitHub untuk memuat UI
local function fetchLuna()
    print("[Airi Hub] DEBUG: Fetching Luna UI from GitHub sources...")
    
    local sources = {
        "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua",
        "https://raw.githubusercontent.com/AmeloxRUS/guiluna/refs/heads/main/luna.lua",
    }

    for _, url in ipairs(sources) do
        print("[Airi Hub] DEBUG: Trying GitHub URL: " .. url)
        local ok, code = pcall(game.HttpGet, game, url, true)
        print("[Airi Hub] DEBUG: HttpGet status: " .. tostring(ok))
        
        if ok and type(code) == "string" and #code > 0 then
            print("[Airi Hub] DEBUG: Got code from GitHub, compiling...")
            local success, luaObj = pcall(loadstring, code)
            print("[Airi Hub] DEBUG: Loadstring status: " .. tostring(success))
            
            if success and type(luaObj) == "function" then
                print("[Airi Hub] DEBUG: Executing Luna function...")
                local result = luaObj()
                print("[Airi Hub] DEBUG: Luna result type: " .. type(result))
                
                if type(result) == "table" then
                    print("[Airi Hub] SUCCESS: Loaded Luna from GitHub!")
                    return true, result
                end
            end
        end
    end

    return false, "Semua sumber GitHub gagal dimuat"
end

print("[Airi Hub] Fetching Luna UI...")
local successUI, Luna = fetchLuna()
if not successUI or type(Luna) ~= "table" then
    warn("[Airi Hub] UI gagal dimuat! Error: " .. tostring(Luna))
    return
end

print("[Airi Hub] UI berhasil diunduh. Membangun Window...")

local Window = Luna:CreateWindow({
    Name = "Combat Warriors | Airi Hub",
    Subtitle = "Airi Script",
    LogoID = "6031097225",
    LoadingEnabled = true,
    LoadingTitle = "Airi Hub Interface",
    LoadingSubtitle = "Loading Modules...",
    KeySystem = false,
    Color = Color3.fromRGB(191, 64, 191)
})

if not Window then
    warn("[Airi Hub] Gagal membuat jendela UI; objek Window nil")
    return
end

pcall(function()
    if Window and Window.Elements and Window.Elements.Parent then
        Window.Elements.Parent.Visible = true
    end
end)

local Tabs = {}
Tabs.Combat = Window:CreateTab({ Name = "Combat", Icon = "code", ImageSource = "Material", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "group_work", ImageSource = "Material", ShowTitle = true })
Tabs.Visuals = Window:CreateTab({ Name = "Visuals", Icon = "list", ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings_phone", ImageSource = "Material", ShowTitle = true })

Window:CreateHomeTab()

print("[Airi Hub] Initializing modules asynchronously...")

-- Fungsi Helper untuk Load Module (HANYA GITHUB & EMBEDDED FALLBACK)
local function loadModule(name)
    print("[Airi Hub] Loading module: " .. name)
    
    -- STRATEGI 1: Murni dari GitHub (dengan cache-bypass)
    print("[Airi Hub] Trying GitHub source...")
    local url = "https://raw.githubusercontent.com/itsbym/Combat-Warrior/main/modules/" .. name .. ".lua?t=" .. tostring(tick())
    
    local success, result = pcall(function()
        local code = game:HttpGet(url)
        if not code or #code == 0 then return nil end
        print("[Airi Hub] Fetched " .. name .. " from GitHub (" .. #code .. " bytes)")
        return loadstring(code, "=" .. name)()
    end)
    
    if success and result and type(result) == "table" then
        print("[Airi Hub] SUCCESS: Module " .. name .. " loaded from GitHub")
        return result
    end
    
    -- STRATEGI 2: Embedded modules sebagai fallback (Tanpa File Lokal Sama Sekali)
    print("[Airi Hub] GitHub load failed, attempting embedded fallback for: " .. name)
    
    local embeddedModules = {
        antidetect = function()
            --[[EMBEDDED_ANTIDETECT_MODULE_START]]
            local Players = game:GetService("Players")
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local VirtualUser = game:GetService("VirtualUser")
            local RunService = game:GetService("RunService")
            local CollectionService = game:GetService("CollectionService")
            local TweenService = game:GetService("TweenService")
            local LocalPlayer = Players.LocalPlayer
            local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
            local AntiDetectModule = {}
            local OldNamecall = nil
            local OldKick = nil
            local OldIndex = nil
            local OldNewIndex = nil
            local Connections = {}
            local SpoofedBodyMovers = setmetatable({}, {__mode = "k"})
            local BLOCKED_REMOTES = {["logkick"] = true,["logactrigger"] = true, ["ban"] = true, ["kick"] = true, ["anticheat"] = true, ["exploit"] = true, ["crash"] = true, ["detect"] = true}
            local BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
            local REQUIRED_BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
            local SpoofedStores = {}
            function AntiDetectModule.Init()
                local idledConn = LocalPlayer.Idled:Connect(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
                table.insert(Connections, idledConn)
                pcall(function()
                    if PlayerGui then
                        local notifConn = PlayerGui.ChildAdded:Connect(function(child)
                            if child:IsA("ScreenGui") and (child.Name:lower():find("notif") or child.Name:lower():find("ac") or child.Name:lower():find("punish")) then
                                task.wait() child.Enabled = false child:Destroy()
                            end
                        end)
                        table.insert(Connections, notifConn)
                    end
                end)
                if not OldNamecall then
                    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                        local method = getnamecallmethod() local args = {...}
                        if not checkcaller() then
                            if method == "Kick" or method == "kick" then warn("[Airi Hub] Blocked Kick") return nil end
                            if method == "FireServer" and type(args[1]) == "string" then
                                local remoteName = string.lower(tostring(args[1]))
                                if BLOCKED_REMOTES[remoteName] then warn("[Airi Hub] Blocked Remote: " .. remoteName) return nil end
                                if remoteName:find("log") and (remoteName:find("kick") or remoteName:find("ac") or remoteName:find("trigger")) then return nil end
                            end
                            if method == "SetNetworkOwner" and type(args[1]) == "nil" then warn("[Airi Hub] Blocked NetworkOwner strip") return nil end
                            if method == "HasTag" and args[2] == BODY_MOVER_TAG then return true end
                        end
                        return OldNamecall(self, ...)
                    end))
                end
                if not OldIndex then
                    OldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
                        if not checkcaller() then
                            if self == CollectionService and key == "HasTag" then
                                return function(_, instance, tag)
                                    if tag == BODY_MOVER_TAG or tag == REQUIRED_BODY_MOVER_TAG then if instance and instance:IsA("BodyMover") then return true end end
                                    return OldIndex(CollectionService, "HasTag")(CollectionService, instance, tag)
                                end
                            end
                            if key == "GetAttribute" and typeof(self) == "Instance" then
                                return function(_, attrName)
                                    local result = OldIndex(self, "GetAttribute")(self, attrName)
                                    if getgenv().AiriConfig and getgenv().AiriConfig.AntiRagdoll then
                                        if attrName == "IsRagdolledServer" or attrName == "IsRagdolledClient" then return false
                                        elseif attrName == "RagdollDisabledClient" or attrName == "RagdollDisabledServer" then return true end
                                    end
                                    if getgenv().AiriConfig and getgenv().AiriConfig.NoDodgeDelay then
                                        if attrName == "DashCooldown" then return 0 elseif attrName == "IsDashing" then return false end
                                    end
                                    return result
                                end
                            end
                        end
                        return OldIndex(self, key)
                    end))
                end
                if not OldNewIndex then
                    OldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
                        if not checkcaller() then
                            if key == "IsRagdolledServer" or key == "IsRagdolledClient" then
                                if getgenv().AiriConfig and getgenv().AiriConfig.AntiRagdoll then return OldNewIndex(self, key, false) end
                            end
                        end
                        return OldNewIndex(self, key, value)
                    end))
                end
                if not OldKick and hookfunction then
                    pcall(function()
                        OldKick = hookfunction(LocalPlayer.Kick, newcclosure(function(self, ...)
                            if not checkcaller() then warn("[Airi Hub] Blocked direct Kick") return nil end
                            return OldKick(self, ...)
                        end))
                    end)
                end
                print("[Airi Hub] Anti-Detect Initialized")
            end
            function AntiDetectModule.Unload()
                for _, conn in ipairs(Connections) do if conn.Connected then conn:Disconnect() end end
                table.clear(Connections)
                if OldNamecall then hookmetamethod(game, "__namecall", OldNamecall) OldNamecall = nil end
                if OldIndex then hookmetamethod(game, "__index", OldIndex) OldIndex = nil end
                if OldNewIndex then hookmetamethod(game, "__newindex", OldNewIndex) OldNewIndex = nil end
                if OldKick and hookfunction then hookfunction(LocalPlayer.Kick, OldKick) OldKick = nil end
                table.clear(SpoofedStores) SpoofedBodyMovers = {}
                print("[Airi Hub] Anti-Detect Unloaded")
            end
            return AntiDetectModule
            --[[EMBEDDED_ANTIDETECT_MODULE_END]]
        end,
        combat = function()
            --[[EMBEDDED_COMBAT_MODULE_START]]
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
            local OriginalSizes = setmetatable({}, {__mode = "k"})
            
            local FOVCircle
            if Drawing then
                pcall(function()
                    FOVCircle = Drawing.new("Circle")
                    FOVCircle.Visible = false FOVCircle.Color = Color3.fromRGB(255,255,255) FOVCircle.Thickness = 1 FOVCircle.Filled = false FOVCircle.Transparency = 1
                end)
            end
            
            local function getLocalCharacter() return PlayerCharacters:FindFirstChild(LocalPlayer.Name) end
            local parryDebounce = false
            local function triggerParry()
                if parryDebounce then return end parryDebounce = true
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(getgenv().AiriConfig.AutoParryDelay or 0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F, false, game)
                task.delay(0.5, function() parryDebounce = false end)
            end
            local function resetHitbox(part)
                if not part then return end
                if OriginalSizes[part] then part.Size = OriginalSizes[part] OriginalSizes[part] = nil end
                part.CanCollide = true
            end
            local function applyHitbox(char, config)
                if char.Name == LocalPlayer.Name then return end
                local part = char:FindFirstChild(config.HitboxPart or "HumanoidRootPart")
                if part then
                    if not OriginalSizes[part] then OriginalSizes[part] = part.Size end
                    part.Size = Vector3.new(config.HitboxSize, config.HitboxSize, config.HitboxSize)
                    part.CanCollide = false
                end
            end
            local function getClosestToCursor(config)
                local closestChar, shortestDist, mousePos = nil, config.AimbotFOV or 100, UserInputService:GetMouseLocation()
                for _, char in ipairs(PlayerCharacters:GetChildren()) do
                    if char.Name ~= LocalPlayer.Name and char:FindFirstChild("HumanoidRootPart") then
                        local humanoid = char:FindFirstChild("Humanoid")
                        if humanoid and humanoid.Health > 0 then
                            local vector, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
                            if onScreen then
                                local dist = (Vector2.new(vector.X, vector.Y) - mousePos).Magnitude
                                if dist < shortestDist then closestChar = char shortestDist = dist end
                            end
                        end
                    end
                end
                return closestChar
            end
            local function setupAnimationDetection(enemyChar)
                if enemyChar.Name == LocalPlayer.Name then return end
                task.spawn(function()
                    local humanoid = enemyChar:WaitForChild("Humanoid", 10) if not humanoid then return end
                    local animator = humanoid:WaitForChild("Animator", 10) if not animator then return end
                    local animConn = animator.AnimationPlayed:Connect(function(animationTrack)
                        local Config = getgenv().AiriConfig
                        if not Config.AutoParry or not Config.UseAnimation then return end
                        local animName = animationTrack.Animation.Name:lower()
                        if animName:find("slash") then
                            local localChar = getLocalCharacter()
                            if localChar and localChar:FindFirstChild("HumanoidRootPart") and enemyChar:FindFirstChild("HumanoidRootPart") then
                                local dist = (localChar.HumanoidRootPart.Position - enemyChar.HumanoidRootPart.Position).Magnitude
                                if dist <= (Config.ParryRange or 15) then triggerParry() end
                            end
                        end
                    end)
                    table.insert(Connections, animConn)
                end)
            end
            function CombatModule.Init()
                for _, char in ipairs(PlayerCharacters:GetChildren()) do setupAnimationDetection(char) end
                table.insert(Connections, PlayerCharacters.ChildAdded:Connect(setupAnimationDetection))
                table.insert(Connections, PlayerCharacters.DescendantAdded:Connect(function(descendant)
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
                                        if dist <= (Config.ParryRange or 15) then triggerParry() end
                                    end
                                end
                            end
                        end
                    end
                end))
                table.insert(Connections, RunService.RenderStepped:Connect(function(deltaTime)
                    local Config = getgenv().AiriConfig
                    if FOVCircle then
                        if Config.AimbotEnabled and Config.ShowFOV then FOVCircle.Visible = true FOVCircle.Radius = Config.AimbotFOV FOVCircle.Position = UserInputService:GetMouseLocation() else FOVCircle.Visible = false end
                    end
                    for _, char in ipairs(PlayerCharacters:GetChildren()) do
                        if char.Name ~= LocalPlayer.Name then
                            local hitboxPart = Config.HitboxPart or "HumanoidRootPart"
                            local partTarget = char:FindFirstChild(hitboxPart)
                            if Config.HitboxExpander then applyHitbox(char, Config) else resetHitbox(partTarget) end
                        end
                    end
                    if Config.AimbotEnabled and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                        local target = getClosestToCursor(Config)
                        if target and target:FindFirstChild(Config.HitboxPart or "HumanoidRootPart") then
                            local targetPos = target[Config.HitboxPart or "HumanoidRootPart"].Position
                            local currentCFrame = Camera.CFrame
                            local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
                            Camera.CFrame = currentCFrame:Lerp(targetCFrame, (Config.AimbotSmooth or 0.5) * deltaTime * 10)
                        end
                    end
                end))
            end
            function CombatModule.Unload()
                if FOVCircle then FOVCircle:Remove() end
                for _, conn in ipairs(Connections) do if conn.Connected then conn:Disconnect() end end
                table.clear(Connections)
                for part, _ in pairs(OriginalSizes) do resetHitbox(part) end
            end
            return CombatModule
            --[[EMBEDDED_COMBAT_MODULE_END]]
        end,
        movement = function()
            --[[EMBEDDED_MOVEMENT_MODULE_START]]
            local Players = game:GetService("Players")
            local RunService = game:GetService("RunService")
            local UserInputService = game:GetService("UserInputService")
            local LocalPlayer = Players.LocalPlayer
            local MovementModule = {}
            local OldNamecall = nil
            local GCHooks = {}
            local Connections = {}
            function MovementModule.Init()
                OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                    local method = getnamecallmethod() local args = {...}
                    if not checkcaller() then
                        if method == "FireServer" then
                            if type(args[1]) == "string" and (args[1] == "TakeFallDamage" or args[1] == "StartFallDamage") then
                                if getgenv().AiriConfig.NoFallDamage then return nil end
                            end
                        elseif method == "GetAttribute" then
                            if getgenv().AiriConfig.AntiRagdoll and type(args[1]) == "string" then
                                local attr = args[1]
                                if attr == "IsRagdolledServer" or attr == "IsRagdolledClient" then return false
                                elseif attr == "RagdollDisabledClient" or attr == "RagdollDisabledServer" then return true end
                            end
                        end
                    end
                    return OldNamecall(self, ...)
                end))
                table.insert(Connections, UserInputService.JumpRequest:Connect(function()
                    if getgenv().AiriConfig.NoJumpDelay then
                        local char = LocalPlayer.Character
                        if char then
                            local humanoid = char:FindFirstChildOfClass("Humanoid")
                            if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
                        end
                    end
                end))
                task.spawn(function()
                    if not getgc then return end
                    pcall(function()
                        for _, obj in pairs(getgc(true)) do
                            if type(obj) == "table" and rawget(obj, "enableDrain") and type(rawget(obj, "enableDrain")) == "function" then
                                local originalDrain = rawget(obj, "enableDrain")
                                table.insert(GCHooks, {object = obj, oldDrain = originalDrain, oldGain = rawget(obj, "gainPerSecond"), oldDelay = rawget(obj, "gainDelay")})
                                obj.enableDrain = newcclosure(function(self, ...) if getgenv().AiriConfig.InfStamina then return end return originalDrain(self, ...) end)
                            end
                        end
                    end)
                end)
                table.insert(Connections, RunService.Heartbeat:Connect(function()
                    for _, hookData in ipairs(GCHooks) do
                        local obj = hookData.object
                        if getgenv().AiriConfig.InfStamina then
                            rawset(obj, "gainPerSecond", 9999) rawset(obj, "gainDelay", 0)
                            local maxStam = rawget(obj, "_maxStamina")
                            if maxStam then rawset(obj, "_stamina", maxStam) end
                        else
                            if rawget(obj, "gainPerSecond") == 9999 then rawset(obj, "gainPerSecond", hookData.oldGain) rawset(obj, "gainDelay", hookData.oldDelay) end
                        end
                    end
                    if getgenv().AiriConfig.NoDodgeDelay and LocalPlayer.Character then
                        local char = LocalPlayer.Character
                        if char:GetAttribute("DashCooldown") then char:SetAttribute("DashCooldown", 0) end
                        if char:GetAttribute("IsDashing") then char:SetAttribute("IsDashing", false) end
                    end
                end))
            end
            function MovementModule.Unload()
                if OldNamecall then hookmetamethod(game, "__namecall", OldNamecall) end
                for _, conn in ipairs(Connections) do if conn.Connected then conn:Disconnect() end end table.clear(Connections)
                for _, hookData in ipairs(GCHooks) do local obj = hookData.object if obj then rawset(obj, "enableDrain", hookData.oldDrain) rawset(obj, "gainPerSecond", hookData.oldGain) rawset(obj, "gainDelay", hookData.oldDelay) end end table.clear(GCHooks)
            end
            return MovementModule
            --[[EMBEDDED_MOVEMENT_MODULE_END]]
        end,
        visuals = function()
            --[[EMBEDDED_VISUAL_MODULE_START]]
            local VisualsModule = {}
            getgenv().AiriConfig = getgenv().AiriConfig or {ESPEnabled = false, ESPOpacity = 1, ESPBox = true, ESPBoxStyle = "Normal", ESPChams = false, ESPSkeleton = false, ESPTracers = false, ESPNames = true, ESPDistances = true, ESPHealthBar = true}
            local Twilight = nil
            local function getBoxStyleInt(styleString) if styleString == "Corner" then return 1 elseif styleString == "3D" then return 3 end return 2 end
            function VisualsModule.Init()
                local success, result = pcall(function() return loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Twilight-ESP/master/src/init.luau"))() end)
                if success and result then Twilight = result print("[Airi Hub] Twilight ESP Loaded") else warn("[Airi Hub] Twilight ESP Failed: " .. tostring(result)) end
                VisualsModule.UpdateAll()
            end
            function VisualsModule.UpdateAll()
                if not Twilight then return end
                local cfg = getgenv().AiriConfig
                Twilight:SetOptions({Enabled = cfg.ESPEnabled, RefreshRate = 1/60, MaxDistance = 1000, Box = {Enabled = cfg.ESPBox, Style = getBoxStyleInt(cfg.ESPBoxStyle), Thickness = 1, Transparency = cfg.ESPOpacity, Filled = {Enabled = false, Transparency = 0.6 * cfg.ESPOpacity}}, Chams = {Enabled = {enemy = cfg.ESPChams, friendly = false,["local"] = false}, Fill = {Enabled = true, Transparency = 0.5 * cfg.ESPOpacity}, Outline = {Enabled = true, Thickness = 0.1}}, Skeleton = {Enabled = {enemy = cfg.ESPSkeleton, friendly = false}, Thickness = 1, Transparency = cfg.ESPOpacity}, Tracer = {Enabled = {enemy = cfg.ESPTracers, friendly = false}, Origin = 1, Thickness = 1, Transparency = cfg.ESPOpacity}, Name = {Enabled = {enemy = cfg.ESPNames, friendly = false}, Style = 1}, Distance = {Enabled = {enemy = cfg.ESPDistances, friendly = false}}, HealthBar = {Enabled = {enemy = cfg.ESPHealthBar, friendly = false}, Bar = true, Text = true}})
            end
            function VisualsModule.ToggleESP(state) getgenv().AiriConfig.ESPEnabled = state VisualsModule.UpdateAll() end
            function VisualsModule.SetBox(state, style) getgenv().AiriConfig.ESPBox = state if style then getgenv().AiriConfig.ESPBoxStyle = style end VisualsModule.UpdateAll() end
            function VisualsModule.SetChams(state) getgenv().AiriConfig.ESPChams = state VisualsModule.UpdateAll() end
            function VisualsModule.SetSkeleton(state) getgenv().AiriConfig.ESPSkeleton = state VisualsModule.UpdateAll() end
            function VisualsModule.SetTracers(state) getgenv().AiriConfig.ESPTracers = state VisualsModule.UpdateAll() end
            function VisualsModule.SetOpacity(value) getgenv().AiriConfig.ESPOpacity = math.clamp(value, 0, 1) VisualsModule.UpdateAll() end
            function VisualsModule.Unload() if Twilight then pcall(function() Twilight:Unload() end) Twilight = nil end end
            return VisualsModule
            --[[EMBEDDED_VISUAL_MODULE_END]]
        end
    }
    
    -- Alias untuk modul visual/visuals
    embeddedModules.visual = embeddedModules.visuals
    
    if embeddedModules[name] then
        local success, result = pcall(embeddedModules[name])
        if success and result and type(result) == "table" then
            print("[Airi Hub] SUCCESS: Module " .. name .. " loaded from embedded fallback")
            return result
        end
    end
    
    warn("[Airi Hub] FAILED to load module: " .. name)
    return nil
end

-- Declare modules as nil first (they will be populated)
local AntiDetectModule, CombatModule, MovementModule, VisualsModule

-- Also store in getgenv for access across threads
getgenv().AiriModules = getgenv().AiriModules or {}

-- Load modules asynchronously (non-blocking)
task.spawn(function()
    print("[Airi Hub] Loading modules in background...")
    AntiDetectModule = loadModule("antidetect")
    getgenv().AiriModules.AntiDetect = AntiDetectModule
    print("[Airi Hub] AntiDetectModule loaded: " .. tostring(AntiDetectModule ~= nil))
    
    CombatModule = loadModule("combat")
    getgenv().AiriModules.Combat = CombatModule
    print("[Airi Hub] CombatModule loaded: " .. tostring(CombatModule ~= nil))
    
    MovementModule = loadModule("movement")
    getgenv().AiriModules.Movement = MovementModule
    print("[Airi Hub] MovementModule loaded: " .. tostring(MovementModule ~= nil))
    
    VisualsModule = loadModule("visual") or loadModule("visuals")
    getgenv().AiriModules.Visuals = VisualsModule
    print("[Airi Hub] VisualsModule loaded: " .. tostring(VisualsModule ~= nil))
    
    print("[Airi Hub] All modules loaded.")
    
    -- Initialize modules
    if AntiDetectModule and AntiDetectModule.Init then pcall(AntiDetectModule.Init) end
    if CombatModule and CombatModule.Init then pcall(CombatModule.Init) end
    if MovementModule and MovementModule.Init then pcall(MovementModule.Init) end
    if VisualsModule and VisualsModule.Init then pcall(VisualsModule.Init) end
    
    print("[Airi Hub] Modules initialized.")
end)

print("[Airi Hub] Now populating tabs (modules loading in background)...")

-----------------------------------------
-- COMBAT TAB
-----------------------------------------
print("[Airi Hub] Populating Combat tab...")
local combatSuccess, combatErr = pcall(function()
    Tabs.Combat:CreateSection("Auto Parry Settings")
    Tabs.Combat:CreateToggle({
        Name = "Auto Parry",
        CurrentValue = getgenv().AiriConfig.AutoParry,
        Flag = "AutoParryToggle",
        Callback = function(state) getgenv().AiriConfig.AutoParry = state end
    })
    
    Tabs.Combat:CreateSlider({
        Name = "Auto Parry Range",
        Range = {5, 30},
        Increment = 1,
        CurrentValue = getgenv().AiriConfig.ParryRange,
        Flag = "AutoParryRangeSlider",
        Callback = function(value) getgenv().AiriConfig.ParryRange = value end
    })
    
    Tabs.Combat:CreateSection("Combat Assist")
    Tabs.Combat:CreateToggle({
        Name = "Anti Parry",
        CurrentValue = getgenv().AiriConfig.AntiParry,
        Flag = "AntiParryToggle",
        Callback = function(state) getgenv().AiriConfig.AntiParry = state end
    })
    
    Tabs.Combat:CreateToggle({
        Name = "Hitbox Expander",
        CurrentValue = getgenv().AiriConfig.HitboxExpander,
        Flag = "HitboxExpanderToggle",
        Callback = function(state) getgenv().AiriConfig.HitboxExpander = state end
    })
    
    Tabs.Combat:CreateSlider({
        Name = "Hitbox Size",
        Range = {0.1, 10},
        Increment = 0.1,
        CurrentValue = getgenv().AiriConfig.HitboxSize,
        Flag = "HitboxSizeSlider",
        Callback = function(value) getgenv().AiriConfig.HitboxSize = value end
    })
    print("[Airi Hub] Combat tab populated!")
end)
if not combatSuccess then warn("[Airi Hub] Combat tab error: " .. tostring(combatErr)) end

-----------------------------------------
-- MOVEMENT TAB
-----------------------------------------
print("[Airi Hub] Populating Movement tab...")
local movementSuccess, movementErr = pcall(function()
    Tabs.Movement:CreateSection("Stamina & Cooldowns")
    Tabs.Movement:CreateToggle({
        Name = "Infinite Stamina",
        CurrentValue = getgenv().AiriConfig.InfStamina,
        Flag = "InfStaminaToggle",
        Callback = function(state) getgenv().AiriConfig.InfStamina = state end
    })
    
    Tabs.Movement:CreateToggle({
        Name = "No Jump Delay",
        CurrentValue = getgenv().AiriConfig.NoJumpDelay,
        Flag = "NoJumpDelayToggle",
        Callback = function(state) getgenv().AiriConfig.NoJumpDelay = state end
    })
    
    Tabs.Movement:CreateToggle({
        Name = "No Dodge Delay",
        CurrentValue = getgenv().AiriConfig.NoDodgeDelay,
        Flag = "NoDodgeDelayToggle",
        Callback = function(state) getgenv().AiriConfig.NoDodgeDelay = state end
    })
    print("[Airi Hub] Movement tab populated!")
end)
if not movementSuccess then warn("[Airi Hub] Movement tab error: " .. tostring(movementErr)) end

-----------------------------------------
-- VISUALS TAB (ESP & AIMBOT)
-----------------------------------------
print("[Airi Hub] Populating Visuals tab...")
local visualsSuccess, visualsErr = pcall(function()
    Tabs.Visuals:CreateSection("ESP Settings")
    Tabs.Visuals:CreateToggle({
        Name = "Enable ESP",
        CurrentValue = getgenv().AiriConfig.ESPEnabled,
        Flag = "ESPToggle",
        Callback = function(state)
            getgenv().AiriConfig.ESPEnabled = state
            print("[Airi Hub] ESP Toggle: " .. tostring(state))
            if getgenv().AiriModules and getgenv().AiriModules.Visuals then
                local VisualsModule = getgenv().AiriModules.Visuals
                if VisualsModule.ToggleESP then 
                    local ok, err = pcall(VisualsModule.ToggleESP, state)
                    if not ok then warn("[Airi Hub] ToggleESP Error: " .. tostring(err)) end
                end
            else
                print("[Airi Hub] ToggleESP: Visuals module not loaded yet")
            end
        end
    })
    
    Tabs.Visuals:CreateDropdown({
        Name = "ESP Box Style",
        Options = {"Corner", "Normal", "3D"},
        CurrentValue = "Normal",
        Flag = "ESPBoxStyleDropdown",
        Callback = function(value)
            print("[Airi Hub] ESP Box Style changed to: " .. tostring(value))
            getgenv().AiriConfig.ESPBoxStyle = value
            if getgenv().AiriModules and getgenv().AiriModules.Visuals then
                local VisualsModule = getgenv().AiriModules.Visuals
                if VisualsModule.SetBox then 
                    local ok, err = pcall(VisualsModule.SetBox, getgenv().AiriConfig.ESPBox, value)
                    if not ok then warn("[Airi Hub] SetBox Error: " .. tostring(err)) end
                end
            end
        end
    })
    
    Tabs.Visuals:CreateToggle({
        Name = "ESP Box",
        CurrentValue = getgenv().AiriConfig.ESPBox,
        Flag = "ESPBoxToggle",
        Callback = function(state)
            print("[Airi Hub] ESP Box Toggle: " .. tostring(state))
            getgenv().AiriConfig.ESPBox = state
            if getgenv().AiriModules and getgenv().AiriModules.Visuals then
                local VisualsModule = getgenv().AiriModules.Visuals
                if VisualsModule.SetBox then 
                    local ok, err = pcall(VisualsModule.SetBox, state, getgenv().AiriConfig.ESPBoxStyle)
                    if not ok then warn("[Airi Hub] SetBox Error: " .. tostring(err)) end
                end
            end
        end
    })
    
    Tabs.Visuals:CreateToggle({
        Name = "ESP Chams",
        CurrentValue = getgenv().AiriConfig.ESPChams,
        Flag = "ESPChamsToggle",
        Callback = function(state)
            print("[Airi Hub] ESP Chams Toggle: " .. tostring(state))
            getgenv().AiriConfig.ESPChams = state
            if getgenv().AiriModules and getgenv().AiriModules.Visuals then
                local VisualsModule = getgenv().AiriModules.Visuals
                if VisualsModule.SetChams then 
                    local ok, err = pcall(VisualsModule.SetChams, state)
                    if not ok then warn("[Airi Hub] SetChams Error: " .. tostring(err)) end
                end
            end
        end
    })
    
    Tabs.Visuals:CreateToggle({
        Name = "ESP Skeleton",
        CurrentValue = getgenv().AiriConfig.ESPSkeleton,
        Flag = "ESPSkeletonToggle",
        Callback = function(state)
            print("[Airi Hub] ESP Skeleton Toggle: " .. tostring(state))
            getgenv().AiriConfig.ESPSkeleton = state
            if getgenv().AiriModules and getgenv().AiriModules.Visuals then
                local VisualsModule = getgenv().AiriModules.Visuals
                if VisualsModule.SetSkeleton then 
                    local ok, err = pcall(VisualsModule.SetSkeleton, state)
                    if not ok then warn("[Airi Hub] SetSkeleton Error: " .. tostring(err)) end
                end
            end
        end
    })
    
    Tabs.Visuals:CreateToggle({
        Name = "ESP Tracers",
        CurrentValue = getgenv().AiriConfig.ESPTracers,
        Flag = "ESPTracersToggle",
        Callback = function(state)
            print("[Airi Hub] ESP Tracers Toggle: " .. tostring(state))
            getgenv().AiriConfig.ESPTracers = state
            if getgenv().AiriModules and getgenv().AiriModules.Visuals then
                local VisualsModule = getgenv().AiriModules.Visuals
                if VisualsModule.SetTracers then 
                    local ok, err = pcall(VisualsModule.SetTracers, state)
                    if not ok then warn("[Airi Hub] SetTracers Error: " .. tostring(err)) end
                end
            end
        end
    })
    
    Tabs.Visuals:CreateSection("Aimbot Settings")
    Tabs.Visuals:CreateToggle({
        Name = "Enable Aimbot (Hold RMB)",
        CurrentValue = getgenv().AiriConfig.AimbotEnabled,
        Flag = "AimbotToggle",
        Callback = function(state) getgenv().AiriConfig.AimbotEnabled = state end
    })
    
    Tabs.Visuals:CreateSlider({
        Name = "Aimbot Smoothness",
        Range = {0, 1},
        Increment = 0.1,
        CurrentValue = getgenv().AiriConfig.AimbotSmooth,
        Flag = "AimbotSmoothSlider",
        Callback = function(value) getgenv().AiriConfig.AimbotSmooth = value end
    })
    
    Tabs.Visuals:CreateSlider({
        Name = "Aimbot FOV",
        Range = {0, 500},
        Increment = 1,
        CurrentValue = getgenv().AiriConfig.AimbotFOV,
        Flag = "AimbotFOVSlider",
        Callback = function(value) getgenv().AiriConfig.AimbotFOV = value end
    })
    print("[Airi Hub] Visuals tab populated!")
end)
if not visualsSuccess then warn("[Airi Hub] Visuals tab error: " .. tostring(visualsErr)) end

-----------------------------------------
-- SETTINGS TAB
-----------------------------------------
print("[Airi Hub] Populating Settings tab...")
local settingsSuccess, settingsErr = pcall(function()
    Tabs.Settings:CreateSection("UI Settings")
    Tabs.Settings:BuildThemeSection()
    print("[Airi Hub] Settings tab populated!")
end)
if not settingsSuccess then warn("[Airi Hub] Settings tab error: " .. tostring(settingsErr)) end

print("[Airi Hub] UI loaded successfully!")
print("[Airi Hub] DIBUKA! Sukses meload UI.")
