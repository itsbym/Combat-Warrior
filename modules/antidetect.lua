--[[
    Airi Hub V3 - Anti-Detect (Total Shutdown - STABLE)
    Target: Combat Warriors 2026
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AntiDetect = {}

-- Constants
local BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
local RAGDOLL_FALSE = {["IsRagdolledServer"] = true, ["IsRagdolledClient"] = true}
local RAGDOLL_TRUE = {["RagdollDisabledClient"] = true, ["RagdollDisabledServer"] = true}

-- Storage for hooks to avoid conflicts
getgenv()._AiriNetworkHookDone = getgenv()._AiriNetworkHookDone or false
getgenv()._AiriMetamethodHookDone = getgenv()._AiriMetamethodHookDone or false

function AntiDetect.Init()
    print("[Airi Hub] Anti-Detect V3 (Modern) initializing...")

    -- ===========================================
    -- 1. REQUIRE INTERNAL MODULES (Game Accurate)
    -- ===========================================
    local Network = nil
    local AntiCheatHandler = nil
    
    -- Menggunakan path asli dari src/ReplicatedStorage/Shared
    local networkSuccess, networkResult = pcall(function()
        return require(ReplicatedStorage.Shared.Vendor.Network)
    end)
    if networkSuccess then Network = networkResult end
    
    -- ===========================================
    -- THE ULTIMATE BYPASS (Credits to Reference Script)
    -- "one line bypass, if you hook punish ur gay!"
    -- Overwriting Flag.getIsMaxed ensures no local punishments are EVER executed, avoiding all honeypots!
    local flagSuccess, flagResult = pcall(function()
        return require(ReplicatedStorage.Shared.Vendor.Flag)
    end)
    
    if flagSuccess and type(flagResult) == "table" then
        if not getgenv()._AiriFlagHookDone then
            -- Replace getIsMaxed so it always returns false/nil
            -- This means no matter how many flags the AC gives us, we are never "maxed" or punished!
            flagResult.getIsMaxed = function() return false end
            getgenv()._AiriFlagHookDone = true
        end
    end
    
    -- ===========================================
    -- 2. SILENCED BYPASS LOGIC (Network Level)
    -- ===========================================
    -- We do NOT use hookmetamethod("__namecall") because it runs thousands of times per frame 
    -- and completely freezes the client (CPU 100% deadlock with pcalls).
    -- Instead, we simply hook the game's internal Network module directly!
    if Network and type(Network.FireServer) == "function" and not getgenv()._AiriNetworkHookDone then
        local originalFireServer = Network.FireServer
        
        Network.FireServer = function(self, remoteName, ...)
            if type(remoteName) == "string" then
                -- Block ALL anti-cheat telemetry and kick requests natively!
                if remoteName == "LogKick" or remoteName == "LogACTrigger" then
                    return nil
                end
                
                -- Block manual exploit damage reporting
                if remoteName:match("Exploit") or remoteName:match("Cheat") then
                    return nil
                end

                local Config = getgenv().AiriConfig
                if Config and Config.NoFallDamage and (remoteName == "TakeFallDamage" or remoteName == "StartFallDamage") then
                    return nil
                end
            end
            
            -- Pass through normally
            return originalFireServer(self, remoteName, ...)
        end
        getgenv()._AiriNetworkHookDone = true
    end

    print("[Airi Hub] AntiDetect V6 (Ultimate Stability) INITIALIZED =====================")
end

function AntiDetect.Unload()
    -- V3 Persistence: Untuk keamanan, kita tidak melepas hook metamethod.
end

return AntiDetect
