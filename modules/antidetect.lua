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
    
    local acSuccess, acResult = pcall(function()
        return require(ReplicatedStorage.Shared.Source.AntiCheat.AntiCheatHandler)
    end)
    if acSuccess and type(acResult) == "table" then 
        AntiCheatHandler = acResult 
        
        -- THE ULTIMATE FIX FOR CTD: Hook the punish function to prevent the deliberate while true do crash loop
        if type(AntiCheatHandler.punish) == "function" and not getgenv()._AiriPunishHookDone then
            hookfunction(AntiCheatHandler.punish, function(...)
                -- Do absolutely nothing. Block the punishment entirely.
                return nil
            end)
            getgenv()._AiriPunishHookDone = true
        end
    end
    
    -- ===========================================
    -- 2. SILENCED BYPASS LOGIC
    -- ===========================================
    if Network and type(Network.FireServer) == "function" and not getgenv()._AiriNetworkHookDone then
        local oldFireServer
        oldFireServer = hookfunction(Network.FireServer, function(self, remoteName, ...)
            if typeof(self) == "table" and type(remoteName) == "string" then
                -- Blokir pelaporan telemetry (LogKick / LogACTrigger)
                if remoteName == "LogKick" or remoteName == "LogACTrigger" then
                    print("[Airi Hub] Blocked Network:FireServer -> " .. remoteName)
                    return nil
                end
                
                local Config = getgenv().AiriConfig
                if Config and Config.NoFallDamage and (remoteName == "TakeFallDamage" or remoteName == "StartFallDamage") then
                    return nil
                end
            end
            return oldFireServer(self, remoteName, ...)
        end)
        getgenv()._AiriNetworkHookDone = true
    end
    
    -- ===========================================
    -- 3. UNIFIED METAMETHOD PROTECTION (Invisible Shield)
    -- ===========================================
    if not getgenv()._AiriMetamethodHookDone then
        local OldNamecall
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if not checkcaller() and typeof(self) == "Instance" then
                -- Agresif Kick/Destroy Protection
                if method == "Kick" and self == LocalPlayer then return nil end
                if (method == "Destroy" or method == "destroy") and self == LocalPlayer then return nil end

                -- Blokir direct logging via FireServer remote
                if method == "FireServer" then
                    local remoteName = args[1]
                    if type(remoteName) == "string" and (remoteName == "LogKick" or remoteName == "LogACTrigger") then 
                        return nil 
                    end
                    -- Gunakan self.Name secara langsung, executor modern akan melempar Lua Error (yang tertangkap/diabaikan di hook) 
                    -- HINDARI membuat function() di dalam namecall loop.
                    if self.Name == "LogKick" or self.Name == "LogACTrigger" then
                        return nil
                    end
                end

                -- BodyMover Integrity (HasTag Spoof)
                if method == "HasTag" and args[1] == BODY_MOVER_TAG then
                    return true
                end
                
                -- Attribute Spoof & BodyMover protection
                if method == "GetAttribute" then
                    local attr = args[1]
                    if type(attr) == "string" then
                        local Config = getgenv().AiriConfig
                        if Config then
                            if Config.AntiRagdoll then
                                if RAGDOLL_FALSE[attr] then return false end
                                if RAGDOLL_TRUE[attr] then return true end
                            end
                            if Config.NoDodgeDelay then
                                if attr == "DashCooldown" then return 0 end
                                if attr == "IsDashing" then return false end
                            end
                        end
                        -- Spoof Lifetime attribute for BodyMovers
                        -- Murni cek string atribut. Jangan pernah panggil fungsi obyek 
                        -- dari dalam hook __namecall karena akan bikin Register Corruption atau CTD!
                        if attr == "Lifetime" then
                            return 5
                        end
                    end
                end
            end
            
            if OldNamecall then
                return OldNamecall(self, ...)
            end
            return nil
        end))
        getgenv()._AiriMetamethodHookDone = true
    end
    
    print("[Airi Hub V3] AC Total Shutdown FULLY RESTORED & ACTIVE.")
end

function AntiDetect.Unload()
    -- V3 Persistence: Untuk keamanan, kita tidak melepas hook metamethod.
end

return AntiDetect
