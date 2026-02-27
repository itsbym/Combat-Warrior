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
    
    -- Aimbot
    AimbotEnabled = false,
    AimbotSmooth = 0.5,
    AimbotFOV = 100
}

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
local ESPModule = loadModule("esp_wrapper")
local AimbotModule = loadModule("aimbot")

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

Window:CreateHomeTab()

local Tabs = {
    Combat = Window:CreateTab({
        Name = "Combat",
        Icon = "swords",
        ImageSource = "Lucide",
        ShowTitle = true
    }),
    Movement = Window:CreateTab({
        Name = "Movement",
        Icon = "person",
        ImageSource = "Material",
        ShowTitle = true
    }),
    Visuals = Window:CreateTab({
        Name = "Visuals",
        Icon = "visibility",
        ImageSource = "Material",
        ShowTitle = true
    })
}

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
        if ESPModule and ESPModule.ToggleESP then
            pcall(ESPModule.ToggleESP, state)
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
        getgenv().AiriConfig.AimbotFOV = value
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
if ESPModule and ESPModule.Init then pcall(ESPModule.Init) end
if AimbotModule and AimbotModule.Init then pcall(AimbotModule.Init) end

print("[Airi Hub] Successfully loaded all UI and modules.")
