--[[
    Airi Hub - Anti-Detect Module
    Target: Combat Warriors
    Focus: Anti-AFK, Local Anti-Cheat Bypass, Client Kick/Ban Prevention, Rodux Store Sanitization
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)

local AntiDetectModule = {}

local OldNamecall = nil
local OldKick = nil
local OldIndex = nil
local OldNewIndex = nil
local OldRequire = nil
local Connections = {}
local SpoofedBodyMovers = setmetatable({}, {__mode = "k"})

local BLOCKED_REMOTES = {
    ["logkick"] = true,
    ["logactrigger"] = true,
    ["ban"] = true,
    ["kick"] = true,
    ["anticheat"] = true,
    ["exploit"] = true,
    ["crash"] = true,
    ["detect"] = true
}

-- From AntiCheatConstants decompilation
local BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"
local REQUIRED_BODY_MOVER_TAG = "4f9a51c7-5fb1-43ea-834f-091d74b80d81"

-- Spoofed Rodux store reference
local SpoofedStores = {}

function AntiDetectModule.Init()
    -- Anti-AFK
    local idledConn = LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
    table.insert(Connections, idledConn)

    -- Block notification GUI creation (prevents AC notifications)
    pcall(function()
        if PlayerGui then
            local notifConn = PlayerGui.ChildAdded:Connect(function(child)
                if child:IsA("ScreenGui") and (child.Name:lower():find("notif") or child.Name:lower():find("ac") or child.Name:lower():find("punish")) then
                    task.wait()
                    child.Enabled = false
                    child:Destroy()
                end
            end)
            table.insert(Connections, notifConn)
        end
    end)

    -- Hook __namecall (Network, Remotes, Kick)
    if not OldNamecall then
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = {...}

            if not checkcaller() then
                -- Block Kick
                if method == "Kick" or method == "kick" then
                    warn("[Airi Hub] Blocked Kick: " .. tostring(args[1] or "No reason"))
                    return nil
                end
                
                -- Block AC remote logging
                if method == "FireServer" and type(args[1]) == "string" then
                    local remoteName = string.lower(tostring(args[1]))
                    if BLOCKED_REMOTES[remoteName] then
                        warn("[Airi Hub] Blocked Remote: " .. remoteName)
                        return nil
                    end
                    -- Block LogKick and LogACTrigger specifically
                    if remoteName:find("log") and (remoteName:find("kick") or remoteName:find("ac") or remoteName:find("trigger")) then
                        return nil
                    end
                end
                
                -- Prevent network ownership stripping (rectified punishment)
                if method == "SetNetworkOwner" and type(args[1]) == "nil" then
                    warn("[Airi Hub] Blocked NetworkOwner strip")
                    return nil
                end
                
                -- Block BodyMover tag validation from server
                if method == "HasTag" and args[2] == BODY_MOVER_TAG then
                    return true
                end
            end

            return OldNamecall(self, ...)
        end))
    end

    -- Hook __index (CollectionService.HasTag, GetAttribute)
    if not OldIndex then
        OldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
            if not checkcaller() then
                -- Spoof CollectionService.HasTag for BodyMover validation
                if self == CollectionService and key == "HasTag" then
                    return function(_, instance, tag)
                        if tag == BODY_MOVER_TAG or tag == REQUIRED_BODY_MOVER_TAG then
                            -- If it's a BodyMover, always say it has the tag
                            if instance and instance:IsA("BodyMover") then
                                return true
                            end
                        end
                        return OldIndex(CollectionService, "HasTag")(CollectionService, instance, tag)
                    end
                end
                
                -- Spoof GetAttribute for IsRagdolled checks (referenced in movement.lua)
                if key == "GetAttribute" and typeof(self) == "Instance" then
                    return function(_, attrName)
                        local result = OldIndex(self, "GetAttribute")(self, attrName)
                        -- Spoof ragdoll attributes if AntiRagdoll is enabled
                        if getgenv().AiriConfig and getgenv().AiriConfig.AntiRagdoll then
                            if attrName == "IsRagdolledServer" or attrName == "IsRagdolledClient" then
                                return false
                            elseif attrName == "RagdollDisabledClient" or attrName == "RagdollDisabledServer" then
                                return true
                            end
                        end
                        -- Spoof DashCooldown
                        if getgenv().AiriConfig and getgenv().AiriConfig.NoDodgeDelay then
                            if attrName == "DashCooldown" then
                                return 0
                            elseif attrName == "IsDashing" then
                                return false
                            end
                        end
                        return result
                    end
                end
                
                -- Spoof BodyMover Lifetime attribute
                if key == "GetAttribute" and typeof(self) == "Instance" and self:IsA("BodyMover") then
                    return function(_, attrName)
                        if attrName == "Lifetime" then
                            return true
                        end
                        return OldIndex(self, "GetAttribute")(self, attrName)
                    end
                end
            end
            return OldIndex(self, key)
        end))
    end

    -- Hook __newindex to prevent AC from setting attributes
    if not OldNewIndex then
        OldNewIndex = hookmetamethod(game, "__newindex", newcclosure(function(self, key, value)
            if not checkcaller() then
                -- Prevent AC from setting IsRagdolled attributes
                if key == "IsRagdolledServer" or key == "IsRagdolledClient" then
                    if getgenv().AiriConfig and getgenv().AiriConfig.AntiRagdoll then
                        return OldNewIndex(self, key, false)
                    end
                end
            end
            return OldNewIndex(self, key, value)
        end))
    end

    -- Hook Player.Kick directly
    if not OldKick and hookfunction then
        pcall(function()
            OldKick = hookfunction(LocalPlayer.Kick, newcclosure(function(self, ...)
                if not checkcaller() then
                    warn("[Airi Hub] Blocked direct Kick call")
                    return nil
                end
                return OldKick(self, ...)
            end))
        end)
    end

    -- Deep AC module neutralization
    task.spawn(function()
        pcall(function()
            -- Wait for game to load
            task.wait(3)
            
            local function getAntiCheatModules()
                local modules = {}
                
                local paths = {
                    "ReplicatedStorage.Client.Source.AntiCheat",
                    "ReplicatedStorage.Shared.Source.AntiCheat",
                    "ServerStorage.Server.Source.AntiCheat",
                    "ReplicatedStorage.Shared.Source.Data",
                }
                
                for _, path in ipairs(paths) do
                    local success, folder = pcall(function()
                        local current = game
                        for _, part in ipairs(string.split(path, ".")) do
                            current = current:FindFirstChild(part)
                            if not current then break end
                        end
                        return current
                    end)
                    
                    if success and folder then
                        for _, child in ipairs(folder:GetDescendants()) do
                            if child:IsA("ModuleScript") then
                                table.insert(modules, child)
                            end
                        end
                    end
                end
                
                return modules
            end

            local acModules = getAntiCheatModules()
            
            -- Neutralize AC module functions
            for _, module in ipairs(acModules) do
                pcall(function()
                    local modData = require(module)
                    if type(modData) == "table" then
                        for funcName, func in pairs(modData) do
                            if type(func) == "function" then
                                -- Don't break module structure, just make punishments do nothing
                                if funcName:lower():find("punish") or funcName:lower():find("kick") or funcName:lower():find("ban") or funcName:lower():find("log") then
                                    hookfunction(func, newcclosure(function(...)
                                        warn("[Airi Hub] Blocked AC function: " .. funcName)
                                        return nil
                                    end))
                                elseif funcName:lower():find("check") or funcName:lower():find("detect") or funcName:lower():find("validate") then
                                    hookfunction(func, newcclosure(function(...)
                                        return false -- Validation checks return false (no cheat detected)
                                    end))
                                end
                            end
                        end
                        
                        -- Specifically target the punish function structure from decompilation
                        if modData.punish then
                            hookfunction(modData.punish, newcclosure(function(player, punishmentData, ...)
                                warn("[Airi Hub] Blocked punish call for: " .. tostring(punishmentData and punishmentData.punishType or "unknown"))
                                return nil
                            end))
                        end
                        
                        -- Block createBodyMover validation
                        if modData.createBodyMover then
                            local oldCreate = modData.createBodyMover
                            modData.createBodyMover = function(...)
                                local mover = oldCreate(...)
                                if mover then
                                    SpoofedBodyMovers[mover] = true
                                    pcall(function()
                                        mover:SetAttribute("Lifetime", 5)
                                        CollectionService:AddTag(mover, BODY_MOVER_TAG)
                                    end)
                                end
                                return mover
                            end
                        end
                        
                        -- Spoof getIsBodyMoverCreatedByGame
                        if modData.getIsBodyMoverCreatedByGame then
                            hookfunction(modData.getIsBodyMoverCreatedByGame, newcclosure(function(mover)
                                return true
                            end))
                        end
                        
                        -- Spoof getIsAcDisabled to always return true (disable all AC checks)
                        if modData.getIsAcDisabled then
                            hookfunction(modData.getIsAcDisabled, newcclosure(function(...)
                                return true
                            end))
                        end
                    end
                end)
            end

            -- Hook Rodux Store to prevent AC state changes
            pcall(function()
                local Rodux = require(ReplicatedStorage.Shared.Vendor.Rodux)
                if Rodux and Rodux.Store then
                    local originalCreateStore = Rodux.Store
                    Rodux.Store = function(...)
                        local store = originalCreateStore(...)
                        
                        -- Wrap dispatch
                        local originalDispatch = store.dispatch
                        store.dispatch = function(self, action, ...)
                            if type(action) == "table" and action.type then
                                -- Block all anti-cheat related dispatches
                                if action.type:find("ANTI_CHEAT") or action.type:find("AntiCheat") then
                                    warn("[Airi Hub] Blocked Rodux action: " .. action.type)
                                    return self
                                end
                            end
                            return originalDispatch(self, action, ...)
                        end
                        
                        -- Wrap getState to spoof AC disabled state
                        local originalGetState = store.getState
                        store.getState = function(...)
                            local state = originalGetState(...)
                            if state and state.antiCheat then
                                -- Deep copy and modify
                                local newState = {}
                                for k, v in pairs(state) do
                                    newState[k] = v
                                end
                                newState.antiCheat = {
                                    disabledCounts = {},
                                    disabledFromCounts = {}
                                }
                                -- Mark all AC types as disabled
                                for _, acType in ipairs({"bcre", "wrdn", "meow"}) do
                                    newState.antiCheat.disabledFromCounts[acType] = true
                                    newState.antiCheat.disabledCounts[acType] = 999
                                end
                                return newState
                            end
                            return state
                        end
                        
                        table.insert(SpoofedStores, store)
                        return store
                    end
                end
            end)
        end)
    end)
    
    print("[Airi Hub] Anti-Detect Initialized. Advanced Rodux & Network Bypass Active.")
end

function AntiDetectModule.Unload()
    for _, conn in ipairs(Connections) do
        if conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(Connections)
    
    if OldNamecall then
        hookmetamethod(game, "__namecall", OldNamecall)
        OldNamecall = nil
    end
    
    if OldIndex then
        hookmetamethod(game, "__index", OldIndex)
        OldIndex = nil
    end

    if OldNewIndex then
        hookmetamethod(game, "__newindex", OldNewIndex)
        OldNewIndex = nil
    end

    if OldKick and hookfunction then
        hookfunction(LocalPlayer.Kick, OldKick)
        OldKick = nil
    end

    -- Clear spoofed stores
    table.clear(SpoofedStores)
    
    SpoofedBodyMovers = {}
    
    print("[Airi Hub] Anti-Detect Unloaded.")
end

return AntiDetectModule