--[[
    Moonnight Hub - Visuals (ESP) Module
    Target: Combat Warriors (FFA Focus)
    Engine: Twilight ESP (Integrated via Nebula-Softworks)
]]

local RunService = game:GetService("RunService")
local VisualsModule = {}
local Connections = {}

-- Global Config Initializer (Fallback)
getgenv().MoonnightConfig = getgenv().MoonnightConfig or {
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
    ESPTeamCheck = true,
    ESPColorMode = "Static",
    ESPStaticColor = Color3.new(1, 1, 1),
    ESPRainbowSpeed = 5
}

local Twilight = nil
local hue = 0

-- Helper: Convert Box Style String
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
    local twilightUrls = {
        "https://raw.githubusercontent.com/Nebula-Softworks/Twilight-ESP/master/src/init.luau",
        "https://raw.githubusercontent.com/Nebula-Softworks/Twilight-ESP/master/src/init.lua",
    }

    local success, result = false, nil

    for _, url in ipairs(twilightUrls) do
        local httpOk, code = pcall(game.HttpGet, game, url, true)
        if httpOk and type(code) == "string" and #code > 0 then
            local lsOk, luaObj = pcall(loadstring, code)
            -- loadstring bisa return nil kalau executor blokir
            if lsOk and type(luaObj) == "function" then
                local execOk, res = pcall(luaObj)
                if execOk and res then
                    success, result = true, res
                    break
                else
                    result = res
                end
            elseif luaObj == nil then
                warn("[Moonnight Hub] Twilight ESP: loadstring return nil (executor blocked?)")
            end
        end
    end

    if success and result then
        Twilight = result
        print("[Moonnight Hub] Twilight ESP Engine Loaded Successfully.")
        VisualsModule.UpdateAll()
        
        -- Rainbow Engine Loop
        local renderConn = RunService.RenderStepped:Connect(function(deltaTime)
            local cfg = getgenv().MoonnightConfig
            if Twilight and cfg.ESPEnabled and cfg.ESPColorMode == "Rainbow" then
                hue = hue + (deltaTime * cfg.ESPRainbowSpeed * 0.1)
                if hue >= 1 then hue = 0 end
                
                local c = Color3.fromHSV(hue, 1, 1)
                Twilight:SetOptions({
                    Box = { Color = c },
                    Chams = { FillColor = c, OutlineColor = c },
                    Skeleton = { Color = c },
                    Tracer = { Color = c },
                    Name = { Color = c },
                    Distance = { Color = c }
                })
            end
        end)
        table.insert(Connections, renderConn)
    else
        warn("[Moonnight Hub] Failed to load Twilight ESP: " .. tostring(result))
    end
end

-- ==========================================
-- 2. UPDATE ENGINE (SYNC WITH CONFIG)
-- ==========================================
function VisualsModule.UpdateAll()
    if not Twilight then return end

    local cfg = getgenv().MoonnightConfig
    
    local showFriendly = not cfg.ESPTeamCheck
    
    local c = cfg.ESPColorMode == "Rainbow" and Color3.fromHSV(hue, 1, 1) or cfg.ESPStaticColor

    Twilight:SetOptions({
        Enabled = cfg.ESPEnabled,
        RefreshRate = 1/60,
        MaxDistance = 5000,

        Box = {
            Enabled = { enemy = cfg.ESPBox, friendly = showFriendly and cfg.ESPBox },
            Style = getBoxStyleInt(cfg.ESPBoxStyle),
            Thickness = 1,
            Transparency = cfg.ESPOpacity,
            Color = c,
            Filled = { 
                Enabled = false, 
                Transparency = 0.6 * cfg.ESPOpacity 
            }
        },

        Chams = {
            Enabled = { enemy = cfg.ESPChams, friendly = showFriendly and cfg.ESPChams, ["local"] = false },
            Fill = { Enabled = true, Transparency = 0.5 * cfg.ESPOpacity },
            Outline = { Enabled = true, Thickness = 0.1 },
            FillColor = c,
            OutlineColor = c
        },

        Skeleton = {
            Enabled = { enemy = cfg.ESPSkeleton, friendly = showFriendly and cfg.ESPSkeleton },
            Thickness = 1,
            Transparency = cfg.ESPOpacity,
            Color = c
        },

        Tracer = {
            Enabled = { enemy = cfg.ESPTracers, friendly = showFriendly and cfg.ESPTracers },
            Origin = 1, 
            Thickness = 1,
            Transparency = cfg.ESPOpacity,
            Color = c
        },

        Name = { 
            Enabled = { enemy = cfg.ESPNames, friendly = showFriendly and cfg.ESPNames },
            Style = 1,
            Color = c
        },
        
        Distance = {
            Enabled = { enemy = cfg.ESPDistances, friendly = showFriendly and cfg.ESPDistances },
            Color = c
        },

        HealthBar = { 
            Enabled = { enemy = cfg.ESPHealthBar, friendly = showFriendly and cfg.ESPHealthBar },
            Bar = true,
            Text = true
        }
    })
end

-- ==========================================
-- 3. DYNAMIC TOGGLES (For UI Connections)
-- ==========================================
function VisualsModule.ToggleESP(state)
    getgenv().MoonnightConfig.ESPEnabled = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetBox(state, style)
    getgenv().MoonnightConfig.ESPBox = state
    if style then getgenv().MoonnightConfig.ESPBoxStyle = style end
    VisualsModule.UpdateAll()
end

function VisualsModule.SetChams(state)
    getgenv().MoonnightConfig.ESPChams = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetSkeleton(state)
    getgenv().MoonnightConfig.ESPSkeleton = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetTracers(state)
    getgenv().MoonnightConfig.ESPTracers = state
    VisualsModule.UpdateAll()
end

function VisualsModule.SetInfo(names, distances, healthbar)
    getgenv().MoonnightConfig.ESPNames = names
    getgenv().MoonnightConfig.ESPDistances = distances
    getgenv().MoonnightConfig.ESPHealthBar = healthbar
    VisualsModule.UpdateAll()
end

function VisualsModule.SetOpacity(value)
    getgenv().MoonnightConfig.ESPOpacity = math.clamp(value, 0, 1)
    VisualsModule.UpdateAll()
end

-- ==========================================
-- 4. CLEANUP FUNCTION
-- ==========================================
function VisualsModule.Unload()
    if Twilight then
        pcall(function() Twilight:Unload() end)
        Twilight = nil
    end
    
    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)
end

return VisualsModule
