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
                if type(result) == "table" then
                    return true, result
                end
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

if not Window then return end
pcall(function() if Window and Window.Elements and Window.Elements.Parent then Window.Elements.Parent.Visible = true end end)

local Tabs = {}
Tabs.Combat = Window:CreateTab({ Name = "Combat", Icon = "code", ImageSource = "Material", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "group_work", ImageSource = "Material", ShowTitle = true })
Tabs.Visuals = Window:CreateTab({ Name = "Visuals", Icon = "list", ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings_phone", ImageSource = "Material", ShowTitle = true })
Window:CreateHomeTab()

-- ==========================================
-- DAFTAR MODUL EMBEDDED (FAIL-SAFE)
-- ==========================================
local embeddedModules = {
    antidetect = function()
        local AntiDetectModule = {}
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer
        function AntiDetectModule.Init() print("[Airi Hub] Anti-Detect V2 Ready (Fallback)") end
        function AntiDetectModule.Unload() end
        return AntiDetectModule
    end,
    combat = function()
        local CombatModule = {}
        function CombatModule.Init() print("[Airi Hub] Combat V2 Ready (Fallback)") end
        function CombatModule.Unload() end
        return CombatModule
    end,
    movement = function()
        local MovementModule = {}
        function MovementModule.Init() print("[Airi Hub] Movement V2 Ready (Fallback)") end
        function MovementModule.Unload() end
        return MovementModule
    end,
    visuals = function()
        -- NATIVE ESP (No Twilight Dependancy)
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
                local localChar = Players.LocalPlayer.Character
                
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
                                    -- Box ESP
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

                                    -- Tracer ESP
                                    if cfg.ESPTracers then
                                        d.Tracer.Visible = true
                                        d.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                        d.Tracer.To = Vector2.new(vector.X, vector.Y)
                                        d.Tracer.Color = Color3.fromRGB(191, 64, 191)
                                        d.Tracer.Thickness = 1
                                    else
                                        d.Tracer.Visible = false
                                    end

                                    -- Name ESP
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
        
        -- Dummy functions untuk mencegah error dari UI Callback
        function VisualsModule.ToggleESP(state) getgenv().AiriConfig.ESPEnabled = state end
        function VisualsModule.SetBox(state, style) getgenv().AiriConfig.ESPBox = state; getgenv().AiriConfig.ESPBoxStyle = style or "Normal" end
        function VisualsModule.SetChams(state) getgenv().AiriConfig.ESPChams = state end
        function VisualsModule.SetSkeleton(state) getgenv().AiriConfig.ESPSkeleton = state end
        function VisualsModule.SetTracers(state) getgenv().AiriConfig.ESPTracers = state end
        function VisualsModule.SetOpacity(value) getgenv().AiriConfig.ESPOpacity = value end
        function VisualsModule.Unload()
            for _, d in pairs(Drawings) do pcall(function() d.Box:Remove() d.Tracer:Remove() d.Name:Remove() end) end
        end
        return VisualsModule
    end
}
embeddedModules.visual = embeddedModules.visuals -- Alias

-- ==========================================
-- FAIL-SAFE MODULE LOADER
-- ==========================================
local function loadModule(name)
    print("[Airi Hub] Loading module: " .. name)
    -- URL TELAH DIPERBAIKI SESUAI STRUKTUR GITHUB YANG BENAR
    local url = "https://raw.githubusercontent.com/itsbym/Combat-Warrior/refs/heads/main/modules/" .. name .. ".lua?t=" .. tostring(tick())
    
    local success, result = pcall(function()
        local code = game:HttpGet(url)
        -- Proteksi dari error 404 (halaman tidak ada)
        if not code or #code == 0 or code:find("404: Not Found") then return nil end
        
        local loadFunc = loadstring(code)
        -- Proteksi jika loadstring mengembalikan nil (syntax error)
        if type(loadFunc) ~= "function" then return nil end
        
        return loadFunc()
    end)
    
    if success and type(result) == "table" then
        print("[Airi Hub] SUCCESS: Module " .. name .. " loaded from GitHub")
        return result
    end
    
    -- JIKA GITHUB GAGAL / 404, SELALU GUNAKAN EMBEDDED
    print("[Airi Hub] GitHub failed, using embedded fallback for: " .. name)
    if embeddedModules[name] then
        local fallbackSuccess, fallbackResult = pcall(embeddedModules[name])
        if fallbackSuccess and type(fallbackResult) == "table" then
            print("[Airi Hub] SUCCESS: Embedded module " .. name .. " loaded.")
            return fallbackResult
        else
            warn("[Airi Hub] ERROR: Embedded module " .. name .. " crashed during creation!")
        end
    end
    
    return nil
end

-- Simpan ke _G / getgenv agar bisa diakses
getgenv().AiriModules = getgenv().AiriModules or {}

task.spawn(function()
    print("[Airi Hub] Loading modules in background...")
    
    getgenv().AiriModules.AntiDetect = loadModule("antidetect")
    getgenv().AiriModules.Combat = loadModule("combat")
    getgenv().AiriModules.Movement = loadModule("movement")
    
    -- Memuat Visuals
    local visMod = loadModule("visual")
    if not visMod then visMod = loadModule("visuals") end
    getgenv().AiriModules.Visuals = visMod
    
    print("[Airi Hub] Executing Module Init functions...")
    
    -- Menjalankan Init() dengan aman
    if getgenv().AiriModules.AntiDetect and getgenv().AiriModules.AntiDetect.Init then pcall(getgenv().AiriModules.AntiDetect.Init) end
    if getgenv().AiriModules.Combat and getgenv().AiriModules.Combat.Init then pcall(getgenv().AiriModules.Combat.Init) end
    if getgenv().AiriModules.Movement and getgenv().AiriModules.Movement.Init then pcall(getgenv().AiriModules.Movement.Init) end
    if getgenv().AiriModules.Visuals and getgenv().AiriModules.Visuals.Init then pcall(getgenv().AiriModules.Visuals.Init) end
    
    print("[Airi Hub] Modules initialized successfully!")
end)

print("[Airi Hub] Building UI Menus...")

--[TAB COMBAT]
Tabs.Combat:CreateSection("Auto Parry Settings")
Tabs.Combat:CreateToggle({Name = "Auto Parry", CurrentValue = Config.AutoParry, Flag = "AutoParryToggle", Callback = function(state) Config.AutoParry = state end})
Tabs.Combat:CreateSlider({Name = "Auto Parry Range", Range = {5, 30}, Increment = 1, CurrentValue = Config.ParryRange, Flag = "AutoParryRangeSlider", Callback = function(val) Config.ParryRange = val end})
Tabs.Combat:CreateSection("Combat Assist")
Tabs.Combat:CreateToggle({Name = "Hitbox Expander", CurrentValue = Config.HitboxExpander, Flag = "HitboxExpanderToggle", Callback = function(state) Config.HitboxExpander = state end})
Tabs.Combat:CreateSlider({Name = "Hitbox Size", Range = {0.1, 10}, Increment = 0.1, CurrentValue = Config.HitboxSize, Flag = "HitboxSizeSlider", Callback = function(val) Config.HitboxSize = val end})

-- [TAB MOVEMENT]
Tabs.Movement:CreateSection("Stamina & Cooldowns")
Tabs.Movement:CreateToggle({Name = "Infinite Stamina", CurrentValue = Config.InfStamina, Flag = "InfStaminaToggle", Callback = function(state) Config.InfStamina = state end})
Tabs.Movement:CreateToggle({Name = "No Jump Delay", CurrentValue = Config.NoJumpDelay, Flag = "NoJumpDelayToggle", Callback = function(state) Config.NoJumpDelay = state end})
Tabs.Movement:CreateToggle({Name = "No Dodge Delay", CurrentValue = Config.NoDodgeDelay, Flag = "NoDodgeDelayToggle", Callback = function(state) Config.NoDodgeDelay = state end})

-- [TAB VISUALS]
Tabs.Visuals:CreateSection("ESP Settings (Native)")
Tabs.Visuals:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = Config.ESPEnabled,
    Flag = "ESPToggle",
    Callback = function(state)
        Config.ESPEnabled = state
        if getgenv().AiriModules and getgenv().AiriModules.Visuals and getgenv().AiriModules.Visuals.ToggleESP then 
            pcall(getgenv().AiriModules.Visuals.ToggleESP, state)
        else
            warn("[Airi Hub] ESP Toggle clicked, but Visuals module is missing/crashed!")
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Box",
    CurrentValue = Config.ESPBox,
    Flag = "ESPBoxToggle",
    Callback = function(state)
        Config.ESPBox = state
        if getgenv().AiriModules and getgenv().AiriModules.Visuals and getgenv().AiriModules.Visuals.SetBox then 
            pcall(getgenv().AiriModules.Visuals.SetBox, state, Config.ESPBoxStyle)
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Tracers",
    CurrentValue = Config.ESPTracers,
    Flag = "ESPTracersToggle",
    Callback = function(state)
        Config.ESPTracers = state
        if getgenv().AiriModules and getgenv().AiriModules.Visuals and getgenv().AiriModules.Visuals.SetTracers then 
            pcall(getgenv().AiriModules.Visuals.SetTracers, state)
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Names",
    CurrentValue = Config.ESPNames,
    Flag = "ESPNamesToggle",
    Callback = function(state)
        Config.ESPNames = state
    end
})

--[TAB SETTINGS]
Tabs.Settings:CreateSection("UI Settings")
Tabs.Settings:BuildThemeSection()

print("[Airi Hub] DIBUKA! Sukses meload UI.")
