-- ================================================================
-- EXECUTION GUARD
-- ================================================================
if getgenv().AiriHubExecuted then
    print("[Airi Hub] Script is already running!")
    return
end
getgenv().AiriHubExecuted = true

-- ================================================================
-- INIT GLOBAL CONFIG
-- ================================================================
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

-- ================================================================
-- FUNGSI HELPER: Load Module (PRIORITAS: Local > GitHub)
-- ================================================================
local GITHUB_BASE = "https://raw.githubusercontent.com/itsbym/Combat-Warrior/refs/heads/main/modules/"

local function loadModule(name)
    print("[Airi Hub] Loading module: " .. name)

    -- STRATEGI 1: File lokal
    if readfile then
        local localPaths = {
            "modules/" .. name .. ".lua",
            "Combat-Warrior/modules/" .. name .. ".lua",
            "Combat-Warrior/Combat-Warrior/modules/" .. name .. ".lua",
        }
        for _, path in ipairs(localPaths) do
            local ok, code = pcall(readfile, path)
            if ok and code and #code > 0 then
                local success, result = pcall(function()
                    return loadstring(code, "=" .. name)()
                end)
                if success and result then
                    print("[Airi Hub] Loaded '" .. name .. "' from local: " .. path)
                    return result
                end
            end
        end
    end

    -- STRATEGI 2: GitHub
    local url = GITHUB_BASE .. name .. ".lua?t=" .. tostring(tick())
    local ok, code = pcall(game.HttpGet, game, url)
    if ok and code and #code > 0 then
        local success, result = pcall(function()
            return loadstring(code, "=" .. name)()
        end)
        if success and result then
            print("[Airi Hub] Loaded '" .. name .. "' from GitHub.")
            return result
        end
    end

    -- STRATEGI 3: Alias fallback
    if name == "visual" then return loadModule("visuals") end
    if name == "visuals" then return loadModule("visual") end

    warn("[Airi Hub] FAILED to load module: " .. name)
    return nil
end

-- ================================================================
-- PHASE 1: LOAD & INIT ANTI-DETECT - SINKRON, PRIORITAS TERTINGGI
-- ================================================================
print("[Airi Hub] [PHASE 1] Loading AntiDetect (synchronous, priority)...")
local AntiDetectModule = loadModule("antidetect")
if AntiDetectModule and AntiDetectModule.Init then
    local ok, err = pcall(AntiDetectModule.Init)
    if ok then
        print("[Airi Hub] [PHASE 1] AntiDetect ACTIVE (V3 Stable).")
    else
        warn("[Airi Hub] [PHASE 1] AntiDetect.Init() error: " .. tostring(err))
    end
else
    warn("[Airi Hub] [PHASE 1] AntiDetect module GAGAL di-load!")
end

-- ================================================================
-- PHASE 2: LOAD LUNA UI
-- ================================================================
local function fetchLuna()
    print("[Airi Hub] DEBUG: Attempting to load Luna UI...")
    
    local ok, localCode = pcall(readfile, "LUNA-LIB-UI/source.lua")
    if ok and type(localCode) == "string" and #localCode > 0 then
        local success, luaObj = pcall(loadstring, localCode)
        if success and type(luaObj) == "function" then
            local result = luaObj()
            if type(result) == "table" then
                print("[Airi Hub] SUCCESS: Loaded Luna from local file!")
                return true, result
            end
        end
    end

    local sources = {
        "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua",
        "https://raw.githubusercontent.com/AmeloxRUS/guiluna/refs/heads/main/luna.lua",
    }

    for _, url in ipairs(sources) do
        local ok2, code = pcall(game.HttpGet, game, url, true)
        if ok2 and type(code) == "string" and #code > 0 then
            local success, luaObj = pcall(loadstring, code)
            if success and type(luaObj) == "function" then
                local result = luaObj()
                if type(result) == "table" then
                    print("[Airi Hub] SUCCESS: Loaded Luna from GitHub!")
                    return true, result
                end
            end
        end
    end

    return false, "semua sumber gagal dimuat"
end

print("[Airi Hub] [PHASE 2] Fetching Luna UI...")
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

if not Window then
    warn("[Airi Hub] Gagal membuat jendela UI")
    return
end

local Tabs = {}
Tabs.Combat   = Window:CreateTab({ Name = "Combat",   Icon = "code",        ImageSource = "Material", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "group_work",  ImageSource = "Material", ShowTitle = true })
Tabs.Visuals  = Window:CreateTab({ Name = "Visuals",  Icon = "list",        ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings_phone", ImageSource = "Material", ShowTitle = true })

Window:CreateHomeTab()

-- ================================================================
-- PHASE 3: LOAD MODULE LAIN - ASYNC (background)
-- ================================================================
local CombatModule, MovementModule, VisualsModule

task.spawn(function()
    print("[Airi Hub] [PHASE 3] Loading background modules...")

    CombatModule   = loadModule("combat")
    MovementModule = loadModule("movement")
    VisualsModule  = loadModule("visual") or loadModule("visuals")

    if CombatModule   and CombatModule.Init   then pcall(CombatModule.Init)   end
    if MovementModule and MovementModule.Init  then pcall(MovementModule.Init)  end
    if VisualsModule  and VisualsModule.Init   then pcall(VisualsModule.Init)   end

    print("[Airi Hub][PHASE 3] All background modules initialized.")
end)

-----------------------------------------
-- UI POPULATION (COMBAT)
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
-- UI POPULATION (MOVEMENT)
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
-- UI POPULATION (VISUALS)
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

-----------------------------------------
-- UI POPULATION (SETTINGS)
-----------------------------------------
Tabs.Settings:CreateSection("UI Settings")
Tabs.Settings:BuildThemeSection()

print("[Airi Hub] Script fully initialized.")
