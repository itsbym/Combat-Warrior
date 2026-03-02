--[[
    Airi Hub - Anti-Detect Module V2.2
    Target: Combat Warriors

    CHANGELOG V2.2:
    - FIX: Rodux scan sekarang SINKRON (tidak di dalam task.spawn)
    - FIX: Scan SEMUA Rodux store yang punya antiCheat state (tidak break setelah pertama)
           Ini penting karena AC punya DUA store: per-player session + global map store.
    - FIX: __namecall hook sekarang menggunakan _AiriPreHookOriginalNamecall dari main.lua
           sebagai OldNamecall, bukan hasil hookmetamethod baru.
           Ini memastikan chain: PreHook -> OurFullHook -> OriginalGame (tidak ada loop).
    - TETAP: Unified __namecall (Kick, Destroy, FireServer, HasTag, GetAttribute)
    - TETAP: Log silencing via hookfunction

    ARSITEKTUR:
    - main.lua pasang PRE-HOOK minimal SEKETIKA (baris pertama)
    - AntiDetect.Init() menggantikan pre-hook dengan hook LENGKAP
    - Module lain (combat, movement, visual) TIDAK BOLEH hookmetamethod
]]

local Players      = game:GetService("Players")
local LogService   = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
local AntiDetectModule = {}

-- Storage untuk cleanup
local OldNamecall
local OldGetLogHistory

-- Constants dari decompiled AC (anticheat_reference.lua)
local BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
local AC_TYPES       = {"bcre", "wrdn", "meow"}

-- Pre-cached method names (hindari string comparison cost per-call)
local METHOD_KICK    = "Kick"
local METHOD_DESTROY = "Destroy"
local METHOD_FIRE    = "FireServer"
local METHOD_HASTAG  = "HasTag"
local METHOD_GETATTR = "GetAttribute"

-- Lookup tables O(1)
local BLOCKED_AC_REMOTES = {
    ["LogKick"]      = true,["LogACTrigger"] = true,
}
local BLOCKED_FALL_REMOTES = {["TakeFallDamage"]  = true,
    ["StartFallDamage"] = true,
}
local RAGDOLL_FALSE = {
    ["IsRagdolledServer"] = true,["IsRagdolledClient"] = true,
}
local RAGDOLL_TRUE = {
    ["RagdollDisabledClient"] = true,
    ["RagdollDisabledServer"] = true,
}

-- =============================================
-- INTERNAL: Rodux Bypass (SINKRON)
-- Mencari SEMUA Rodux store yang punya state antiCheat
-- dan dispatch disable action ke semuanya.
-- =============================================
local function disableRoduxAC()
    if not getgc then
        warn("[Airi Hub] getgc tidak tersedia - Rodux bypass dilewati")
        return
    end

    local found = 0
    local gc = getgc(true)

    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table"
            and rawget(v, "dispatch")
            and rawget(v, "getState")
            and type(rawget(v, "dispatch")) == "function"
            and type(rawget(v, "getState")) == "function"
        then
            local s, state = pcall(v.getState, v)
            if s and type(state) == "table" and state.antiCheat then
                found = found + 1
                -- Dispatch disable ke store ini
                for _, acType in ipairs(AC_TYPES) do
                    pcall(v.dispatch, v, {
                        type    = "ANTI_CHEAT_DISABLED_COUNTS_SINGLE_ADD",
                        payload = { id = acType }
                    })
                end
                print("[Airi Hub] Rodux store #" .. found .. " di-disable (bcre, wrdn, meow).")
                -- TIDAK break - terus scan untuk store berikutnya
            end
        end
    end

    if found == 0 then
        warn("[Airi Hub] Tidak ada Rodux store dengan antiCheat state ditemukan.")
    else
        print("[Airi Hub] Total " .. found .. " Rodux store di-disable.")
    end
end

-- =============================================
-- INIT
-- =============================================
function AntiDetectModule.Init()
    print("[Airi Hub] Anti-Detect V2.2 initializing...")

    -- ===========================================
    -- 1. RODUX BYPASS - SINKRON (tidak di task.spawn)
    -- ===========================================
    disableRoduxAC()

    -- ===========================================
    -- 2. UNIFIED __namecall HOOK (LENGKAP)
    -- ===========================================

    -- Ambil original namecall yang disimpan pre-hook
    local preHookOriginal = getgenv()._AiriPreHookOriginalNamecall

    local replacedHook = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        if not checkcaller() then
            local Config = getgenv().AiriConfig

            -- ---- ANTI-KICK ----
            if method == METHOD_KICK and self == LocalPlayer then
                return nil
            end

            -- ---- ANTI-DESTROY ----
            if method == METHOD_DESTROY and self == LocalPlayer then
                return nil
            end

            -- ---- FIRESERVER INTERCEPTION ----
            if method == METHOD_FIRE then
                local remoteName = ...
                if type(remoteName) == "string" then
                    -- Block AC logging (LogKick, LogACTrigger)
                    if BLOCKED_AC_REMOTES[remoteName] then
                        return nil
                    end
                    -- Block fall damage (jika NoFallDamage aktif)
                    if Config and Config.NoFallDamage and BLOCKED_FALL_REMOTES[remoteName] then
                        return nil
                    end
                end
            end

            -- ---- HASTAG SPOOF ----
            if method == METHOD_HASTAG then
                local arg1, arg2 = ...
                if arg1 == BODY_MOVER_TAG or arg2 == BODY_MOVER_TAG then
                    return true
                end
            end

            -- ---- GETATTRIBUTE SPOOF ----
            if method == METHOD_GETATTR and Config then
                local attr = ...
                if type(attr) == "string" then
                    -- Anti-Ragdoll
                    if Config.AntiRagdoll then
                        if RAGDOLL_FALSE[attr] then return false end
                        if RAGDOLL_TRUE[attr]  then return true  end
                    end
                    -- No Dodge Delay
                    if Config.NoDodgeDelay then
                        if attr == "DashCooldown" then return 0     end
                        if attr == "IsDashing"    then return false  end
                    end
                    -- Body Mover Lifetime (AC cek == 5)
                    if attr == "Lifetime"
                        and typeof(self) == "Instance"
                        and self:IsA("BodyMover")
                    then
                        return 5
                    end
                end
            end
        end

        -- Teruskan ke original game namecall
        return OldNamecall(self, ...)
    end))

    -- Pastikan OldNamecall mengarah ke original game (melewati pre-hook jika ada)
    OldNamecall = preHookOriginal or replacedHook

    -- Bersihkan global reference yang tidak lagi dibutuhkan.
    getgenv()._AiriPreHookOriginalNamecall = nil

    print("[Airi Hub] Unified __namecall hook ACTIVE (menggantikan pre-hook).")

    -- ===========================================
    -- 3. LOG SILENCING
    -- ===========================================
    if hookfunction then
        pcall(function()
            OldGetLogHistory = hookfunction(LogService.GetLogHistory, newcclosure(function(self)
                local s, history = pcall(OldGetLogHistory, self)
                if not s or type(history) ~= "table" then return {} end

                local clean = {}
                for i = 1, #history do
                    local log = history[i]
                    if log and log.message then
                        local msg = log.message:lower()
                        if not (msg:find("airi") or msg:find("executor") or msg:find("exploit")) then
                            clean[#clean + 1] = log
                        end
                    end
                end
                return clean
            end))
            print("[Airi Hub] Log silencing active.")
        end)
    end

    print("[Airi Hub] Anti-Detect V2.2 FULLY ACTIVE.")
end

-- =============================================
-- UNLOAD
-- =============================================
function AntiDetectModule.Unload()
    if OldNamecall then
        hookmetamethod(game, "__namecall", OldNamecall)
        OldNamecall = nil
    end
    getgenv()._AiriPreHookOriginalNamecall = nil
    print("[Airi Hub] Anti-Detect V2.2 Unloaded.")
end

return AntiDetectModule
