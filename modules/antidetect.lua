--[[
    Airi Hub - Anti-Detect Module V2.8 (CRASH FIXED)
    Target: Combat Warriors

    CHANGELOG V2.8:
    - FIX: hookmetamethod wrapped with pcall to prevent crash
    - FIX: GetAttribute BodyMover check wrapped with pcall
    - FIX: Added error handling for all hooks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local LocalPlayer = Players.LocalPlayer

local AntiDetectModule = {}

-- Constants
local BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
local RAGDOLL_FALSE = {["IsRagdolledServer"] = true, ["IsRagdolledClient"] = true}
local RAGDOLL_TRUE = {["RagdollDisabledClient"] = true, ["RagdollDisabledServer"] = true}

function AntiDetectModule.Init()
    print("[Airi Hub] Anti-Detect V2.8 initializing...")

    -- ===========================================
    -- 1. TOTAL AC DISABLE (Membunuh AC dari akarnya)
    -- ===========================================
    pcall(function()
        local AntiCheatHandler = require(ReplicatedStorage.Shared.Source.AntiCheat.AntiCheatHandler)
        
        if type(AntiCheatHandler.getIsAcDisabled) == "function" then
            hookfunction(AntiCheatHandler.getIsAcDisabled, function() return true end)
            print("[Airi Hub] AC Status: COMPLETELY DISABLED (Always True)")
        end
        
        if type(AntiCheatHandler.punish) == "function" then
            hookfunction(AntiCheatHandler.punish, function() return end)
            print("[Airi Hub] AC Punish: NEUTERED")
        end
    end)

    -- ===========================================
    -- 2. NETWORK MODULE HOOK (Memblokir komunikasi rahasia AC)
    -- ===========================================
    pcall(function()
        local Network = require(ReplicatedStorage.Shared.Vendor.Network)
        
        local oldFireServer
        oldFireServer = hookfunction(Network.FireServer, function(self, remoteName, ...)
            if type(remoteName) == "string" then
                -- BLOKIR LAPORAN AC KE SERVER
                if remoteName == "LogKick" or remoteName == "LogACTrigger" then
                    return 
                end
                
                -- BLOKIR FALL DAMAGE
                local Config = getgenv().AiriConfig
                if Config and Config.NoFallDamage and (remoteName == "TakeFallDamage" or remoteName == "StartFallDamage") then
                    return 
                end
            end
            return oldFireServer(self, remoteName, ...)
        end)
        print("[Airi Hub] Network.FireServer Hooked -> AC Telemetry Blocked")
    end)

    -- ===========================================
    -- 3. UNIFIED __namecall HOOK (CRASH PROTECTED)
    -- ===========================================
    local preHookOriginal = getgenv()._AiriPreHookOriginalNamecall
    local OldNamecall
    local hookInstalled = false
    
    local hookSuccess, hookErr = pcall(function()
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()

            if not checkcaller() then
                local Config = getgenv().AiriConfig

                -- Anti Kick & Destroy LocalPlayer
                if method == "Kick" and self == LocalPlayer then return nil end
                if method == "Destroy" and self == LocalPlayer then return nil end

                -- HasTag Spoof (Untuk BodyMover)
                if method == "HasTag" then
                    local arg1, arg2 = ...
                    if arg1 == BODY_MOVER_TAG or arg2 == BODY_MOVER_TAG then return true end
                end

                -- GetAttribute Spoof (with crash protection)
                if method == "GetAttribute" and Config then
                    local attr = ...
                    if type(attr) == "string" then
                        if Config.AntiRagdoll then
                            if RAGDOLL_FALSE[attr] then return false end
                            if RAGDOLL_TRUE[attr] then return true end
                        end
                        if Config.NoDodgeDelay then
                            if attr == "DashCooldown" then return 0 end
                            if attr == "IsDashing" then return false end
                        end
                        if attr == "Lifetime" then
                            -- Safe check for BodyMover with pcall
                            local isBodyMover = pcall(function() return typeof(self) == "Instance" and self:IsA("BodyMover") end)
                            if isBodyMover then return 5 end
                        end
                    end
                end
            end

            return OldNamecall(self, ...)
        end))
    end)
    
    if hookSuccess then
        hookInstalled = true
        -- Restore referensi yang benar
        if preHookOriginal then OldNamecall = preHookOriginal end
        getgenv().OldNamecall = OldNamecall
        getgenv()._AiriPreHookOriginalNamecall = nil
        print("[Airi Hub] Anti-Detect __namecall hook installed.")
    else
        warn("[Airi Hub] __namecall hook failed: " .. tostring(hookErr))
    end

    print("[Airi Hub] Anti-Detect V2.8 FULLY ACTIVE.")
end

function AntiDetectModule.Unload()
    if getgenv().OldNamecall then
        hookmetamethod(game, "__namecall", getgenv().OldNamecall)
        getgenv().OldNamecall = nil
    end
end

return AntiDetectModule