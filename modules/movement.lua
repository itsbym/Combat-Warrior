--[[
    Airi Hub - Movement Module V2.2 (CRASH FIXED)
    Target: Combat Warriors
    Focus: Inf Stamina (GC Hook), No Jump Delay (State Override)
    
    CHANGELOG V2.2:
    - FIX: JumpRequest wrapped with pcall
    - FIX: GetState() wrapped with pcall
    - FIX: All rawset/rawget operations wrapped with pcall
    - FIX: newcclosure wrapped with pcall
    - FIX: Unload function wrapped with pcall
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
    print("[Airi Hub] Movement V2.2 initializing...")

    -- NOTE: Fall Damage, Anti-Ragdoll, dan No Dodge Delay
    -- sekarang di-handle oleh antidetect.lua via unified __namecall hook.
    -- Module ini hanya handle stamina dan jump delay.

    -- 1. NO JUMP DELAY (State Override via UserInput) - with pcall
    local jumpRequestConn
    local jrSuccess, jrErr = pcall(function()
        jumpRequestConn = UserInputService.JumpRequest:Connect(function()
            if getgenv().AiriConfig.NoJumpDelay then
                local char = LocalPlayer.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        -- Safe GetState check
                        local currState
                        local stateSuccess, stateErr = pcall(function()
                            currState = humanoid:GetState()
                        end)
                        if stateSuccess and currState and currState ~= Enum.HumanoidStateType.Dead then
                            pcall(function()
                                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                            end)
                        end
                    end
                end
            end
        end)
    end)
    
    if jrSuccess and jumpRequestConn then
        table.insert(Connections, jumpRequestConn)
    else
        warn("[Airi Hub] JumpRequest connect failed: " .. tostring(jrErr))
    end

    -- 2. INFINITE STAMINA (One-Time GC Scan + Hook) - Full pcall protection
    task.spawn(function()
        if not getgc then
            warn("[Airi Hub] getgc not available - Stamina hook skipped")
            return
        end

        local success, err = pcall(function()
            local gc = getgc(true)
            if not gc then return end
            for i = 1, #gc do
                local obj = gc[i]
                if type(obj) == "table" then
                    -- Safe check for enableDrain
                    local enableDrainFunc = rawget(obj, "enableDrain")
                    if enableDrainFunc and type(enableDrainFunc) == "function" then
                        local originalDrain = enableDrainFunc

                        -- Cache original values untuk restore saat Unload/toggle off
                        local oldGain = rawget(obj, "gainPerSecond")
                        local oldDelay = rawget(obj, "gainDelay")

                        GCHooks[#GCHooks + 1] = {
                            object   = obj,
                            oldDrain = originalDrain,
                            oldGain  = oldGain,
                            oldDelay = oldDelay,
                        }

                        -- Hook: Timpa drain agar stamina tidak berkurang (with pcall)
                        pcall(function()
                            obj.enableDrain = newcclosure(function(self, ...)
                                if getgenv().AiriConfig.InfStamina then
                                    return -- Bypass drain
                                end
                                return originalDrain(self, ...)
                            end)
                        end)
                    end
                end
            end
        end)

        if not success then
            warn("[Airi Hub] Stamina GC hook failed: " .. tostring(err))
        else
            print("[Airi Hub] Stamina GC hook active. Found " .. #GCHooks .. " drain object(s).")
        end
    end)

    -- 3. STAMINA ENFORCEMENT (Heartbeat - rawset with pcall protection)
    local heartbeatConn
    local hbSuccess, hbErr = pcall(function()
        heartbeatConn = RunService.Heartbeat:Connect(function()
            local Config = getgenv().AiriConfig
            if not Config then return end

            -- Enforce stamina values via rawset (langsung ke memory)
            if Config.InfStamina then
                for i = 1, #GCHooks do
                    local obj = GCHooks[i].object
                    if obj then
                        pcall(function()
                            rawset(obj, "gainPerSecond", 9999)
                            rawset(obj, "gainDelay", 0)
                        end)

                        pcall(function()
                            local maxStam = rawget(obj, "_maxStamina")
                            if maxStam then
                                rawset(obj, "_stamina", maxStam)
                            end
                        end)
                    end
                end
            else
                -- Restore values jika InfStamina dimatikan
                for i = 1, #GCHooks do
                    local hookData = GCHooks[i]
                    local obj = hookData.object
                    if obj then
                        pcall(function()
                            local currGain = rawget(obj, "gainPerSecond")
                            if currGain == 9999 then
                                rawset(obj, "gainPerSecond", hookData.oldGain)
                                rawset(obj, "gainDelay", hookData.oldDelay)
                            end
                        end)
                    end
                end
            end
        end)
    end)
    
    if hbSuccess and heartbeatConn then
        table.insert(Connections, heartbeatConn)
    else
        warn("[Airi Hub] Heartbeat connect failed: " .. tostring(hbErr))
    end

    print("[Airi Hub] Movement V2.2 ACTIVE.")
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
        if conn then
            pcall(function()
                if conn.Connected then conn:Disconnect() end
            end)
        end
    end
    table.clear(Connections)

    -- 2. Restore GC Objects (Stamina)
    for i = 1, #GCHooks do
        local hookData = GCHooks[i]
        local obj = hookData.object
        if obj then
            pcall(function()
                rawset(obj, "enableDrain", hookData.oldDrain)
                rawset(obj, "gainPerSecond", hookData.oldGain)
                rawset(obj, "gainDelay", hookData.oldDelay)
            end)
        end
    end
    table.clear(GCHooks)

    print("[Airi Hub] Movement V2.2 Unloaded.")
end

return MovementModule
