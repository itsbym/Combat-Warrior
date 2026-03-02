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

        -- Variables untuk menampung referensi objek dari GC Sweep
        local sweepDone = false
        local acTables = {}
        local acFunctions = {}

        -- Variabel untuk menyimpan hooks lama
        local oldNamecall
        local oldIndex
        local oldGetLogHistory
        local errConn

        function AntiDetectModule.Init()
            print("[Airi Hub] Initializing Anti-Detect V2...")

            -- 1. Single-Sweep Dynamic GC (Structure-based)
            if not sweepDone then
                local function doSweep()
                    local gc = getgc(true)
                    for _, obj in ipairs(gc) do
                        if type(obj) == "table" then
                            -- Deteksi tabel AntiCheat berdasarkan propertinya, bukan namanya
                            if rawget(obj, "disabledCounts") or rawget(obj, "network") or rawget(obj, "remote") then
                                table.insert(acTables, obj)
                            end
                        elseif type(obj) == "function" then
                            local info = debug.getinfo(obj)
                            if info and info.name and (info.name:lower():match("ban") or info.name:lower():match("kick") or info.name:lower():match("crash")) then
                                table.insert(acFunctions, obj)
                            end
                        end
                    end
                end

                -- Jalankan sweep dengan aman
                pcall(doSweep)
                sweepDone = true
                print("[Airi Hub] GC Sweep complete. Ditemukan " .. #acTables .. " tabel mencurigakan & " .. #acFunctions .. " fungsi mencurigakan.")
            end

            -- 2 & 3. Metamethod Guarding (__namecall / __index) & Advanced Anti-Remote Logging
            local mt = getrawmetatable(game)
            setreadonly(mt, false)

            -- CACHE SERVICES DI LUAR HOOK (Sangat Pantang Manggil GetService di dalam Namecall -> Infinite Loop / Crash)
            local CollectionService = game:GetService("CollectionService")
            local CoreGui = game:GetService("CoreGui")

            oldNamecall = mt.__namecall
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()

                if not checkcaller() then
                    -- Pemanggilan berasal dari game script (Anti-Cheat)

                    if self == CollectionService and method == "HasTag" then
                        -- Hanya parsing argument saat kondisi terpenuhi agar FPS tidak drop (mengurangi sampah GC)
                        local args = {...}
                        local tag = args[2] -- Arg 1 adalah Instance, Arg 2 adalah tag string
                        
                        if type(tag) == "string" and (tag == "BodyMover" or tag == "SuspiciousMovement" or tag == "4f9a51c7-5fb1-43ea-834f-091d74b80d81") then
                            return false -- Spoof nilai false agar dikira aman
                        end
                    end

                    -- Mencegah Anti-Cheat memeriksa apa yang kita ubah di dalam instans tertentu
                    if self == CoreGui and (method == "FindFirstChild" or method == "GetChildren") then
                        -- Beberapa executor menyimpan UI di CoreGui, kita bisa spoofing hasilnya di sini jika perlu
                        -- Untuk saat ini, kita biarkan aslinya, atau filter nama spesifik.
                    end
                end

                return oldNamecall(self, ...)
            end)

            oldIndex = mt.__index
            mt.__index = newcclosure(function(self, idx)
                if not checkcaller() then
                    -- Pemanggilan dari game script
                    -- Blokir pencarian index yang sensitif jika diperlukan
                end
                return oldIndex(self, idx)
            end)

            setreadonly(mt, true)

            -- 4. ScriptContext & Crash Log Muting (Gag Order)
            local LogService = game:GetService("LogService")
            local ScriptContext = game:GetService("ScriptContext")

            -- Hook LogService:GetLogHistory() agar developer tidak bisa melihat error executor
            if hookfunction then
                pcall(function()
                    oldGetLogHistory = hookfunction(LogService.GetLogHistory, newcclosure(function(self)
                        local history = oldGetLogHistory(self)
                        local cleanHistory = {}
                        for _, log in ipairs(history) do
                            local msg = string.lower(log.message)
                            -- Jika log mengandung kata kunci script kita, buang dari history
                            if not (string.match(msg, "airi hub") or string.match(msg, "executor") or string.match(msg, "getgc") or string.match(msg, "hookfunction")) then
                                table.insert(cleanHistory, log)
                            end
                        end
                        return cleanHistory
                    end))
                end)
            end

            -- Mute error agar tidak dikirim lewat webhook oleh game
            errConn = ScriptContext.Error:Connect(function(message, trace, script)
                local msg = string.lower(tostring(message))
                local trc = string.lower(tostring(trace))

                -- Jika errornya karena script kita
                if string.match(msg, "airi") or string.match(trc, "airi") or string.match(trc, "executor") then
                    -- Menghapus console output client (hanya bekerja di beberapa executor)
                    if clearconsole then
                        pcall(clearconsole)
                    end
                end
            end)

            print("[Airi Hub] Anti-Detect V2 Ready.")
        end

        function AntiDetectModule.Unload()
            if errConn then
                errConn:Disconnect()
                errConn = nil
            end

            local mt = getrawmetatable(game)
            if mt then
                setreadonly(mt, false)
                if oldNamecall then mt.__namecall = oldNamecall end
                if oldIndex then mt.__index = oldIndex end
                setreadonly(mt, true)
            end

            if hookfunction and oldGetLogHistory then
                pcall(function()
                    hookfunction(game:GetService("LogService").GetLogHistory, oldGetLogHistory)
                end)
            end

            print("[Airi Hub] Anti-Detect V2 Unloaded.")
        end

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
        local Drawings = {}

        -- Global Connections for cleanup
        getgenv().AiriVisualConnections = getgenv().AiriVisualConnections or {}

        local function createDrawings()
            if not Drawing then return nil end
            return {
                Box = Drawing.new("Square"),
                Tracer = Drawing.new("Line"),
                Name = Drawing.new("Text")
            }
        end

        local function removeDrawings(player)
            if Drawings[player] then
                for _, drawingObj in pairs(Drawings[player]) do
                    drawingObj:Remove()
                end
                Drawings[player] = nil
            end
        end

        function VisualsModule.Init()
            print("[Airi Hub] Native ESP Loaded.")

            -- Disconnect existing connections if any
            if getgenv().AiriVisualConnections.RenderStepped then
                getgenv().AiriVisualConnections.RenderStepped:Disconnect()
            end
            if getgenv().AiriVisualConnections.PlayerRemoving then
                getgenv().AiriVisualConnections.PlayerRemoving:Disconnect()
            end

            -- Clean up old drawings if any
            for player, _ in pairs(Drawings) do
                removeDrawings(player)
            end

            getgenv().AiriVisualConnections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
                removeDrawings(player)
            end)

            getgenv().AiriVisualConnections.RenderStepped = RunService.RenderStepped:Connect(function()
                local cfg = getgenv().AiriConfig
                local Camera = workspace.CurrentCamera -- Always get latest camera

                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= Players.LocalPlayer then
                        if not Drawings[player] and Drawing then
                            Drawings[player] = createDrawings()
                        end

                        local d = Drawings[player]
                        if d then
                            local char = player.Character
                            -- Robust check
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
                                        d.Name.Position = Vector2.new(vector.X, vector.Y - (d.Box.Size and d.Box.Size.Y / 2 or 100) - 15)
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

        function VisualsModule.Unload()
            if getgenv().AiriVisualConnections then
                if getgenv().AiriVisualConnections.RenderStepped then
                    getgenv().AiriVisualConnections.RenderStepped:Disconnect()
                end
                if getgenv().AiriVisualConnections.PlayerRemoving then
                    getgenv().AiriVisualConnections.PlayerRemoving:Disconnect()
                end
                getgenv().AiriVisualConnections = {}
            end

            for player, _ in pairs(Drawings) do
                removeDrawings(player)
            end
            print("[Airi Hub] Native ESP Unloaded.")
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
