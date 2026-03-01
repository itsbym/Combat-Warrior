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

-- helper yang mencoba beberapa sumber termasuk file lokal
local function fetchLuna()
    print("[Airi Hub] DEBUG: Attempting to load Luna from local file...")
    
    -- coba file lokal terlebih dahulu (paling reliable)
    local ok, localCode = pcall(readfile, "LUNA-LIB-UI/source.lua")
    print("[Airi Hub] DEBUG: Local readfile status: " .. tostring(ok))
    
    if ok and type(localCode) == "string" and #localCode > 0 then
        print("[Airi Hub] DEBUG: Local file read successfully, compiling...")
        local success, luaObj = pcall(loadstring, localCode)
        print("[Airi Hub] DEBUG: Loadstring status: " .. tostring(success) .. ", type: " .. type(luaObj))
        
        if success and type(luaObj) == "function" then
            print("[Airi Hub] DEBUG: Executing Luna function...")
            local result = luaObj()
            print("[Airi Hub] DEBUG: Luna result type: " .. type(result))
            
            if type(result) == "table" then
                print("[Airi Hub] SUCCESS: Loaded Luna from local file!")
                return true, result
            end
        end
    end

    print("[Airi Hub] DEBUG: Local file failed, trying GitHub sources...")
    
    -- jika lokal gagal, coba dari GitHub
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

    return false, "semua sumber gagal dimuat"
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
Tabs.Combat = Window:CreateTab({ Name = "Combat", Icon = "swords", ImageSource = "Lucide", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "person", ImageSource = "Material", ShowTitle = true })
Tabs.Visuals = Window:CreateTab({ Name = "Visuals", Icon = "visibility", ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings", ImageSource = "Material", ShowTitle = true })

Window:CreateHomeTab()

print("[Airi Hub] UI loaded successfully. Loading modules in background...")

-- Fungsi Helper untuk Load Module (DENGAN ANTI-CACHE / BYPASS CACHE GITHUB)
local function loadModule(name)
    local url = "https://raw.githubusercontent.com/itsbym/Combat-Warrior/main/modules/" .. name .. ".lua?t=" .. tostring(tick())
    
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    
    if success then
        print("[Airi Hub] Successfully loaded module: " .. name)
        return result
    else
        warn("[Airi Hub] FATAL ERROR on module '" .. name .. "': " .. tostring(result))
        return nil
    end
end

-- Load Modules (non-blocking, after UI is ready)
print("[Airi Hub] Loading modules...")
local AntiDetectModule = loadModule("antidetect")
print("[Airi Hub] AntiDetectModule loaded: " .. tostring(AntiDetectModule ~= nil))

local CombatModule = loadModule("combat")
print("[Airi Hub] CombatModule loaded: " .. tostring(CombatModule ~= nil))

local MovementModule = loadModule("movement")
print("[Airi Hub] MovementModule loaded: " .. tostring(MovementModule ~= nil))

local VisualsModule = loadModule("visual")
print("[Airi Hub] VisualsModule loaded: " .. tostring(VisualsModule ~= nil))

print("[Airi Hub] All modules loading complete.")

-----------------------------------------
-- COMBAT TAB
-----------------------------------------
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

-----------------------------------------
-- MOVEMENT TAB
-----------------------------------------
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

-----------------------------------------
-- VISUALS TAB (ESP & AIMBOT)
-----------------------------------------
Tabs.Visuals:CreateSection("ESP Settings")
Tabs.Visuals:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = getgenv().AiriConfig.ESPEnabled,
    Flag = "ESPToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPEnabled = state
        if VisualsModule and VisualsModule.ToggleESP then pcall(VisualsModule.ToggleESP, state) end
    end
})

Tabs.Visuals:CreateDropdown({
    Name = "ESP Box Style",
    Options = {"Corner", "Normal", "3D"},
    CurrentValue = getgenv().AiriConfig.ESPBoxStyle,
    Flag = "ESPBoxStyleDropdown",
    Callback = function(value)
        getgenv().AiriConfig.ESPBoxStyle = value
        if VisualsModule and VisualsModule.SetBox then pcall(VisualsModule.SetBox, getgenv().AiriConfig.ESPBox, value) end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Box",
    CurrentValue = getgenv().AiriConfig.ESPBox,
    Flag = "ESPBoxToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPBox = state
        if VisualsModule and VisualsModule.SetBox then pcall(VisualsModule.SetBox, state, getgenv().AiriConfig.ESPBoxStyle) end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Chams",
    CurrentValue = getgenv().AiriConfig.ESPChams,
    Flag = "ESPChamsToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPChams = state
        if VisualsModule and VisualsModule.SetChams then pcall(VisualsModule.SetChams, state) end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Skeleton",
    CurrentValue = getgenv().AiriConfig.ESPSkeleton,
    Flag = "ESPSkeletonToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPSkeleton = state
        if VisualsModule and VisualsModule.SetSkeleton then pcall(VisualsModule.SetSkeleton, state) end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Tracers",
    CurrentValue = getgenv().AiriConfig.ESPTracers,
    Flag = "ESPTracersToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPTracers = state
        if VisualsModule and VisualsModule.SetTracers then pcall(VisualsModule.SetTracers, state) end
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

-----------------------------------------
-- SETTINGS TAB
-----------------------------------------
Tabs.Settings:CreateSection("UI Settings")
Tabs.Settings:BuildThemeSection()

-----------------------------------------
-- INITIALIZE MODULES
-----------------------------------------
print("[Airi Hub] Initializing local modules...")
if AntiDetectModule and AntiDetectModule.Init then pcall(AntiDetectModule.Init) end
if CombatModule and CombatModule.Init then pcall(CombatModule.Init) end
if MovementModule and MovementModule.Init then pcall(MovementModule.Init) end
if VisualsModule and VisualsModule.Init then pcall(VisualsModule.Init) end

print("[Airi Hub] DIBUKA! Sukses meload UI.")