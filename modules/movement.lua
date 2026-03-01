--[[
    Airi Hub - Movement Module
    Target: Combat Warriors
    Focus: Deep Hooking (Inf Stamina, No Jump/Dodge Delay, No Fall Damage, Anti-Ragdoll)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local MovementModule = {}

-- Store original references for Unload()
local OldNamecall = nil
local GCHooks = {}
local Connections = {}

-- ==========================================
-- METAMETHOD HOOKS (Fall Damage & Anti-Ragdoll)
-- ==========================================
OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    -- Hanya filter panggilan dari client game (bukan dari executor)
    if not checkcaller() then
        -- Hook Fall Damage (Remote Event Filter)
        if method == "FireServer" then
            if type(args[1]) == "string" and (args[1] == "TakeFallDamage" or args[1] == "StartFallDamage") then
                if getgenv().AiriConfig.NoFallDamage then
                    return nil -- Drop the remote call silently
                end
            end
            
        -- Hook Anti-Ragdoll (Attribute Hook)
        elseif method == "GetAttribute" then
            if getgenv().AiriConfig.AntiRagdoll and type(args[1]) == "string" then
                local attr = args[1]
                if attr == "IsRagdolledServer" or attr == "IsRagdolledClient" then
                    return false
                elseif attr == "RagdollDisabledClient" or attr == "RagdollDisabledServer" then
                    return true
                end
            end
        end
    end

    return OldNamecall(self, ...)
end))

-- ==========================================
-- MAIN INITIALIZATION
-- ==========================================
function MovementModule.Init()
    -- 1. NO JUMP DELAY (State Override via UserInput)
    local jumpRequestConn = UserInputService.JumpRequest:Connect(function()
        if getgenv().AiriConfig.NoJumpDelay then
            local char = LocalPlayer.Character
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
                    -- Bypass internal wait states dengan memaksa state Jumping secara real-time
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
    table.insert(Connections, jumpRequestConn)

    -- 2. INFINITE STAMINA (Garbage Collection Hook)
    task.spawn(function()
        if not getgc then return end
        
        local success, err = pcall(function()
            for _, obj in pairs(getgc(true)) do
                if type(obj) == "table" and rawget(obj, "enableDrain") and type(rawget(obj, "enableDrain")) == "function" then
                    local originalDrain = rawget(obj, "enableDrain")
                    
                    -- Simpan state original untuk fungsi Unload dan toggle off
                    table.insert(GCHooks, {
                        object = obj,
                        oldDrain = originalDrain,
                        oldGain = rawget(obj, "gainPerSecond"),
                        oldDelay = rawget(obj, "gainDelay")
                    })
                    
                    -- Hook: Timpa method drain untuk mencegah pengurangan stamina
                    obj.enableDrain = newcclosure(function(self, ...)
                        if getgenv().AiriConfig.InfStamina then
                            return -- Return kosong = bypass logic pengurangan
                        end
                        return originalDrain(self, ...)
                    end)
                end
            end
        end)
        
        if not success then
            warn("[Airi Hub] Failed to execute GC hook for Stamina: ", tostring(err))
        end
    end)

    -- 3. RUNTIME ENFORCEMENT (Heartbeat Loop)
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character

        -- Manipulasi Properti Stamina & Fallback
        for _, hookData in ipairs(GCHooks) do
            local obj = hookData.object
            if getgenv().AiriConfig.InfStamina then
                rawset(obj, "gainPerSecond", 9999)
                rawset(obj, "gainDelay", 0)
                
                local maxStam = rawget(obj, "_maxStamina")
                if maxStam then
                    rawset(obj, "_stamina", maxStam)
                end
            else
                if rawget(obj, "gainPerSecond") == 9999 then
                    rawset(obj, "gainPerSecond", hookData.oldGain)
                    rawset(obj, "gainDelay", hookData.oldDelay)
                end
            end
        end

        -- No Dodge Delay
        if getgenv().AiriConfig.NoDodgeDelay and char then
            if char:GetAttribute("DashCooldown") then
                char:SetAttribute("DashCooldown", 0)
            end
            if char:GetAttribute("IsDashing") then
                char:SetAttribute("IsDashing", false)
            end
        end
    end)
    table.insert(Connections, heartbeatConn)
end

-- ==========================================
-- CLEANUP FUNCTION (Anti Memory-Leak)
-- ==========================================
function MovementModule:Unload()
    -- 1. Restore Metamethods
    if OldNamecall then
        hookmetamethod(game, "__namecall", OldNamecall)
    end
    
    -- 2. Disconnect Events
    for _, conn in ipairs(Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)
    
    -- 3. Restore GC Objects (Stamina)
    for _, hookData in ipairs(GCHooks) do
        local obj = hookData.object
        if obj then
            rawset(obj, "enableDrain", hookData.oldDrain)
            rawset(obj, "gainPerSecond", hookData.oldGain)
            rawset(obj, "gainDelay", hookData.oldDelay)
        end
    end
    table.clear(GCHooks)
end

return MovementModule