-- Inisialisasi Global Config
getgenv().AiriConfig = getgenv().AiriConfig or {
    -- Combat & Parry
    AutoParry = false,
    AutoParryDelay = 0.1,
    AntiParry = false,
    UseSound = true,
    UseAnimation = true,
    ParryRange = 15,
    HitboxExpander = false,
    HitboxSize = 1,
    HitboxPart = "HumanoidRootPart",
    
    -- Movement
    InfStamina = false,
    NoJumpDelay = false,
    NoDodgeDelay = false,
    NoFallDamage = true,
    AntiRagdoll = false,
    
    -- Visuals (ESP)
    ESPEnabled = false,
    ESPOpacity = 1,
    ESPBox = true,
    ESPBoxStyle = "Normal",
    ESPChams = false,
    ESPSkeleton = false,
    ESPTracers = false,
    ESPNames = true,
    ESPDistances = true,
    ESPHealthBar = true,
    
    -- Aimbot
    AimbotEnabled = false,
    AimbotSmooth = 0.5,
    AimbotFOV = 100,
    ShowFOV = true
}
local Config = getgenv().AiriConfig

-- Fungsi Helper untuk Load Module dengan pcall
local function loadModule(name)
    local url = "https://raw.githubusercontent.com/itsbym/Combat-Warrior/main/modules/" .. name .. ".lua"
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    
    if success then
        print("[Airi Hub] Successfully loaded module: " .. name)
        return result
    else
        warn("[Airi Hub] Failed to load module: " .. name .. " | Error: " .. tostring(result))
        return nil
    end
end

-- Load Modules
local AntiDetectModule = loadModule("antidetect")
local CombatModule = loadModule("combat")
local MovementModule = loadModule("movement")
local VisualsModule = loadModule("visual")

-- Inisialisasi Luna UI
local successUI, Luna = pcall(function()
    return loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/luna", true))()
end)

if not successUI or not Luna then
    warn("[Airi Hub] Failed to load Luna UI Library.")
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
    Color = Color3.fromRGB(191, 64, 191) -- Tema warna ungu
})

local Tabs = {}
Tabs.Combat = Window:CreateTab({ Name = "Combat", Icon = "swords", ImageSource = "Lucide", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "person", ImageSource = "Material", ShowTitle = true })
Tabs.Visuals = Window:CreateTab({ Name = "Visuals", Icon = "visibility", ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings", ImageSource = "Material", ShowTitle = true })

Window:CreateHomeTab()

-----------------------------------------
-- COMBAT TAB
-----------------------------------------
Tabs.Combat:CreateSection("Auto Parry Settings")
Tabs.Combat:CreateToggle({
    Name = "Auto Parry",
    Description = "Automatically blocks incoming attacks.",
    CurrentValue = getgenv().AiriConfig.AutoParry,
    Flag = "AutoParryToggle",
    Callback = function(state)
        getgenv().AiriConfig.AutoParry = state
    end
})

Tabs.Combat:CreateSlider({
    Name = "Auto Parry Range",
    Range = {5, 30},
    Increment = 1,
    CurrentValue = getgenv().AiriConfig.ParryRange,
    Flag = "AutoParryRangeSlider",
    Callback = function(value)
        getgenv().AiriConfig.ParryRange = value
    end
})

Tabs.Combat:CreateSection("Combat Assist")
Tabs.Combat:CreateToggle({
    Name = "Anti Parry",
    CurrentValue = getgenv().AiriConfig.AntiParry,
    Flag = "AntiParryToggle",
    Callback = function(state)
        getgenv().AiriConfig.AntiParry = state
    end
})

Tabs.Combat:CreateToggle({
    Name = "Hitbox Expander",
    Description = "Expands enemy hitboxes for easier hits.",
    CurrentValue = getgenv().AiriConfig.HitboxExpander,
    Flag = "HitboxExpanderToggle",
    Callback = function(state)
        getgenv().AiriConfig.HitboxExpander = state
    end
})

Tabs.Combat:CreateSlider({
    Name = "Hitbox Size",
    Range = {0.1, 10},
    Increment = 0.1,
    CurrentValue = getgenv().AiriConfig.HitboxSize,
    Flag = "HitboxSizeSlider",
    Callback = function(value)
        getgenv().AiriConfig.HitboxSize = value
    end
})

-----------------------------------------
-- MOVEMENT TAB
-----------------------------------------
Tabs.Movement:CreateSection("Stamina & Cooldowns")
Tabs.Movement:CreateToggle({
    Name = "Infinite Stamina",
    CurrentValue = getgenv().AiriConfig.InfStamina,
    Flag = "InfStaminaToggle",
    Callback = function(state)
        getgenv().AiriConfig.InfStamina = state
    end
})

Tabs.Movement:CreateToggle({
    Name = "No Jump Delay",
    CurrentValue = getgenv().AiriConfig.NoJumpDelay,
    Flag = "NoJumpDelayToggle",
    Callback = function(state)
        getgenv().AiriConfig.NoJumpDelay = state
    end
})

Tabs.Movement:CreateToggle({
    Name = "No Dodge Delay",
    CurrentValue = getgenv().AiriConfig.NoDodgeDelay,
    Flag = "NoDodgeDelayToggle",
    Callback = function(state)
        getgenv().AiriConfig.NoDodgeDelay = state
    end
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

Tabs.Visuals:CreateSlider({
    Name = "ESP Opacity",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = getgenv().AiriConfig.ESPOpacity,
    Flag = "ESPOpacitySlider",
    Callback = function(value)
        getgenv().AiriConfig.ESPOpacity = value
        if VisualsModule and VisualsModule.SetOpacity then pcall(VisualsModule.SetOpacity, value) end
    end
})

Tabs.Visuals:CreateSection("Aimbot Settings")
Tabs.Visuals:CreateToggle({
    Name = "Enable Aimbot (Hold RMB)",
    CurrentValue = getgenv().AiriConfig.AimbotEnabled,
    Flag = "AimbotToggle",
    Callback = function(state)
        getgenv().AiriConfig.AimbotEnabled = state
    end
})

Tabs.Visuals:CreateSlider({
    Name = "Aimbot Smoothness",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = getgenv().AiriConfig.AimbotSmooth,
    Flag = "AimbotSmoothSlider",
    Callback = function(value)
        getgenv().AiriConfig.AimbotSmooth = value
    end
})

Tabs.Visuals:CreateSlider({
    Name = "Aimbot FOV",
    Range = {0, 500},
    Increment = 1,
    CurrentValue = getgenv().AiriConfig.AimbotFOV,
    Flag = "AimbotFOVSlider",
    Callback = function(value)
        getgenv().AiriConfig.AimbotFOV = value
    end
})

-----------------------------------------
-- SETTINGS TAB
-----------------------------------------
Tabs.Settings:CreateSection("UI Settings")
Tabs.Settings:BuildThemeSection()

-----------------------------------------
-- INITIALIZE MODULES
-----------------------------------------
-- Anti-Detect harus diinisialisasi paling awal
if AntiDetectModule and AntiDetectModule.Init then pcall(AntiDetectModule.Init) end
if CombatModule and CombatModule.Init then pcall(CombatModule.Init) end
if MovementModule and MovementModule.Init then pcall(MovementModule.Init) end
if VisualsModule and VisualsModule.Init then pcall(VisualsModule.Init) end

print("[Airi Hub] Successfully loaded all UI and modules.")
