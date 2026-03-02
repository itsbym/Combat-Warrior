--[[
    Airi Hub - Anti-Detect Module V2.1 (Surgical Stealth - Fixed)
    Target: Combat Warriors
    
    CHANGELOG V2.1 (Hotfix):
    - DIHAPUS: __index hook (PENYEBAB UTAMA frame drop + game freeze)
    - DIGABUNG: Semua __namecall ke SATU hook tunggal (tidak ada konflik)
    - DIPINDAH: GetAttribute spoof dari __index ke __namecall (ringan)
    - DIPINDAH: Fall damage block & anti-ragdoll dari movement.lua ke sini
    - DITAMBAH: Player:Destroy() block (AC punishment protection)
    
    ARSITEKTUR:
    Module ini adalah SATU-SATUNYA yang boleh hook metamethod.
    Module lain (combat, movement, visual) TIDAK BOLEH hookmetamethod.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local LogService = game:GetService("LogService")

local LocalPlayer = Players.LocalPlayer
local AntiDetectModule = {}

-- Storage untuk cleanup
local OldNamecall
local OldGetLogHistory

-- Constants dari decompiled AC (anticheat_reference.lua)
local BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
local AC_TYPES = {"bcre", "wrdn", "meow"}

-- Pre-cached method names (hindari string allocation per call)
local METHOD_KICK      = "Kick"
local METHOD_DESTROY   = "Destroy"
local METHOD_FIRE      = "FireServer"
local METHOD_HASTAG    = "HasTag"
local METHOD_GETATTR   = "GetAttribute"

-- Lookup tables (O(1) lookup, bukan string compare berulang)
local BLOCKED_AC_REMOTES = {
    ["LogKick"]      = true,
    ["LogACTrigger"] = true,
}

local BLOCKED_FALL_REMOTES = {
    ["TakeFallDamage"]  = true,
    ["StartFallDamage"] = true,
}

local RAGDOLL_RETURN_FALSE = {
    ["IsRagdolledServer"] = true,
    ["IsRagdolledClient"] = true,
}

local RAGDOLL_RETURN_TRUE = {
    ["RagdollDisabledClient"] = true,
    ["RagdollDisabledServer"] = true,
}

-- =============================================
-- INIT
-- =============================================
function AntiDetectModule.Init()
    print("[Airi Hub] Anti-Detect V2.1 initializing...")

    -- ===========================================
    -- 1. RODUX HIJACKING (Disable AC via Rodux State)
    --    Cari Rodux store berdasarkan STRUKTUR, bukan nama
    -- ===========================================
    task.spawn(function()
        if not getgc then
            warn("[Airi Hub] getgc not available - Rodux bypass skipped")
            return
        end

        local store
        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]
            if type(v) == "table"
                and rawget(v, "dispatch")
                and rawget(v, "getState")
            then
                local s, state = pcall(v.getState, v)
                if s and type(state) == "table" and state.antiCheat then
                    store = v
                    break
                end
            end
        end

        if store then
            print("[Airi Hub] Rodux Store ditemukan. Menonaktifkan AC...")
            for _, acType in ipairs(AC_TYPES) do
                pcall(function()
                    store:dispatch({
                        type = "ANTI_CHEAT_DISABLED_COUNTS_SINGLE_ADD",
                        payload = { id = acType }
                    })
                end)
            end
            print("[Airi Hub] AC Rodux states disabled (bcre, wrdn, meow).")
        else
            warn("[Airi Hub] Rodux Store tidak ditemukan - AC state bypass dilewati")
        end
    end)

    -- ===========================================
    -- 2. SINGLE UNIFIED __namecall HOOK
    --    Satu hook untuk SEMUA interception.
    --    Ini menggantikan hook terpisah di antidetect + movement.
    --
    --    Yang di-handle:
    --    [AC]       Player:Kick()         -> Block
    --    [AC]       Player:Destroy()      -> Block
    --    [AC]       :FireServer("LogKick"/...) -> Block
    --    [AC]       :HasTag(BODY_MOVER)   -> Return true
    --    [MOVE]     :FireServer("TakeFallDamage"/...) -> Block
    --    [MOVE]     :GetAttribute("DashCooldown"/...) -> Spoof
    --    [AC]       :GetAttribute("Lifetime") on BodyMover -> Return 5
    -- ===========================================
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()

        -- Hanya intercept panggilan dari GAME (bukan dari executor kita)
        if not checkcaller() then
            local Config = getgenv().AiriConfig

            -- ---- ANTI-KICK ----
            -- AC memanggil Player:Kick(reason) untuk mengeluarkan player
            if method == METHOD_KICK and typeof(self) == "Instance" and self:IsA("Player") then
                return nil
            end

            -- ---- ANTI-DESTROY ----
            -- AC memanggil Player:Destroy() setelah Kick sebagai punishment tambahan
            if method == METHOD_DESTROY and typeof(self) == "Instance" and self:IsA("Player") then
                return nil
            end

            -- ---- FIRESERVER INTERCEPTION ----
            if method == METHOD_FIRE then
                local args = {...}
                local remoteName = args[1]

                if type(remoteName) == "string" then
                    -- Block AC logging remotes (LogKick, LogACTrigger)
                    if BLOCKED_AC_REMOTES[remoteName] then
                        return nil
                    end

                    -- Block fall damage remotes (jika NoFallDamage aktif)
                    if Config and Config.NoFallDamage and BLOCKED_FALL_REMOTES[remoteName] then
                        return nil
                    end
                end
            end

            -- ---- HASTAG SPOOF ----
            -- AC cek CollectionService:HasTag(bodyMover, TAG) untuk validasi
            -- body movers yang dibuat oleh game. Kita return true agar
            -- body movers kita dianggap legitimate.
            if method == METHOD_HASTAG then
                local args = {...}
                -- HasTag(instance, tag) - tag bisa di arg 1 atau 2
                if args[1] == BODY_MOVER_TAG or args[2] == BODY_MOVER_TAG then
                    return true
                end
            end

            -- ---- GETATTRIBUTE SPOOF ----
            -- Menggantikan __index hook yang berat.
            -- GetAttribute dipanggil via :GetAttribute() (namecall),
            -- jadi kita intercept di sini.
            if method == METHOD_GETATTR and Config then
                local args = {...}
                local attr = args[1]

                if type(attr) == "string" then
                    -- Anti-Ragdoll: IsRagdolledServer/Client -> false
                    if Config.AntiRagdoll then
                        if RAGDOLL_RETURN_FALSE[attr] then return false end
                        if RAGDOLL_RETURN_TRUE[attr] then return true end
                    end

                    -- No Dodge Delay: DashCooldown -> 0, IsDashing -> false
                    if Config.NoDodgeDelay then
                        if attr == "DashCooldown" then return 0 end
                        if attr == "IsDashing" then return false end
                    end

                    -- Body Mover Lifetime: AC cek GetAttribute("Lifetime") == 5
                    if attr == "Lifetime"
                        and typeof(self) == "Instance"
                        and self:IsA("BodyMover")
                    then
                        return 5
                    end
                end
            end
        end

        return OldNamecall(self, ...)
    end))

    print("[Airi Hub] Unified __namecall hook active.")

    -- ===========================================
    -- 3. LOG SILENCING (Targeted hookfunction)
    --    Hook GetLogHistory untuk menyembunyikan jejak executor
    --    dari sistem analitik game.
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

    print("[Airi Hub] Anti-Detect V2.1 ACTIVE. Single hook, zero __index overhead.")
end

-- =============================================
-- UNLOAD (Clean Restore)
-- =============================================
function AntiDetectModule.Unload()
    -- Restore __namecall ke original
    if OldNamecall then
        hookmetamethod(game, "__namecall", OldNamecall)
        OldNamecall = nil
    end

    -- Note: GetLogHistory hook tidak perlu di-restore
    -- karena tidak menyebabkan side effects pada gameplay

    print("[Airi Hub] Anti-Detect V2.1 Unloaded.")
end

return AntiDetectModule
