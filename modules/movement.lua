--[[
    Airi Hub - Movement Module V2.1 (Cleaned)
    Target: Combat Warriors
    Focus: Inf Stamina (GC Hook), No Jump Delay (State Override)
    
    CHANGELOG V2.1:
    - DIHAPUS: hookmetamethod __namecall (PENYEBAB KONFLIK dengan antidetect.lua)
    - DIHAPUS: Fall Damage hook (sudah di-handle oleh antidetect.lua via __namecall)
    - DIHAPUS: Anti-Ragdoll hook (sudah di-handle oleh antidetect.lua via __namecall)
    - DIHAPUS: No Dodge Delay dari Heartbeat (sudah di-handle oleh antidetect.lua via GetAttribute spoof)
    - TETAP: Infinite Stamina GC hook (one-time scan, bukan loop getgc)
    - TETAP: No Jump Delay (JumpRequest event)
    - TETAP: Heartbeat stamina enforcement (rawset property manipulation)
    
    ATURAN ARSITEKTUR:
    Module ini TIDAK BOLEH hookmetamethod. Semua metamethod hooks
    dipusatkan di antidetect.lua untuk menghindari konflik.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local MovementModule = {}

-- Storage untuk cleanup
local GCHooks = {}
local Connections = {}

-- ==========================================
-- MAIN INITIALIZATION
-- ==========================================
function MovementModule.Init()
    print("[Airi Hub] Movement V2.1 initializing...")

    -- NOTE: Fall Damage, Anti-Ragdoll, dan No Dodge Delay
    -- sekarang di-handle oleh antidetect.lua via unified __namecall hook.
    -- Module ini hanya handle stamina dan jump delay.

    -- 1. NO JUMP DELAY (State Override via UserInput)
    local jumpRequestConn = UserInputService.JumpRequest:Connect(function()
        if getgenv().AiriConfig.NoJumpDelay then
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
    table.insert(Connections, jumpRequestConn)

    -- 2. INFINITE STAMINA (One-Time GC Scan + Hook)
    task.spawn(function()
        if not getgc then
            warn("[Airi Hub] getgc not available - Stamina hook skipped")
            return
        end

        local success, err = pcall(function()
            local gc = getgc(true)
            for i = 1, #gc do
                local obj = gc[i]
                if type(obj) == "table"
                    and rawget(obj, "enableDrain")
                    and type(rawget(obj, "enableDrain")) == "function"
                then
                    local originalDrain = rawget(obj, "enableDrain")

                    -- Cache original values untuk restore saat Unload/toggle off
                    GCHooks[#GCHooks + 1] = {
                        object   = obj,
                        oldDrain = originalDrain,
                        oldGain  = rawget(obj, "gainPerSecond"),
                        oldDelay = rawget(obj, "gainDelay"),
                    }

                    -- Hook: Timpa drain agar stamina tidak berkurang
                    obj.enableDrain = newcclosure(function(self, ...)
                        if getgenv().AiriConfig.InfStamina then
                            return -- Bypass drain
                        end
                        return originalDrain(self, ...)
                    end)
                end
            end
        end)

        if not success then
            warn("[Airi Hub] Stamina GC hook failed: " .. tostring(err))
        else
            print("[Airi Hub] Stamina GC hook active. Found " .. #GCHooks .. " drain object(s).")
        end
    end)

    -- 3. STAMINA ENFORCEMENT (Heartbeat - rawset property manipulation)
    --    Hanya handle stamina values. Dodge delay sudah di antidetect.
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        local Config = getgenv().AiriConfig
        if not Config then return end

        -- Enforce stamina values via rawset (langsung ke memory)
        if Config.InfStamina then
            for i = 1, #GCHooks do
                local obj = GCHooks[i].object
                if obj then
                    rawset(obj, "gainPerSecond", 9999)
                    rawset(obj, "gainDelay", 0)

                    local maxStam = rawget(obj, "_maxStamina")
                    if maxStam then
                        rawset(obj, "_stamina", maxStam)
                    end
                end
            end
        else
            -- Restore values jika InfStamina dimatikan
            for i = 1, #GCHooks do
                local hookData = GCHooks[i]
                local obj = hookData.object
                if obj and rawget(obj, "gainPerSecond") == 9999 then
                    rawset(obj, "gainPerSecond", hookData.oldGain)
                    rawset(obj, "gainDelay", hookData.oldDelay)
                end
            end
        end
    end)
    table.insert(Connections, heartbeatConn)

    print("[Airi Hub] Movement V2.1 ACTIVE.")
end

-- ==========================================
-- CLEANUP (Anti Memory-Leak)
-- ==========================================
function MovementModule.Unload()
    -- NOTE: Tidak ada hookmetamethod restore di sini.
    -- Semua metamethod di-manage oleh antidetect.lua

    -- 1. Disconnect Events
    for i = 1, #Connections do
        local conn = Connections[i]
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)

    -- 2. Restore GC Objects (Stamina)
    for i = 1, #GCHooks do
        local hookData = GCHooks[i]
        local obj = hookData.object
        if obj then
            rawset(obj, "enableDrain", hookData.oldDrain)
            rawset(obj, "gainPerSecond", hookData.oldGain)
            rawset(obj, "gainDelay", hookData.oldDelay)
        end
    end
    table.clear(GCHooks)

    print("[Airi Hub] Movement V2.1 Unloaded.")
end

return MovementModule
