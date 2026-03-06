--[[
    Moonnight Hub - Movement Module V4.0 (Absolute Source Accurate)
    Target: Combat Warriors 2026
    Focus: Source-accurate module hooking for Jump, Dash, Ragdoll, and Stamina.
    Zero getgc loops used.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementModule = {}

-- Storage
local OriginalConstants = {
    JumpDelay = nil,
    DashCooldown = nil,
    ToggleRagdoll = nil
}
local Connections = {}

-- Game Modules (Will be populated in Init)
local JumpConstants, DashConstants, RagdollHandler, DefaultStaminaHandler

-- ==========================================
-- MAIN INITIALIZATION
-- ==========================================
function MovementModule.Init()
    print("[Moonnight Hub] Movement V4.0 (Absolute Source Accurate) initializing...")

    -- 1. LOAD GAME MODULES VIA REQUIRE
    local successJump, resJump = pcall(function() return require(ReplicatedStorage.Shared.Source.Jump.JumpConstants) end)
    if successJump and type(resJump) == "table" then JumpConstants = resJump end

    local successDash, resDash = pcall(function() return require(ReplicatedStorage.Shared.Source.Dash.DashConstants) end)
    if successDash and type(resDash) == "table" then DashConstants = resDash end

    local successRagdoll, resRagdoll = pcall(function() return require(ReplicatedStorage.Shared.Source.Ragdoll.RagdollHandler) end)
    if successRagdoll and type(resRagdoll) == "table" then RagdollHandler = resRagdoll end

    local successStamina, resStamina = pcall(function() return require(ReplicatedStorage.Client.Source.DefaultStamina.DefaultStaminaHandlerClient) end)
    if successStamina and type(resStamina) == "table" then DefaultStaminaHandler = resStamina end

    -- 2. CACHE ORIGINALS & APPLY HOOKS
    -- A) Jump Cooldown
    if JumpConstants and JumpConstants.JUMP_DELAY_ADD ~= nil then
        OriginalConstants.JumpDelay = JumpConstants.JUMP_DELAY_ADD
        print("[Moonnight Hub] JumpConstants Hooked.")
    end

    -- B) Dash Cooldown
    if DashConstants and DashConstants.DASH_COOLDOWN ~= nil then
        OriginalConstants.DashCooldown = DashConstants.DASH_COOLDOWN
        print("[Moonnight Hub] DashConstants Hooked.")
    end

    -- C) Anti-Ragdoll Hook
    if RagdollHandler and type(RagdollHandler.toggleRagdoll) == "function" then
        OriginalConstants.ToggleRagdoll = RagdollHandler.toggleRagdoll
        
        RagdollHandler.toggleRagdoll = function(humanoid, isRagdoll, ...)
            if getgenv().MoonnightConfig.AntiRagdoll and isRagdoll then
                return -- Blokir Ragdoll
            end
            return OriginalConstants.ToggleRagdoll(humanoid, isRagdoll, ...)
        end
        print("[Moonnight Hub] RagdollHandler.toggleRagdoll Hooked.")
    end

    if DefaultStaminaHandler and type(DefaultStaminaHandler.getDefaultStamina) == "function" then
        print("[Moonnight Hub] DefaultStaminaHandler Hooked.")
    end

    -- 3. CONSTANTS ENFORCER (Heartbeat) - NO GETGC
    local heartbeatConn = RunService.Heartbeat:Connect(function()
        local Config = getgenv().MoonnightConfig
        if not Config then return end

        -- A & B: Update Module Constants Dynamically
        if JumpConstants and OriginalConstants.JumpDelay ~= nil then
            JumpConstants.JUMP_DELAY_ADD = Config.NoJumpDelay and 0 or OriginalConstants.JumpDelay
        end
        
        if DashConstants and OriginalConstants.DashCooldown ~= nil then
            DashConstants.DASH_COOLDOWN = Config.NoDodgeDelay and 0 or OriginalConstants.DashCooldown
        end

        -- C: Inf Stamina Memory Enforcer using DefaultStaminaHandlerClient
        if Config.InfStamina and DefaultStaminaHandler then
            local myStaminaObj = DefaultStaminaHandler.getDefaultStamina()
            if myStaminaObj then
                pcall(function()
                    myStaminaObj:setStamina(myStaminaObj:getMaxStamina())
                end)
            end
        end
    end)
    table.insert(Connections, heartbeatConn)

    print("[Moonnight Hub] Movement V4.0 ACTIVE. GetGC Removed!")
end

-- ==========================================
-- CLEANUP
-- ==========================================
function MovementModule.Unload()
    -- Stop Loop
    for i = 1, #Connections do
        local conn = Connections[i]
        if conn and conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)

    -- Restore Game Modules
    if JumpConstants and OriginalConstants.JumpDelay ~= nil then
        JumpConstants.JUMP_DELAY_ADD = OriginalConstants.JumpDelay
    end
    if DashConstants and OriginalConstants.DashCooldown ~= nil then
        DashConstants.DASH_COOLDOWN = OriginalConstants.DashCooldown
    end
    if RagdollHandler and OriginalConstants.ToggleRagdoll ~= nil then
        RagdollHandler.toggleRagdoll = OriginalConstants.ToggleRagdoll
    end

    print("[Moonnight Hub] Movement V4.0 Unloaded.")
end

return MovementModule
