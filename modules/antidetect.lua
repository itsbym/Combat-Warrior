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
    print("[Airi Hub] Anti-Detect V3 (Restored) initializing...")

    -- ===========================================
    -- 1. REQUIRE INTERNAL MODULES
    -- ===========================================
    local Network = nil
    local AntiCheatHandler = nil
    
    local networkSuccess, networkResult = pcall(function()
        return require(ReplicatedStorage.Shared.Vendor.Network)
    end)
    if networkSuccess then Network = networkResult end
    
    local acSuccess, acResult = pcall(function()
        return require(ReplicatedStorage.Shared.Source.AntiCheat.AntiCheatHandler)
    end)
    if acSuccess then AntiCheatHandler = acResult end
    
    -- ===========================================
    -- 2. NULLIFY ANTICHEAT LOGIC (Silent)
    -- ===========================================
    -- NOTE: Kita TIDAK me-hook .punish atau .getIsAcDisabled secara langsung
    -- untuk menghindari deteksi heartbeat anti-tamper.
    -- Sebagai gantinya, kita memblokir EFEK dari fungsi tersebut via metamethods.

    -- ===========================================
    -- 3. NETWORK TELEMETRY SILENCER
    -- ===========================================
    if Network and not getgenv()._AiriNetworkHookDone then
        local oldFireServer
        pcall(function()
            oldFireServer = hookfunction(Network.FireServer, function(self, remoteName, ...)
                if type(remoteName) == "string" then
                    -- Blokir pelaporan telemetry (LogKick / LogACTrigger)
                    if remoteName == "LogKick" or remoteName == "LogACTrigger" then
                        return nil
                    end
                    -- Restore No Fall Damage
                    local Config = getgenv().AiriConfig
                    if Config and Config.NoFallDamage and (remoteName == "TakeFallDamage" or remoteName == "StartFallDamage") then
                        return nil
                    end
                end
                return oldFireServer(self, remoteName, ...)
            end)
        end)
        getgenv()._AiriNetworkHookDone = true
    end
    
    -- ===========================================
    -- 4. UNIFIED METAMETHOD PROTECTION (Invisible Shield)
    -- ===========================================
    if not getgenv()._AiriMetamethodHookDone then
        local OldNamecall
        
        local hookSuccess, hookErr = pcall(function()
            OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}

                if not checkcaller() then
                    -- Agresif Kick/Destroy Protection (V3 Logic)
                    local k_ok, k_res = pcall(function() return method == "Kick" and self == LocalPlayer end)
                    if k_ok and k_res then return nil end
                    
                    local d_ok, d_res = pcall(function() return (method == "Destroy" or method == "destroy") and self == LocalPlayer end)
                    if d_ok and d_res then return nil end

                    -- Blokir direct logging via FireServer remote
                    if method == "FireServer" then
                        local remoteName = args[1]
                        if remoteName == "LogKick" or remoteName == "LogACTrigger" then return nil end
                    end

                    -- BodyMover Integrity (HasTag Spoof) agar cheat pergerakan tidak deteksi
                    if method == "HasTag" then
                        if args[1] == BODY_MOVER_TAG or args[2] == BODY_MOVER_TAG then return true end
                    end
                    
                    -- Attribute Spoof (Lifetime check) untuk BodyMovers
                    if method == "GetAttribute" then
                        local attr = args[1]
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
                        if attr == "Lifetime" then
                            local success, result = pcall(function() return self:IsA("BodyMover") end)
                            if success and result then return 5 end
                        end
                    end
                end
                return OldNamecall(self, ...)
            end))
        end)
        
        if hookSuccess then
            getgenv().OldNamecall = OldNamecall
            getgenv()._AiriMetamethodHookDone = true
        end
    end
    
    print("[Airi Hub V3] AC Total Shutdown FULLY RESTORED & ACTIVE.")
end

function AntiDetect.Unload()
    -- V3 Persistence: Untuk keamanan, kita tidak melepas hook metamethod.
end

return AntiDetect
