--[[
    Airi Hub - Visuals (ESP) Module
    Target: Combat Warriors (FFA Focus)
    Engine: Twilight ESP (Integrated via Nebula-Softworks)
]]

local VisualsModule = {}

-- Global Config Initializer (Fallback if not set by main script)
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

-- Reference to the external Twilight Library
local Twilight = nil

-- Airi Hub Theme
local AIRI_PURPLE = Color3.fromRGB(191, 64, 191)

-- Helper: Convert Box Style String to Twilight Int
local function getBoxStyleInt(styleString)
    if styleString == "Corner" then return 1 end
    if styleString == "Normal" then return 2 end
    if styleString == "3D" then return 3 end
    return 2 -- Default Normal
end

-- ==========================================
-- 1. INITIALIZATION
-- ==========================================
function VisualsModule.Init()
    -- Load Twilight ESP Library safely
    local success, result = pcall(function()
        -- Menggunakan URL raw dari repositori resmi Nebula-Softworks/Twilight-ESP
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Twilight-ESP/master/src/init.luau"))()
    end)

    if success and result then
        Twilight = result
        print("[Airi Hub] Twilight ESP Engine Loaded Successfully.")
        VisualsModule.UpdateAll()
    else
        warn("[Airi Hub] Failed to load Twilight ESP: " .. tostring(result))
    end
end

-- ==========================================
-- 2. UPDATE ENGINE (SYNC WITH CONFIG)
-- ==========================================
function VisualsModule.UpdateAll()
    if not Twilight then return end

    local cfg = getgenv().AiriConfig
    
    Twilight:SetOptions({
        Enabled = cfg.ESPEnabled,
        RefreshRate = 1/60,
        MaxDistance = 1000,

        -- Box ESP
        Box = {
            Enabled = cfg.ESPBox,
            Style = getBoxStyleInt(cfg.ESPBoxStyle),
            Thickness = 1,
            Transparency = cfg.ESPOpacity,
            Filled = { 
                Enabled = false, 
                Transparency = 0.6 * cfg.ESPOpacity 
            }
        },

        -- Chams ESP
        Chams = {
            Enabled = { enemy = cfg.ESPChams, friendly = false, ["local"] = false },
            Fill = { Enabled = true, Transparency = 0.5 * cfg.ESPOpacity },
            Outline = { Enabled = true, Thickness = 0.1 }
        },

        -- Skeleton ESP
        Skeleton = {
            Enabled = { enemy = cfg.ESPSkeleton, friendly = false },
            Thickness = 1,
            Transparency = cfg.ESPOpacity
        },

        -- Tracers ESP
        Tracer = {
            Enabled = { enemy = cfg.ESPTracers, friendly = false },
            Origin = 1, 
            Thickness = 1,
            Transparency = cfg.ESPOpacity
        },

        -- Text Info ESP
        Name = { 
            Enabled = { enemy = cfg.ESPNames, friendly = false },
            Style = 1 -- Username
        },
        
        Distance = {
            Enabled = { enemy = cfg.ESPDistances, friendly = false }
        },

        -- Health Bar
        HealthBar = { 
            Enabled = { enemy = cfg.ESPHealthBar, friendly = false },
            Bar = true,
            Text = true
        }
    })
end

-- ==========================================
-- 3. DYNAMIC TOGGLES (For UI Connections)
-- ==========================================
function VisualsModule.ToggleESP(state)
    getgenv().AiriConfig.ESPEnabled = state
    if Twilight then Twilight.Settings.Enabled = state end
end

function VisualsModule.SetBox(state, style)
    getgenv().AiriConfig.ESPBox = state
    if style then getgenv().AiriConfig.ESPBoxStyle = style end
    VisualsModule.UpdateAll()
end

function VisualsModule.SetChams(state)
    getgenv().AiriConfig.ESPChams = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetSkeleton(state)
    getgenv().AiriConfig.ESPSkeleton = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetTracers(state)
    getgenv().AiriConfig.ESPTracers = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetInfo(names, distances, healthbar)
    getgenv().AiriConfig.ESPNames = names
    getgenv().AiriConfig.ESPDistances = distances
    getgenv().AiriConfig.ESPHealthBar = healthbar
    VisualsModule.UpdateAll()
end

function VisualsModule.SetOpacity(value)
    getgenv().AiriConfig.ESPOpacity = math.clamp(value, 0, 1)
    VisualsModule.UpdateAll()
end

-- ==========================================
-- 4. CLEANUP FUNCTION
-- ==========================================
function VisualsModule.Unload()
    if Twilight then
        Twilight:Unload()
        Twilight = nil
    end
end

return VisualsModule
