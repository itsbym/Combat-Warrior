-- ================================================================
-- EXECUTION GUARD (allows re-inject by destroying old UI)
-- ================================================================
if getgenv().AiriHubExecuted then
    pcall(function()
        for _, v in ipairs(game:GetService("CoreGui"):GetChildren()) do
            if v.Name == "Luna" then v:Destroy() end
        end
    end)
end
getgenv().AiriHubExecuted = true

-- ================================================================
-- INIT GLOBAL CONFIG
-- ================================================================
getgenv().AiriConfig = getgenv().AiriConfig or {
    -- PARRY CONFIG
    AutoParry = false, AutoParryDelay = 0.1, AutoParryKeybind = "None",
    AutoParryRange = 15, AutoParryFOV = 100, AutoParryTeamCheck = false,
    AutoParryWhitelistPlayer = "", AutoParryBlacklistPlayer = "",
    AutoParryWhitelistTeam = "", AutoParryBlacklistTeam = "",
    AutoParryMode = "Toggle", AutoParryToggleKeybind = "None",
    AutoParryDetection = "Both", AutoParryChance = 100,
    AutoEquip = false, AutoEquipDelay = 0,

    -- NO DELAY / STAMINA
    NoJumpDelay = false, NoDodgeDelay = false, InfStamina = false, NoFallDamage = true, AntiRagdoll = false,

    -- ANTI PARRY
    AntiParryEnabled = false, AntiParryMode = "Toggle", AntiParryToggleKeybind = "None",

    -- HITBOX EXPANDER
    HitboxExpander = false, HitboxExpanderKeybind = "None", HitboxExpanderSize = 5,
    HitboxTarget = "HumanoidRootPart", HitboxOpacity = 0.5,
    HitboxColorMode = "Static", HitboxStaticColor = Color3.fromRGB(255, 0, 0), HitboxRainbowSpeed = 1,

    -- AIMBOT
    AimbotEnabled = false, AimbotMode = "Toggle", AimbotToggleKeybind = "None", AimbotHoldKeybind = "None", AimbotTriggerKeybind = "None",
    AimbotSmooth = 0.5, AimbotFOV = 100, AimbotTeamCheck = false,
    AimbotWhitelistTeam = "", AimbotBlacklistTeam = "", AimbotMethod = "Camera",

    -- ESP
    ESPEnabled = false, ESPMode = "Toggle", ESPToggleKeybind = "None", ESPHoldKeybind = "None",
    ESPTeamCheck = false, ESPWhitelistTeam = "", ESPBlacklistTeam = "",
    ESPOpacity = 1, ESPColorMode = "Static", ESPStaticColor = Color3.fromRGB(255, 255, 255), ESPRainbowSpeed = 1,
    
    -- GENERAL VISUALS
    ShowFOV = true
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
Tabs.Combat   = Window:CreateTab({ Name = "Combat", Icon = "shield", ShowTitle = true })
Tabs.Visuals  = Window:CreateTab({ Name = "Visuals", Icon = "inventory", ShowTitle = true })
Tabs.Aimbot   = Window:CreateTab({ Name = "Aimbot", Icon = "sort", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "archive", ShowTitle = true })



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
-- UI POPULATION (COMBAT TAB)
-----------------------------------------
Tabs.Combat:CreateSection("Auto Parry Settings")
Tabs.Combat:CreateToggle({ Name = "Enable Auto Parry", CurrentValue = Config.AutoParry, Flag = "AutoParryToggle", Callback = function(s) Config.AutoParry = s end })
Tabs.Combat:CreateSlider({ Name = "Parry Delay", Range = {0.1, 1}, Increment = 0.1, CurrentValue = Config.AutoParryDelay, Flag = "AutoParryDelay", Callback = function(v) Config.AutoParryDelay = v end })
Tabs.Combat:CreateKeybind({ Name = "Parry Toggle Keybind", CurrentKeybind = Config.AutoParryToggleKeybind, HoldToInteract = false, Flag = "AutoParryBind", Callback = function(k) if type(k)=="userdata" then Config.AutoParryToggleKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Combat:CreateSlider({ Name = "Parry Range", Range = {5, 50}, Increment = 1, CurrentValue = Config.AutoParryRange, Flag = "AutoParryRange", Callback = function(v) Config.AutoParryRange = v end })
Tabs.Combat:CreateSlider({ Name = "Parry FOV", Range = {10, 360}, Increment = 5, CurrentValue = Config.AutoParryFOV, Flag = "AutoParryFOV", Callback = function(v) Config.AutoParryFOV = v end })
Tabs.Combat:CreateToggle({ Name = "Teamcheck", CurrentValue = Config.AutoParryTeamCheck, Flag = "AutoParryTeam", Callback = function(s) Config.AutoParryTeamCheck = s end })
Tabs.Combat:CreateInput({ Name = "Whitelist Player", PlaceholderText = "Username...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.AutoParryWhitelistPlayer = t end })
Tabs.Combat:CreateInput({ Name = "Blacklist Player", PlaceholderText = "Username...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.AutoParryBlacklistPlayer = t end })
Tabs.Combat:CreateInput({ Name = "Whitelist Team", PlaceholderText = "Team Name...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.AutoParryWhitelistTeam = t end })
Tabs.Combat:CreateInput({ Name = "Blacklist Team", PlaceholderText = "Team Name...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.AutoParryBlacklistTeam = t end })
Tabs.Combat:CreateDropdown({ Name = "Parry Mode", Options = {"Hold", "Toggle", "Trigger"}, Flag = "AutoParryMode", Callback = function(o) Config.AutoParryMode = type(o)=="table" and o[1] or o end })
Tabs.Combat:CreateDropdown({ Name = "Detection Method", Options = {"Animation", "Sound", "Both"}, Flag = "AutoParryDetect", Callback = function(o) Config.AutoParryDetection = type(o)=="table" and o[1] or o end })
Tabs.Combat:CreateSlider({ Name = "Parry Chance (%)", Range = {1, 100}, Increment = 1, CurrentValue = Config.AutoParryChance, Flag = "AutoParryChance", Callback = function(v) Config.AutoParryChance = v end })
Tabs.Combat:CreateToggle({ Name = "Auto Equip Weapon", CurrentValue = Config.AutoEquip, Flag = "AutoEquipTog", Callback = function(s) Config.AutoEquip = s end })
Tabs.Combat:CreateSlider({ Name = "Auto Equip Delay", Range = {0, 2}, Increment = 0.1, CurrentValue = Config.AutoEquipDelay, Flag = "AutoEquipDelay", Callback = function(v) Config.AutoEquipDelay = v end })

Tabs.Combat:CreateSection("Anti Parry")
Tabs.Combat:CreateToggle({ Name = "Enable Anti Parry", CurrentValue = Config.AntiParryEnabled, Flag = "AntiParryTog", Callback = function(s) Config.AntiParryEnabled = s end })
Tabs.Combat:CreateDropdown({ Name = "Anti Parry Mode", Options = {"Hold", "Toggle"}, Flag = "AntiParryMode", Callback = function(o) Config.AntiParryMode = type(o)=="table" and o[1] or o end })
Tabs.Combat:CreateKeybind({ Name = "Anti Parry Keybind", CurrentKeybind = Config.AntiParryToggleKeybind, HoldToInteract = false, Flag = "AntiParryBind", Callback = function(k) if type(k)=="userdata" then Config.AntiParryToggleKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })

Tabs.Combat:CreateSection("No Delay & Movement")
Tabs.Combat:CreateToggle({ Name = "No Jump Delay", CurrentValue = Config.NoJumpDelay, Flag = "NoJumpTog", Callback = function(s) Config.NoJumpDelay = s end })
Tabs.Combat:CreateToggle({ Name = "No Dodge Delay", CurrentValue = Config.NoDodgeDelay, Flag = "NoDodgeTog", Callback = function(s) Config.NoDodgeDelay = s end })
Tabs.Combat:CreateToggle({ Name = "Infinite Stamina", CurrentValue = Config.InfStamina, Flag = "InfStamTog", Callback = function(s) Config.InfStamina = s end })

Tabs.Combat:CreateSection("Hitbox Expander")
Tabs.Combat:CreateToggle({ Name = "Enable Hitbox Expander", CurrentValue = Config.HitboxExpander, Flag = "HitboxTog", Callback = function(s) Config.HitboxExpander = s end })
Tabs.Combat:CreateKeybind({ Name = "Hitbox Keybind", CurrentKeybind = Config.HitboxExpanderKeybind, HoldToInteract = false, Flag = "HitboxBind", Callback = function(k) if type(k)=="userdata" then Config.HitboxExpanderKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Combat:CreateSlider({ Name = "Hitbox Size", Range = {0.1, 50}, Increment = 0.5, CurrentValue = Config.HitboxExpanderSize, Flag = "HitboxSizeBtn", Callback = function(v) Config.HitboxExpanderSize = v end })
Tabs.Combat:CreateDropdown({ Name = "Target Part", Options = {"Head", "Torso", "HumanoidRootPart", "Arms", "Legs"}, Flag = "HitboxTargetOpt", Callback = function(o) Config.HitboxTarget = type(o)=="table" and o[1] or o end })
Tabs.Combat:CreateSlider({ Name = "Opacity", Range = {0, 1}, Increment = 0.1, CurrentValue = Config.HitboxOpacity, Flag = "HitboxOpac", Callback = function(v) Config.HitboxOpacity = v end })
Tabs.Combat:CreateDropdown({ Name = "Color Mode", Options = {"Static", "Rainbow"}, Flag = "HitboxColMode", Callback = function(o) Config.HitboxColorMode = type(o)=="table" and o[1] or o end })
Tabs.Combat:CreateColorPicker({ Name = "Static Color", Color = Config.HitboxStaticColor, Flag = "HitboxColorPick", Callback = function(c) Config.HitboxStaticColor = c end })
Tabs.Combat:CreateSlider({ Name = "Rainbow Speed", Range = {1, 10}, Increment = 1, CurrentValue = Config.HitboxRainbowSpeed, Flag = "HitboxRBSpeed", Callback = function(v) Config.HitboxRainbowSpeed = v end })

-----------------------------------------
-- UI POPULATION (AIMBOT TAB)
-----------------------------------------
Tabs.Aimbot:CreateSection("Aimbot Settings")
Tabs.Aimbot:CreateToggle({ Name = "Enable Aimbot", CurrentValue = Config.AimbotEnabled, Flag = "AimbotTog", Callback = function(s) Config.AimbotEnabled = s end })
Tabs.Aimbot:CreateDropdown({ Name = "Aimbot Mode", Options = {"Hold", "Toggle", "Trigger"}, Flag = "AimMode", Callback = function(o) Config.AimbotMode = type(o)=="table" and o[1] or o end })
Tabs.Aimbot:CreateKeybind({ Name = "Toggle Keybind", CurrentKeybind = Config.AimbotToggleKeybind, HoldToInteract = false, Flag = "AimTogBind", Callback = function(k) if type(k)=="userdata" then Config.AimbotToggleKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Aimbot:CreateKeybind({ Name = "Hold Keybind", CurrentKeybind = Config.AimbotHoldKeybind, HoldToInteract = false, Flag = "AimHoldBind", Callback = function(k) if type(k)=="userdata" then Config.AimbotHoldKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Aimbot:CreateKeybind({ Name = "Trigger Keybind", CurrentKeybind = Config.AimbotTriggerKeybind, HoldToInteract = false, Flag = "AimTrigBind", Callback = function(k) if type(k)=="userdata" then Config.AimbotTriggerKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Aimbot:CreateDropdown({ Name = "Aim Method", Options = {"Camera", "Mouse"}, Flag = "AimMethod", Callback = function(o) Config.AimbotMethod = type(o)=="table" and o[1] or o end })
Tabs.Aimbot:CreateSlider({ Name = "Smoothness", Range = {0, 1}, Increment = 0.1, CurrentValue = Config.AimbotSmooth, Flag = "AimSmooth", Callback = function(v) Config.AimbotSmooth = v end })
Tabs.Aimbot:CreateSlider({ Name = "FOV Size", Range = {0, 500}, Increment = 10, CurrentValue = Config.AimbotFOV, Flag = "AimFOV", Callback = function(v) Config.AimbotFOV = v end })
Tabs.Aimbot:CreateToggle({ Name = "Teamcheck", CurrentValue = Config.AimbotTeamCheck, Flag = "AimTeam", Callback = function(s) Config.AimbotTeamCheck = s end })
Tabs.Aimbot:CreateInput({ Name = "Whitelist Team", PlaceholderText = "Team Name...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.AimbotWhitelistTeam = t end })
Tabs.Aimbot:CreateInput({ Name = "Blacklist Team", PlaceholderText = "Team Name...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.AimbotBlacklistTeam = t end })

-----------------------------------------
-- UI POPULATION (VISUALS TAB)
-----------------------------------------
Tabs.Visuals:CreateSection("ESP Options")
Tabs.Visuals:CreateToggle({ Name = "Enable ESP", CurrentValue = Config.ESPEnabled, Flag = "ESPToggle", Callback = function(s) Config.ESPEnabled = s; if VisualsModule and VisualsModule.ToggleESP then pcall(VisualsModule.ToggleESP, s) end end })
Tabs.Visuals:CreateDropdown({ Name = "ESP Mode", Options = {"Hold", "Toggle"}, Flag = "ESPMode", Callback = function(o) Config.ESPMode = type(o)=="table" and o[1] or o end })
Tabs.Visuals:CreateKeybind({ Name = "Toggle Keybind", CurrentKeybind = Config.ESPToggleKeybind, HoldToInteract = false, Flag = "ESPTogBind", Callback = function(k) if type(k)=="userdata" then Config.ESPToggleKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Visuals:CreateKeybind({ Name = "Hold Keybind", CurrentKeybind = Config.ESPHoldKeybind, HoldToInteract = false, Flag = "ESPHoldBind", Callback = function(k) if type(k)=="userdata" then Config.ESPHoldKeybind = (k.Name=="Escape") and "None" or tostring(k.Name) end end })
Tabs.Visuals:CreateSlider({ Name = "ESP Opacity", Range = {0, 1}, Increment = 0.1, CurrentValue = Config.ESPOpacity, Flag = "ESPOpac", Callback = function(v) Config.ESPOpacity = v end })
Tabs.Visuals:CreateDropdown({ Name = "Color Mode", Options = {"Static", "Rainbow"}, CurrentOption = {Config.ESPColorMode}, Flag = "ESPColMode", Callback = function(o) Config.ESPColorMode = type(o)=="table" and o[1] or o end })
Tabs.Visuals:CreateColorPicker({ Name = "Static Color", Color = Config.ESPStaticColor, Flag = "ESPColPick", Callback = function(c) Config.ESPStaticColor = c end })
Tabs.Visuals:CreateSlider({ Name = "Rainbow Speed", Range = {1, 10}, Increment = 1, CurrentValue = Config.ESPRainbowSpeed, Flag = "ESPRBSpeed", Callback = function(v) Config.ESPRainbowSpeed = v end })
Tabs.Visuals:CreateToggle({ Name = "Teamcheck", CurrentValue = Config.ESPTeamCheck, Flag = "ESPTchk", Callback = function(s) Config.ESPTeamCheck = s end })
Tabs.Visuals:CreateInput({ Name = "Whitelist Team", PlaceholderText = "Team Name...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.ESPWhitelistTeam = t end })
Tabs.Visuals:CreateInput({ Name = "Blacklist Team", PlaceholderText = "Team Name...", RemoveTextAfterFocusLost = false, Callback = function(t) Config.ESPBlacklistTeam = t end })

-----------------------------------------
-- UI POPULATION (SETTINGS)
-----------------------------------------
Tabs.Settings:CreateSection("Script Configurations")
-- ================================================================
-- CONFIGURATION MANAGER (SAVE/LOAD)
-- ================================================================
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local CONFIG_FILE = "AiriHub_CW_Config.json"

local function SaveConfig()
    if writefile then
        local success, json = pcall(function() return HttpService:JSONEncode(Config) end)
        if success then
            writefile(CONFIG_FILE, json)
            print("[Airi Hub] Configuration saved successfully to " .. CONFIG_FILE)
        end
    else
        warn("[Airi Hub] Executor does not support writefile.")
    end
end

local function LoadConfig()
    if readfile and isfile and pcall(isfile, CONFIG_FILE) and isfile(CONFIG_FILE) then
        local success, result = pcall(function()
            local decoded = HttpService:JSONDecode(readfile(CONFIG_FILE))
            for k, v in pairs(decoded) do
                if Config[k] ~= nil then Config[k] = v end
            end
        end)
        if success then
            print("[Airi Hub] Configuration loaded successfully.")
            -- Note: UI elements won't visually update instantly without calling Luna API methods.
            -- But the internal bypass logic will use these variables.
        else
            warn("[Airi Hub] Failed to parse config JSON.")
        end
    end
end

Tabs.Settings:CreateButton({ Name = "Save Configuration", Callback = SaveConfig })
Tabs.Settings:CreateButton({ Name = "Load Configuration", Callback = LoadConfig })

Tabs.Settings:CreateSection("UI Settings")
Tabs.Settings:BuildThemeSection()

-- ================================================================
-- GLOBAL KEYBIND & INPUT MANAGER
-- ================================================================
local StarterGui = game:GetService("StarterGui")

local function IsTyping()
    return UserInputService:GetFocusedTextBox() ~= nil
end

local function Toast(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 2.5,
        })
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or IsTyping() then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local keyName = input.KeyCode.Name

    -- Toggle Hotkeys
    if Config.HitboxExpanderKeybind ~= "None" and Config.HitboxExpanderKeybind == keyName then
        Config.HitboxExpander = not Config.HitboxExpander
        Toast("Hitbox Expander", Config.HitboxExpander and "✅ ON" or "❌ OFF")
    end

    if Config.AutoParryToggleKeybind ~= "None" and Config.AutoParryToggleKeybind == keyName then
        Config.AutoParry = not Config.AutoParry
        Toast("Auto Parry", Config.AutoParry and "✅ ON" or "❌ OFF")
    end

    if Config.AntiParryToggleKeybind ~= "None" and Config.AntiParryToggleKeybind == keyName then
        Config.AntiParryEnabled = not Config.AntiParryEnabled
        Toast("Anti Parry", Config.AntiParryEnabled and "✅ ON" or "❌ OFF")
    end

    if Config.AimbotToggleKeybind ~= "None" and Config.AimbotToggleKeybind == keyName then
        Config.AimbotEnabled = not Config.AimbotEnabled
        Toast("Aimbot", Config.AimbotEnabled and "✅ ON" or "❌ OFF")
    end

    if Config.ESPToggleKeybind ~= "None" and Config.ESPToggleKeybind == keyName then
        Config.ESPEnabled = not Config.ESPEnabled
        if VisualsModule and VisualsModule.ToggleESP then pcall(VisualsModule.ToggleESP, Config.ESPEnabled) end
        Toast("ESP", Config.ESPEnabled and "✅ ON" or "❌ OFF")
    end

    -- Hold Hotkeys (Activation)
    if Config.AimbotHoldKeybind ~= "None" and Config.AimbotHoldKeybind == keyName and Config.AimbotMode == "Hold" then
        Config.AimbotEnabled = true
    end

    if Config.ESPHoldKeybind ~= "None" and Config.ESPHoldKeybind == keyName and Config.ESPMode == "Hold" then
        Config.ESPEnabled = true
        if VisualsModule and VisualsModule.ToggleESP then pcall(VisualsModule.ToggleESP, true) end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed or IsTyping() then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local keyName = input.KeyCode.Name
    
    -- Hold Hotkeys (Deactivation)
    if Config.AimbotHoldKeybind == keyName and Config.AimbotMode == "Hold" then
        Config.AimbotEnabled = false
    end
    
    if Config.ESPHoldKeybind == keyName and Config.ESPMode == "Hold" then
        Config.ESPEnabled = false
        if VisualsModule and VisualsModule.ToggleESP then pcall(VisualsModule.ToggleESP, false) end
    end
end)

print("[Airi Hub] Script fully initialized (V6 Modern UI).")
