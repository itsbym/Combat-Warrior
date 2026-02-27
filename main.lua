-- Inisialisasi Global Config
getgenv().AiriConfig = getgenv().AiriConfig or {
    -- Combat & Parry
    AutoParry = false,
    AutoParryDelay = 0.1,
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
    AimbotFOV = 100
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
    KeySystem = false, -- Dimatikan agar mudah diakses, ubah ke true jika butuh
    Color = Color3.fromRGB(191, 64, 191) -- Tema warna ungu
})

local Tabs = {}
Tabs.Combat = Window:CreateTab({
    Name = "Combat",
    Icon = "swords",
    ImageSource = "Lucide",
    ShowTitle = true
})

Tabs.Movement = Window:CreateTab({
    Name = "Movement",
    Icon = "person",
    ImageSource = "Material",
    ShowTitle = true
})

Tabs.Visuals = Window:CreateTab({
    Name = "Visuals",
    Icon = "visibility",
    ImageSource = "Material",
    ShowTitle = true
})

-- Home Tab sebaiknya dibuat terakhir atau di awal setelah semua tab di-setup
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
        Config.AutoParry = state
        if CombatModule and CombatModule.ToggleAutoParry then
            pcall(CombatModule.ToggleAutoParry, state)
        end
    end
})

Tabs.Combat:CreateSlider({
    Name = "Auto Parry Delay",
    Range = {0.1, 1},
    Increment = 0.1,
    CurrentValue = getgenv().AiriConfig.AutoParryDelay,
    Flag = "AutoParryDelaySlider",
    Callback = function(value)
        getgenv().AiriConfig.AutoParryDelay = value
    end
})

Tabs.Combat:CreateSection("Combat Assist")
Tabs.Combat:CreateToggle({
    Name = "Anti Parry",
    CurrentValue = getgenv().AiriConfig.AntiParry,
    Flag = "AntiParryToggle",
    Callback = function(state)
        getgenv().AiriConfig.AntiParry = state
        if CombatModule and CombatModule.ToggleAntiParry then
            pcall(CombatModule.ToggleAntiParry, state)
        end
    end
})

Tabs.Combat:CreateToggle({
    Name = "Hitbox Expander",
    Description = "Expands enemy hitboxes for easier hits.",
    CurrentValue = getgenv().AiriConfig.HitboxExpander,
    Flag = "HitboxExpanderToggle",
    Callback = function(state)
        getgenv().AiriConfig.HitboxExpander = state
        if CombatModule and CombatModule.ToggleHitbox then
            pcall(CombatModule.ToggleHitbox, state)
        end
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
        if MovementModule and MovementModule.ToggleInfStamina then
            pcall(MovementModule.ToggleInfStamina, state)
        end
    end
})

Tabs.Movement:CreateToggle({
    Name = "No Jump Delay",
    CurrentValue = getgenv().AiriConfig.NoJumpDelay,
    Flag = "NoJumpDelayToggle",
    Callback = function(state)
        getgenv().AiriConfig.NoJumpDelay = state
        if MovementModule and MovementModule.ToggleNoJumpDelay then
            pcall(MovementModule.ToggleNoJumpDelay, state)
        end
    end
})

Tabs.Movement:CreateToggle({
    Name = "No Dodge Delay",
    CurrentValue = getgenv().AiriConfig.NoDodgeDelay,
    Flag = "NoDodgeDelayToggle",
    Callback = function(state)
        getgenv().AiriConfig.NoDodgeDelay = state
        if MovementModule and MovementModule.ToggleNoDodgeDelay then
            pcall(MovementModule.ToggleNoDodgeDelay, state)
        end
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
        if VisualsModule and VisualsModule.ToggleESP then
            pcall(VisualsModule.ToggleESP, state)
        end
    end
})

Tabs.Visuals:CreateDropdown({
    Name = "ESP Box Style",
    Options = {"Corner", "Normal", "3D"},
    CurrentValue = getgenv().AiriConfig.ESPBoxStyle,
    Flag = "ESPBoxStyleDropdown",
    Callback = function(value)
        getgenv().AiriConfig.ESPBoxStyle = value
        if VisualsModule and VisualsModule.SetBox then
            pcall(VisualsModule.SetBox, getgenv().AiriConfig.ESPBox, value)
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Box",
    CurrentValue = getgenv().AiriConfig.ESPBox,
    Flag = "ESPBoxToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPBox = state
        if VisualsModule and VisualsModule.SetBox then
            pcall(VisualsModule.SetBox, state, getgenv().AiriConfig.ESPBoxStyle)
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Chams",
    CurrentValue = getgenv().AiriConfig.ESPChams,
    Flag = "ESPChamsToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPChams = state
        if VisualsModule and VisualsModule.SetChams then
            pcall(VisualsModule.SetChams, state)
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Skeleton",
    CurrentValue = getgenv().AiriConfig.ESPSkeleton,
    Flag = "ESPSkeletonToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPSkeleton = state
        if VisualsModule and VisualsModule.SetSkeleton then
            pcall(VisualsModule.SetSkeleton, state)
        end
    end
})

Tabs.Visuals:CreateToggle({
    Name = "ESP Tracers",
    CurrentValue = getgenv().AiriConfig.ESPTracers,
    Flag = "ESPTracersToggle",
    Callback = function(state)
        getgenv().AiriConfig.ESPTracers = state
        if VisualsModule and VisualsModule.SetTracers then
            pcall(VisualsModule.SetTracers, state)
        end
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
    end
})

Tabs.Visuals:CreateSection("Aimbot Settings")
Tabs.Visuals:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = getgenv().AiriConfig.AimbotEnabled,
    Flag = "AimbotToggle",
    Callback = function(state)
        getgenv().AiriConfig.AimbotEnabled = state
        if AimbotModule and AimbotModule.ToggleAimbot then
            pcall(AimbotModule.ToggleAimbot, state)
        end
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
        Config.AimbotFOV = value
    end
})

-- Opsi tambahan untuk membangun menu pengaturan/tema bawaan Luna
Tabs.Visuals:BuildThemeSection()

-----------------------------------------
-- INITIALIZE MODULES
-----------------------------------------
-- Memanggil fungsi Init dari masing-masing module apabila module berhasil diload
if CombatModule and CombatModule.Init then pcall(CombatModule.Init) end
if MovementModule and MovementModule.Init then pcall(MovementModule.Init) end
if VisualsModule and VisualsModule.Init then pcall(VisualsModule.Init) end

print("[Airi Hub] Successfully loaded all UI and modules.")
