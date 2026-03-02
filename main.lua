-- ================================================================
-- PRE-HOOK: Pasang SEKETIKA, sebelum apapun (UI, module, dll)
-- Ini "pelindung sementara" selama antidetect.lua belum selesai di-load.
-- Akan di-replace oleh hook lengkap dari AntiDetectModule.Init().
-- ================================================================
do
    local _mt = getrawmetatable(game)
    setreadonly(_mt, false)
    local _oldnc = _mt.__namecall
    _mt.__namecall = newcclosure(function(self, ...)
        local m = getnamecallmethod()
        if not checkcaller() then
            -- Block Kick ke local player
            if m == "Kick" and typeof(self) == "Instance" and self:IsA("Player") then
                return nil
            end
            -- Block Destroy ke local player
            if m == "Destroy" and typeof(self) == "Instance" and self:IsA("Player") then
                return nil
            end
            -- Block AC remote logging
            if m == "FireServer" then
                local a = ...
                if a == "LogKick" or a == "LogACTrigger" then return nil end
            end
        end
        return _oldnc(self, ...)
    end)
    setreadonly(_mt, true)
    -- Simpan referensi original untuk di-restore dengan benar oleh antidetect.lua
    getgenv()._AiriPreHookOriginalNamecall = _oldnc
    print("[Airi Hub] Pre-hook ACTIVE (Kick/Destroy/LogKick blocked).")
end

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

    -- STRATEGI 1: File lokal (paling cepat, tidak butuh internet)
    if readfile then
        local localPaths = {
            "modules/" .. name .. ".lua",
            "./modules/" .. name .. ".lua",
            "Combat-Warrior/modules/" .. name .. ".lua",
            "Combat-Warrior/Combat-Warrior/modules/" .. name .. ".lua",
        }
        for _, path in ipairs(localPaths) do
            local ok, result = pcall(function()
                local code = readfile(path)
                if not code or #code == 0 then return nil end
                print("[Airi Hub] Loaded '" .. name .. "' from local: " .. path)
                return loadstring(code, "=" .. name)()
            end)
            if ok and result and type(result) == "table" then
                return result
            end
        end
    end

    -- STRATEGI 2: GitHub (URL sudah diperbaiki: /refs/heads/main/)
    local url = GITHUB_BASE .. name .. ".lua?t=" .. tostring(tick())
    print("[Airi Hub] Trying GitHub: " .. url)
    local ok, result = pcall(function()
        local code = game:HttpGet(url)
        if not code or #code == 0 then return nil end
        return loadstring(code, "=" .. name)()
    end)
    if ok and result and type(result) == "table" then
        print("[Airi Hub] Loaded '" .. name .. "' from GitHub.")
        return result
    end

    -- STRATEGI 3: Alias fallback untuk visual/visuals
    if name == "visual" then
        return loadModule("visuals")
    end

    warn("[Airi Hub] FAILED to load module: " .. name)
    return nil
end

-- ================================================================
-- PHASE 1: LOAD & INIT ANTI-DETECT - SINKRON, PRIORITAS TERTINGGI
--
-- Ini BLOCKING (tidak di dalam task.spawn).
-- Script tidak lanjut ke UI sampai antidetect selesai di-load dan di-init.
-- Tujuan: hook __namecall yang lengkap harus terpasang SEBELUM UI muncul
-- dan SEBELUM module lain berjalan.
-- ================================================================
print("[Airi Hub] [PHASE 1] Loading AntiDetect (synchronous, priority)...")
local AntiDetectModule = loadModule("antidetect")
if AntiDetectModule and AntiDetectModule.Init then
    local ok, err = pcall(AntiDetectModule.Init)
    if ok then
        print("[Airi Hub] [PHASE 1] AntiDetect ACTIVE. Full hook live.")
    else
        warn("[Airi Hub] [PHASE 1] AntiDetect.Init() error: " .. tostring(err))
        warn("[Airi Hub] Pre-hook masih aktif sebagai fallback.")
    end
else
    warn("[Airi Hub] [PHASE 1] AntiDetect module GAGAL di-load! Pre-hook saja yang aktif.")
end

-- ================================================================
-- PHASE 2: LOAD LUNA UI
-- Dilakukan setelah antidetect aktif.
-- ================================================================
local function fetchLuna()
    print("[Airi Hub] DEBUG: Attempting to load Luna from local file...")

    local ok, localCode = pcall(readfile, "LUNA-LIB-UI/source.lua")
    print("[Airi Hub] DEBUG: Local readfile status: " .. tostring(ok))

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

    print("[Airi Hub] DEBUG: Local file failed, trying GitHub sources...")
    local sources = {
        "https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/refs/heads/master/source.lua",
        "https://raw.githubusercontent.com/AmeloxRUS/guiluna/refs/heads/main/luna.lua",
    }

    for _, url in ipairs(sources) do
        print("[Airi Hub] DEBUG: Trying GitHub URL: " .. url)
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
Tabs.Combat   = Window:CreateTab({ Name = "Combat",   Icon = "code",        ImageSource = "Material", ShowTitle = true })
Tabs.Movement = Window:CreateTab({ Name = "Movement", Icon = "group_work",  ImageSource = "Material", ShowTitle = true })
Tabs.Visuals  = Window:CreateTab({ Name = "Visuals",  Icon = "list",        ImageSource = "Material", ShowTitle = true })
Tabs.Settings = Window:CreateTab({ Name = "Settings", Icon = "settings_phone", ImageSource = "Material", ShowTitle = true })

Window:CreateHomeTab()

-- ================================================================
-- PHASE 3: LOAD MODULE LAIN - ASYNC (background, tidak blocking)
-- Combat, Movement, Visual tidak perlu seblum UI muncul.
-- ================================================================
local CombatModule, MovementModule, VisualsModule

task.spawn(function()
    print("[Airi Hub] [PHASE 3] Loading remaining modules (background)...")

    CombatModule   = loadModule("combat")
    print("[Airi Hub] CombatModule loaded: " .. tostring(CombatModule ~= nil))

    MovementModule = loadModule("movement")
    print("[Airi Hub] MovementModule loaded: " .. tostring(MovementModule ~= nil))

    VisualsModule  = loadModule("visual") or loadModule("visuals")
    print("[Airi Hub] VisualsModule loaded: " .. tostring(VisualsModule ~= nil))

    if CombatModule   and CombatModule.Init   then pcall(CombatModule.Init)   end
    if MovementModule and MovementModule.Init  then pcall(MovementModule.Init)  end
    if VisualsModule  and VisualsModule.Init   then pcall(VisualsModule.Init)   end

    print("[Airi Hub] [PHASE 3] All background modules initialized.")
end)

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
            if VisualsModule and VisualsModule.ToggleESP then
                local ok, err = pcall(VisualsModule.ToggleESP, state)
                if not ok then warn("[Airi Hub] ToggleESP Error: " .. tostring(err)) end
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
