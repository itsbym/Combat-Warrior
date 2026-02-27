--[[
    Airi Hub - Anti-Detect Module
    Target: Combat Warriors
    Focus: Anti-AFK, Local Anti-Cheat Bypass, Client Kick/Ban Prevention
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local AntiDetectModule = {}

-- Store original references for Unload()
local OldNamecall = nil
local OldKick = nil
local Connections = {}

-- Daftar kata kunci remote yang biasanya digunakan untuk report ban/kick ke server
local SuspiciousRemotes = {
    "ban", "kick", "anticheat", "exploit", "crash", "log", "detect"
}

-- ==========================================
-- 1. INITIALIZATION & BYPASS
-- ==========================================
function AntiDetectModule.Init()
    -- 1. Anti-AFK (Mencegah Roblox idle kick setelah 20 menit)
    local idledConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    table.insert(Connections, idledConn)

    -- 2. Hook Namecall (Blokir fungsi Kick & Remote Event deteksi dari Client)
    if not OldNamecall then
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            -- Hanya filter eksekusi yang berasal dari Game Scripts, biarkan executor script jalan
            if not checkcaller() then
                -- Blokir fungsi Kick
                if method == "Kick" or method == "kick" then
                    return nil
                end
                
                -- Blokir Remote Event yang mencurigakan (Anti-Cheat Reports)
                if method == "FireServer" and type(args[1]) == "string" then
                    local remoteName = string.lower(args[1])
                    for _, keyword in ipairs(SuspiciousRemotes) do
                        if remoteName:find(keyword) then
                            -- Blokir pengiriman remote ke server
                            return nil
                        end
                    end
                end
            end

            return OldNamecall(self, ...)
        end))
    end

    -- 3. Hook Fungsi Kick Secara Langsung
    if not OldKick and hookfunction then
        local success, _ = pcall(function()
            OldKick = hookfunction(LocalPlayer.Kick, newcclosure(function(self, ...)
                if not checkcaller() then
                    return nil
                end
                return OldKick(self, ...)
            end))
        end)
    end

    -- 4. Melumpuhkan Modul AntiCheat Lokal (Spesifik Combat Warriors)
    task.spawn(function()
        local success, err = pcall(function()
            -- Exact path berdasarkan dump structure Combat Warriors
            local AntiCheatHandler = ReplicatedStorage:WaitForChild("Client", 5)
            if AntiCheatHandler then
                AntiCheatHandler = AntiCheatHandler:WaitForChild("Source", 5)
                if AntiCheatHandler then
                    AntiCheatHandler = AntiCheatHandler:WaitForChild("AntiCheat", 5)
                    if AntiCheatHandler then
                        AntiCheatHandler = AntiCheatHandler:WaitForChild("AntiCheatHandlerClient", 5)
                    end
                end
            end
            
            if AntiCheatHandler then
                -- Kumpulkan modul AntiCheat utama dan sub-modulnya
                local acModules = { AntiCheatHandler }
                for _, subModule in ipairs(AntiCheatHandler:GetChildren()) do
                    if subModule:IsA("ModuleScript") then
                        table.insert(acModules, subModule)
                    end
                end

                -- Melumpuhkan setiap fungsi yang ada di dalam tabel module yang di-require
                for _, module in ipairs(acModules) do
                    if require and hookfunction then
                        pcall(function()
                            local modData = require(module)
                            if type(modData) == "table" then
                                for funcName, func in pairs(modData) do
                                    if type(func) == "function" then
                                        -- Mengganti fungsi asli anticheat dengan fungsi kosong (bypass)
                                        hookfunction(func, function() return end)
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end)
        
        if not success then
            warn("[Airi Hub] Failed to execute deep Anti-Cheat module bypass:", tostring(err))
        end
    end)
    
    print("[Airi Hub] Anti-Detect Initialized. Anti-AFK & Client Kick Bypass Active.")
end

-- ==========================================
-- 2. CLEANUP FUNCTION (Restoration)
-- ==========================================
function AntiDetectModule.Unload()
    -- Restore Namecall
    if OldNamecall then
        hookmetamethod(game, "__namecall", OldNamecall)
        OldNamecall = nil
    end

    -- Restore Kick Function
    if OldKick and hookfunction then
        hookfunction(LocalPlayer.Kick, OldKick)
        OldKick = nil
    end

    -- Disconnect Events (Anti-AFK)
    for _, conn in ipairs(Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)
    
    print("[Airi Hub] Anti-Detect Unloaded.")
end

return AntiDetectModule
