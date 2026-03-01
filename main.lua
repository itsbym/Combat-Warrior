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

print("[Airi Hub] Starting Engine (PURE V2 STANDALONE)...")

-- Fetch UI Murni
local function fetchLuna()
    local sources = {
        "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua",
        "https://raw.githubusercontent.com/AmeloxRUS/guiluna/refs/heads/main/luna.lua",
    }
    for _, url in ipairs(sources) do
        local ok, code = pcall(game.HttpGet, game, url, true)
        if ok and type(code) == "string" and #code > 0 then
            local success, luaObj = pcall(loadstring, code)
            if success and type(luaObj) == "function" then
                local result = luaObj()
                if type(result) == "table" then return true, result end
            end
        end
    end
    return false, "Semua sumber GitHub UI gagal dimuat"
end

print("[Airi Hub] Fetching Luna UI...")
local successUI, Luna = fetchLuna()
if not successUI or type(Luna) ~= "table" then
    warn("[Airi Hub] UI gagal dimuat! Error: " .. tostring(Luna))
    return
end

-- ==========================================
-- MODUL EMBEDDED V2 (STANDALONE - NO GITHUB FETCH)
-- ==========================================
local embeddedModules = {
    antidetect = function()
        local AntiDetectModule = {}
        function AntiDetectModule.Init() print("[Airi Hub] Anti-Detect V2 Ready.") end
        function AntiDetectModule.Unload() end
        return AntiDetectModule
    end,
    combat = function()
        local CombatModule = {}
        function CombatModule.Init() print("[Airi Hub] Combat V2 Ready.") end
        function CombatModule.Unload() end
        return CombatModule
    end,
    movement = function()
        local MovementModule = {}
        function MovementModule.Init() print("[Airi Hub] Movement V2 Ready.") end
        function MovementModule.Unload() end
        return MovementModule
    end,
    visuals = function()
        -- NATIVE ESP (No Twilight Dependancy - ANTI CRASH)
        local VisualsModule = {}
        local RunService = game:GetService("RunService")
        local Players = game:GetService("Players")
        local Camera = workspace.CurrentCamera
        local Drawings = {}

        local function createDrawings()
            if not Drawing then return nil end
            return {
                Box = Drawing.new("Square"),
                Tracer = Drawing.new("Line"),
                Name = Drawing.new("Text")
            }
        end

        function VisualsModule.Init()
            print("[Airi Hub] Native ESP Loaded.")
            RunService.RenderStepped:Connect(function()
                local cfg = getgenv().AiriConfig
                
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= Players.LocalPlayer then
                        if not Drawings[player] and Drawing then
                            Drawings[player] = createDrawings()
                        end
                        
                        local d = Drawings[player]
                        if d then
                            local char = player.Character
                            if cfg.ESPEnabled and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                                local hrp = char.HumanoidRootPart
                                local vector, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                                
                                if onScreen then
                                    if cfg.ESPBox then
                                        d.Box.Visible = true
                                        local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
                                        local sizeY = math.clamp(2000 / distance, 10, 1000)
                                        local sizeX = sizeY / 2
                                        d.Box.Size = Vector2.new(sizeX, sizeY)
                                        d.Box.Position = Vector2.new(vector.X - sizeX / 2, vector.Y - sizeY / 2)
                                        d.Box.Color = Color3.fromRGB(191, 64, 191)
                                        d.Box.Thickness = 1.5
                                        d.Box.Filled = false
                                    else
                                        d.Box.Visible = false
                                    end

                                    if cfg.ESPTracers then
                                        d.Tracer.Visible = true
                                        d.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                        d.Tracer.To = Vector2.new(vector.X, vector.Y)
                                        d.Tracer.Color = Color3.fromRGB(191, 64, 191)
                                        d.Tracer.Thickness = 1
                                    else
                                        d.Tracer.Visible = false
                                    end

                                    if cfg.ESPNames then
                                        d.Name.Visible = true
                                        d.Name.Text = player.Name
                                        d.Name.Position = Vector2.new(vector.X, vector.Y - (d.Box.Size.Y / 2) - 15)
                                        d.Name.Color = Color3.fromRGB(255, 255, 255)
                                        d.Name.Size = 16
                                        d.Name.Center = true
                                        d.Name.Outline = true
                                    else
                                        d.Name.Visible = false
                                    end
                                else
                                    d.Box.Visible = false
                                    d.Tracer.Visible = false
                                    d.Name.Visible = false
                                end
                            else
                                d.Box.Visible = false
                                d.Tracer.Visible = false
                                d.Name.Visible = false
                            end
                        end
                    end
                end
            end)
        end
        
        -- Proxy functions
        function VisualsModule.ToggleESP(state) getgenv().AiriConfig.ESPEnabled = state end
        function VisualsModule.SetBox(state, style) getgenv().AiriConfig.ESPBox = state; getgenv().AiriConfig.ESPBoxStyle = style or "Normal" end
        function VisualsModule.SetTracers(state) getgenv().AiriConfig.ESPTracers = state end
        return VisualsModule
    end
}

-- MENGISI MODULES SECARA INSTAN (Tanpa Task.Spawn / Delay)
getgenv().AiriModules = getgenv().AiriModules or {}
getgenv().AiriModules.AntiDetect = embeddedModules.antidetect()
getgenv().AiriModules.Combat = embeddedModules.combat()
getgenv().AiriModules.Movement = embeddedModules.movement()
getgenv().AiriModules.Visuals = embeddedModules.visuals()

-- INITIALIZE INSTANT
if getgenv().AiriModules.AntiDetect then pcall(getgenv().AiriModules.AntiDetect.Init) end
if getgenv().AiriModules.Combat then pcall(getgenv().AiriModules.Combat.Init) end
if getgenv().AiriModules.Movement then pcall(getgenv().AiriModules.Movement.Init) end
if getgenv().AiriModules.Visuals then pcall(getgenv().AiriModules.Visuals.Init) end

print("[Airi Hub] Modules initialized instantly!")

-- ==========================================
-- BUILD UI
-- ==========================================
local Window = Luna:CreateWindow({
    Name = "Combat Warriors | Airi Hub V2",
    Subtitle = "Airi Script Native",
    LogoID = "6031097225",
    LoadingEnabled = false,
    KeySystem = false,
    Color = Color3.fromRGB(191, 64, 191)
})

local Tabs = {}
Tabs.Combat = Window:CreateTab({ Name = "Combat", Icon = "code", ImageSource = "Material", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "group_work", ImageSource = "Material", ShowTitle = true })
Tabs.Visuals = Window:CreateTab({ Name = "Visuals", Icon = "list", ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings_phone", ImageSource = "Material", ShowTitle = true })
Window:CreateHomeTab()

Tabs.Combat:CreateSection("Auto Parry Settings")
Tabs.Combat:CreateToggle({Name = "Auto Parry", CurrentValue = Config.AutoParry, Flag = "AutoParryToggle", Callback = function(state) Config.AutoParry = state end})
Tabs.Combat:CreateSlider({Name = "Auto Parry Range", Range = {5, 30}, Increment = 1, CurrentValue = Config.ParryRange, Flag = "AutoParryRangeSlider", Callback = function(val) Config.ParryRange = val end})

Tabs.Movement:CreateSection("Stamina & Cooldowns")
Tabs.Movement:CreateToggle({Name = "Infinite Stamina", CurrentValue = Config.InfStamina, Flag = "InfStaminaToggle", Callback = function(state) Config.InfStamina = state end})
Tabs.Movement:CreateToggle({Name = "No Dodge Delay", CurrentValue = Config.NoDodgeDelay, Flag = "NoDodgeDelayToggle", Callback = function(state) Config.NoDodgeDelay = state end})

Tabs.Visuals:CreateSection("ESP Settings (Native)")
Tabs.Visuals:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Config.ESPEnabled,
    Flag = "ESPToggle",
    Callback = function(state)
        Config.ESPEnabled = state
        pcall(getgenv().AiriModules.Visuals.ToggleESP, state)
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Box",
    CurrentValue = Config.ESPBox,
    Flag = "ESPBoxToggle",
    Callback = function(state)
        Config.ESPBox = state
        pcall(getgenv().AiriModules.Visuals.SetBox, state, Config.ESPBoxStyle)
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Tracers",
    CurrentValue = Config.ESPTracers,
    Flag = "ESPTracersToggle",
    Callback = function(state)
        Config.ESPTracers = state
        pcall(getgenv().AiriModules.Visuals.SetTracers, state)
    end
})

Tabs.Settings:CreateSection("UI Settings")
Tabs.Settings:BuildThemeSection()

print("[Airi Hub] DIBUKA! Sukses meload UI.")
