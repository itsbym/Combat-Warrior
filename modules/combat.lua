--[[
    Airi Hub - Combat Module V4.0 (HYDRA-REFERENCE OVERHAUL)
    Target: Combat Warriors
    Features: Hitbox Expander, Aimbot, Auto Parry (Anti-Feint), Anti Parry (CharacterUtil Hook)
    
    Anti-Parry  → Hooks CharacterUtil.getIsHittableCharacterPart (Nevermore) so enemy parry
                  shields don't block our hits.
    Anti-Feint  → Auto-parry ONLY triggers when enemy anim passes startHitDetection marker,
                  so we never get baited by feints.
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Workspace      = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CombatModule = {}
local Connections = {}

-- ==========================================
-- HELPERS
-- ==========================================
local PlayerCharacters = nil
local function getPlayerCharacters()
    if PlayerCharacters then return PlayerCharacters end
    local ok, res = pcall(function() return Workspace:WaitForChild("PlayerCharacters", 10) end)
    if ok then PlayerCharacters = res end
    return PlayerCharacters
end

local function getLocalCharacter()
    local pc = getPlayerCharacters()
    if not pc then return LocalPlayer.Character end
    return pc:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
end

local function isListValid(listStr, targetStr)
    if not listStr or listStr == "" then return false end
    for _, t in ipairs(string.split(string.lower(listStr), ",")) do
        if string.find(string.lower(targetStr), string.match(t, "^%s*(.-)%s*$")) then
            return true
        end
    end
    return false
end

local function isValidTarget(char, teamCheck, whitelistPlayer, blacklistPlayer)
    if not char or not char.Parent or char.Name == LocalPlayer.Name then return false end
    local player = Players:GetPlayerFromCharacter(char) or Players:FindFirstChild(char.Name)
    if not player then return false end -- Changed: non-player models (e.g. tools, shields) are NOT valid targets
    if blacklistPlayer and isListValid(blacklistPlayer, player.Name) then return true end
    if whitelistPlayer and isListValid(whitelistPlayer, player.Name) then return false end
    if teamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then return false end
    local humanoid = char:FindFirstChild("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- ==========================================
-- NEVERMORE MODULE LOADER (for hooking game internals)
-- ==========================================
local NevermoreModules = {}
local NevermoreLoaded = false

local function tryLoadNevermore()
    if NevermoreLoaded then return true end
    local ok = pcall(function()
        local old_identity = getthreadidentity and getthreadidentity() or 8
        setthreadidentity(2)
        local Nevermore = require(ReplicatedStorage.Framework.Nevermore)
        local _lookup = rawget(Nevermore, "_lookupTable")
        if _lookup then
            for name, mod in _lookup do
                if name:sub(1, 1) == "@" then name = name:sub(2) end
                pcall(function() NevermoreModules[name] = require(mod) end)
            end
        end
        setthreadidentity(old_identity)
    end)
    NevermoreLoaded = ok
    if not ok then
        warn("[Airi Hub] Nevermore load failed — anti-parry hook unavailable")
    end
    return ok
end

-- ==========================================
-- ANIMATION MARKER SCRAPER
-- ==========================================
local _markerCache = {}

local function getAnimMarkers(animId)
    if _markerCache[animId] then return _markerCache[animId] end

    local markers = {}
    local ok, ks = pcall(function()
        return KeyframeSequenceProvider:GetKeyframeSequenceAsync(animId)
    end)

    if ok and ks then
        local function recurse(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child:IsA("KeyframeMarker") then
                    local kf = child:FindFirstAncestor("Keyframe")
                    if kf then
                        -- Keep the EARLIEST occurrence of each marker
                        if not markers[child.Name] or kf.Time < markers[child.Name] then
                            markers[child.Name] = kf.Time
                        end
                    end
                end
                if #child:GetChildren() > 0 then
                    recurse(child)
                end
            end
        end
        recurse(ks)
        _markerCache[animId] = markers
    end

    return markers
end

-- ==========================================
-- PARRY SIMULATOR (keypress / VIM approach)
-- ==========================================
local parryDebounce = false

local function simulateParry()
    if parryDebounce then return end
    parryDebounce = true

    local Config = getgenv().AiriConfig
    local holdTime = Config and Config.AutoParryDelay or 0.12

    -- Try Network:FireServer("Parry") first if available
    local firedNetwork = false
    if NevermoreLoaded and NevermoreModules["MeleeWeaponClient"] then
        local ok = pcall(function()
            local localChar = getLocalCharacter()
            if localChar then
                for _, tool in ipairs(localChar:GetChildren()) do
                    if tool:IsA("Tool") and tool:FindFirstChild("Hitboxes") then
                        local metadata = NevermoreModules["MeleeWeaponClient"].getObj(tool)
                        if metadata then
                            NevermoreModules["MeleeWeaponClient"].parry(metadata)
                            firedNetwork = true
                        end
                        break
                    end
                end
            end
        end)
        if ok and firedNetwork then
            task.delay(0.5, function() parryDebounce = false end)
            return
        end
    end

    -- Fallback: keypress simulation (F key = default parry)
    task.spawn(function()
        if keypress and keyrelease then
            pcall(keypress, 0x46) -- F key
            task.wait(holdTime)
            pcall(keyrelease, 0x46)
        else
            local vim = game:GetService("VirtualInputManager")
            pcall(function()
                vim:SendKeyEvent(true, Enum.KeyCode.F, false, game)
                task.wait(holdTime)
                vim:SendKeyEvent(false, Enum.KeyCode.F, false, game)
            end)
        end
        task.delay(0.4, function() parryDebounce = false end)
    end)
end

-- ==========================================
-- ANTI-PARRY ENGINE (CharacterUtil hook)
-- Bypasses enemy parry shields so our hits
-- always land even if they're parrying.
-- ==========================================
local antiParryHooked = false
local _oldHittable = nil

local function hookAntiParry()
    if antiParryHooked then return end
    if not NevermoreLoaded then return end
    local charUtil = NevermoreModules["CharacterUtil"]
    if not charUtil or not charUtil.getIsHittableCharacterPart then
        warn("[Airi Hub] CharacterUtil.getIsHittableCharacterPart not found")
        return
    end

    _oldHittable = charUtil.getIsHittableCharacterPart
    charUtil.getIsHittableCharacterPart = function(part, unused)
        local Config = getgenv().AiriConfig
        if Config and Config.AntiParryEnabled and Config.AntiParry then
            -- Hydra's Anti-Parry logic:
            -- ONLY valid enemy character models are "hittable".
            -- Anything else (Tools, Accessories, Shields, LocalPlayer, Teammates) returns False
            -- This makes raycasts pass through Enemy Parry Shields straight to their Torso/Head.
            if part and typeof(part) == "Instance" then
                if not isValidTarget(part.Parent, Config.AutoParryTeamCheck, Config.AutoParryWhitelistPlayer, Config.AutoParryBlacklistPlayer) then
                    return false
                end
            end
        end
        return _oldHittable(part, unused)
    end

    antiParryHooked = true
    print("[Airi Hub] Anti-Parry hook active (CharacterUtil)")
end

local function unhookAntiParry()
    if not antiParryHooked then return end
    local charUtil = NevermoreModules["CharacterUtil"]
    if charUtil and _oldHittable then
        charUtil.getIsHittableCharacterPart = _oldHittable
    end
    antiParryHooked = false
end

-- ==========================================
-- AUTO-PARRY ENGINE (Anti-Feint aware)
--
-- Monitors every enemy animator every frame.
-- For each playing animation:
--   1. Scrape its animation markers
--   2. If "startHitDetection" marker exists,
--      only trigger parry when anim.TimePosition
--      reaches (marker - threshold) AND hasn't
--      passed marker yet.
--   3. This naturally ignores feints — if enemy
--      cancels the anim before the marker, we
--      never parry.
-- ==========================================
local HumanoidToParry = {}
local _parryTracked = {}  -- animTrack → last triggered state

local function trackEnemy(char)
    if char.Name == LocalPlayer.Name then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    if not table.find(HumanoidToParry, humanoid) then
        table.insert(HumanoidToParry, humanoid)
    end
end

local function cleanHumanoidList()
    local i = #HumanoidToParry
    while i > 0 do
        local hum = HumanoidToParry[i]
        if not hum or not hum.Parent then
            table.remove(HumanoidToParry, i)
        end
        i -= 1
    end
end

-- Called every RenderStepped when AutoParry is enabled
local function updateAutoParry()
    local Config = getgenv().AiriConfig
    if not Config or not Config.AutoParry then return end

    local localChar = getLocalCharacter()
    if not localChar then return end
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    if not localRoot then return end

    local threshold = Config.AutoParryThreshold or 0.15  -- seconds before marker to fire parry
    local range     = Config.AutoParryRange    or 25
    local chance    = Config.AutoParryChance   or 100

    for _, humanoid in ipairs(HumanoidToParry) do
        if not humanoid or not humanoid.Parent then continue end
        local enemyChar = humanoid.Parent
        if enemyChar == localChar then continue end

        -- Validate target
        if not isValidTarget(enemyChar, Config.AutoParryTeamCheck,
            Config.AutoParryWhitelistPlayer, Config.AutoParryBlacklistPlayer) then
            continue
        end

        local enemyRoot = enemyChar:FindFirstChild("HumanoidRootPart")
        if not enemyRoot then continue end
        local dist = (localRoot.Position - enemyRoot.Position).Magnitude
        if dist > range then continue end

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then continue end

        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            if not track or not track.Animation then continue end
            local animId = track.Animation.AnimationId

            local markers = getAnimMarkers(animId)
            if not markers then continue end

            local hitMarker = markers["startHitDetection"]

            if hitMarker then
                -- Anti-Feint: only fire when TimePosition is in [marker-threshold, marker]
                local t = track.TimePosition
                local shouldParry = (t >= math.clamp(hitMarker - threshold, 0, math.huge))
                                 and (t <= hitMarker + 0.05)

                local trackKey = tostring(track) .. "_" .. animId
                local alreadyFired = _parryTracked[trackKey]

                if shouldParry and not alreadyFired then
                    -- Chance check
                    if math.random(1, 100) <= chance then
                        _parryTracked[trackKey] = true
                        task.spawn(simulateParry)
                    end
                elseif not shouldParry then
                    -- Reset so it can fire again on next swing
                    _parryTracked[trackKey] = nil
                end
            else
                -- Fallback: no marker found, use name-based detection
                -- (less accurate — fooled by feints; still better than nothing)
                local animName = animId:lower()
                local animLabel = track.Animation.Name:lower()
                local isAttack = animLabel:find("slash") or animLabel:find("swing")
                             or animLabel:find("strike") or animLabel:find("attack")
                             or animName:find("slash") or animName:find("swing")

                if isAttack and track.TimePosition > 0.05 then
                    local trackKey = tostring(track) .. "_fallback"
                    if not _parryTracked[trackKey] then
                        if math.random(1, 100) <= chance then
                            _parryTracked[trackKey] = true
                            task.spawn(simulateParry)
                            task.delay(1, function() _parryTracked[trackKey] = nil end)
                        end
                    end
                end
            end
        end
    end
end

-- ==========================================
-- AUTO EQUIP  (hydra-reference)
-- Only picks up weapons with "Hitboxes" child  
-- (CW melee marker) OR IsRangedWeapon attribute,
-- ignoring non-combat tools in the backpack.
-- ==========================================
local autoEquipDebounce = false

-- Check if a Tool is a real CW combat weapon
local function isCombatWeapon(tool)
    if not tool or not tool:IsA("Tool") then return false end
    -- Melee: always has a "Hitboxes" folder
    if tool:FindFirstChild("Hitboxes") then return true end
    -- Ranged: has IsRangedWeapon attribute
    if tool:GetAttribute("IsRangedWeapon") then return true end
    -- Fallback: ItemType attribute check (same as Nevermore WeaponMetadata)
    if tool:GetAttribute("ItemType") == "weapon" then return true end
    return false
end

-- Returns the currently equipped CW weapon (or nil)
local function getEquippedWeapon(char)
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if isCombatWeapon(v) then return v end
    end
    return nil
end

local function handleAutoEquip()
    if autoEquipDebounce then return end
    local Config = getgenv().AiriConfig
    if not Config or not Config.AutoEquip then return end

    local localChar = LocalPlayer.Character
    if not localChar then return end
    local humanoid = localChar:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    -- Only equip if no combat weapon is currently held
    if getEquippedWeapon(localChar) then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end

    -- Priority: prefer melee (Hitboxes) → ranged → any weapon attribute
    local preferred = nil
    for _, tool in ipairs(backpack:GetChildren()) do
        if isCombatWeapon(tool) then
            if not preferred then
                preferred = tool
            elseif tool:FindFirstChild("Hitboxes") and not preferred:FindFirstChild("Hitboxes") then
                preferred = tool  -- prefer melee over ranged
            end
        end
    end

    if not preferred then return end

    autoEquipDebounce = true
    local delay = Config.AutoEquipDelay or 0

    if delay > 0 then
        task.delay(delay, function()
            pcall(function()
                -- Re-check (weapon might have been equipped manually during delay)
                if Config.AutoEquip and humanoid.Health > 0 and not getEquippedWeapon(localChar) then
                    humanoid:EquipTool(preferred)
                end
            end)
            task.delay(0.5, function() autoEquipDebounce = false end)
        end)
    else
        pcall(function() humanoid:EquipTool(preferred) end)
        task.delay(0.5, function() autoEquipDebounce = false end)
    end
end

-- ==========================================
-- AIMBOT ENGINE
-- ==========================================
local function getClosestForAimbot()
    local Config = getgenv().AiriConfig
    if not Config then return nil end

    local closestChar = nil
    local shortestDist = Config.AimbotFOV or 150
    local mousePos = UserInputService:GetMouseLocation()

    local pc = getPlayerCharacters()
    if not pc then return nil end

    for _, char in ipairs(pc:GetChildren()) do
        if isValidTarget(char, Config.AimbotTeamCheck, nil, nil) then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
            if root then
                local vec, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen then
                    local dist = (Vector2.new(vec.X, vec.Y) - mousePos).Magnitude
                    if dist < shortestDist then
                        closestChar   = char
                        shortestDist  = dist
                    end
                end
            end
        end
    end
    return closestChar
end

-- ==========================================
-- HITBOX EXPANDER ENGINE
-- ==========================================
local hue = 0
local OriginalSizes = {}

local function ApplyHitboxExtender(deltaTime)
    local Config = getgenv().AiriConfig
    if not Config then return end

    local pc = getPlayerCharacters()
    if not pc then return end

    if Config.HitboxColorMode == "Rainbow" then
        hue = hue + (deltaTime * (Config.HitboxRainbowSpeed or 0.5) * 0.1)
        if hue >= 1 then hue = 0 end
    end

    local currentColor = Config.HitboxColorMode == "Rainbow"
        and Color3.fromHSV(hue, 1, 1)
        or (Config.HitboxStaticColor or Color3.fromRGB(255, 100, 0))

    for _, char in ipairs(pc:GetChildren()) do
        if char.Name == LocalPlayer.Name then continue end
        local humanoid = char:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local targets = {}
        local ht = Config.HitboxTarget or "HumanoidRootPart"
        if     ht == "Head"  then table.insert(targets, char:FindFirstChild("Head"))
        elseif ht == "Torso" then
            table.insert(targets, char:FindFirstChild("Torso"))
            table.insert(targets, char:FindFirstChild("UpperTorso"))
            table.insert(targets, char:FindFirstChild("LowerTorso"))
        elseif ht == "Arms"  then
            table.insert(targets, char:FindFirstChild("Left Arm"))
            table.insert(targets, char:FindFirstChild("Right Arm"))
            table.insert(targets, char:FindFirstChild("LeftUpperArm"))
            table.insert(targets, char:FindFirstChild("RightUpperArm"))
        elseif ht == "Legs"  then
            table.insert(targets, char:FindFirstChild("Left Leg"))
            table.insert(targets, char:FindFirstChild("Right Leg"))
            table.insert(targets, char:FindFirstChild("LeftUpperLeg"))
            table.insert(targets, char:FindFirstChild("RightUpperLeg"))
        else
            table.insert(targets, char:FindFirstChild("HumanoidRootPart"))
        end

        for _, part in ipairs(targets) do
            if part and part:IsA("BasePart") then
                if not OriginalSizes[part] then OriginalSizes[part] = part.Size end
                pcall(function()
                    if Config.HitboxExpander then
                        local sz = Config.HitboxExpanderSize or 10
                        part.Size        = Vector3.new(sz, sz, sz)
                        part.Transparency = Config.HitboxOpacity or 0.5
                        part.Color       = currentColor
                        part.CanCollide  = false
                        part.Material    = Enum.Material.Neon
                    else
                        part.Size        = OriginalSizes[part]
                        part.Transparency = part.Name == "HumanoidRootPart" and 1 or 0
                        part.Material    = Enum.Material.Plastic
                    end
                end)
            end
        end
    end
end

-- ==========================================
-- MAIN INIT
-- ==========================================
function CombatModule.Init()
    print("[Airi Hub] Combat V4.0 initializing...")

    -- 1. Try loading Nevermore for internal hooks
    task.spawn(function()
        local ok = tryLoadNevermore()
        if ok then
            hookAntiParry()
        end
    end)

    -- 2. Build initial humanoid-to-parry list
    local pc = getPlayerCharacters()
    if not pc then
        warn("[Airi Hub] Combat: PlayerCharacters not found")
        return
    end

    for _, char in ipairs(pc:GetChildren()) do
        pcall(trackEnemy, char)
    end

    local addConn = pc.ChildAdded:Connect(function(char)
        pcall(trackEnemy, char)
    end)
    table.insert(Connections, addConn)

    -- 3. Remove humanoids when characters die / leave
    local remConn = pc.ChildRemoved:Connect(function(char)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local idx = table.find(HumanoidToParry, humanoid)
            if idx then table.remove(HumanoidToParry, idx) end
        end
    end)
    table.insert(Connections, remConn)

    -- 4. Main render loop
    local renderConn = RunService.RenderStepped:Connect(function(dt)
        local Config = getgenv().AiriConfig

        -- Hitbox expander
        pcall(ApplyHitboxExtender, dt)

        -- Auto equip
        pcall(handleAutoEquip)

        -- Anti-Parry hook: toggle dynamically
        if Config then
            if Config.AntiParryEnabled and Config.AntiParry and not antiParryHooked and NevermoreLoaded then
                hookAntiParry()
            elseif (not Config.AntiParryEnabled or not Config.AntiParry) and antiParryHooked then
                unhookAntiParry()
            end
        end

        -- Auto Parry (anti-feint)
        pcall(updateAutoParry)

        -- Periodic humanoid list cleanup
        if math.random(1, 120) == 1 then
            cleanHumanoidList()
        end

        -- Aimbot
        if Config and Config.AimbotEnabled then
            local useAim = true
            if Config.AimbotMethod == "Mouse" and
               not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                useAim = false
            end

            if useAim then
                local target = getClosestForAimbot()
                if target and target:FindFirstChild("HumanoidRootPart") then
                    local hitPart = target:FindFirstChild("Head") or target.HumanoidRootPart
                    local targetPos = hitPart.Position
                    local cc = Camera.CFrame
                    local tc = CFrame.new(cc.Position, targetPos)
                    local smooth = Config.AimbotSmooth or 0
                    if smooth > 0 then
                        Camera.CFrame = cc:Lerp(tc, math.clamp(smooth * dt * 10, 0, 1))
                    else
                        Camera.CFrame = tc
                    end
                end
            end
        end
    end)
    table.insert(Connections, renderConn)

    print("[Airi Hub] Combat V4.0 ACTIVE.")
end

function CombatModule:Unload()
    for _, conn in ipairs(Connections) do
        if conn.Connected then conn:Disconnect() end
    end
    table.clear(Connections)

    -- Unhook anti-parry
    unhookAntiParry()

    -- Revert hitboxes
    for part, origSize in pairs(OriginalSizes) do
        if part and part.Parent then
            pcall(function()
                part.Size        = origSize
                part.Transparency = part.Name == "HumanoidRootPart" and 1 or 0
                part.Material    = Enum.Material.Plastic
            end)
        end
    end
    table.clear(OriginalSizes)
    table.clear(HumanoidToParry)
    table.clear(_parryTracked)
    table.clear(_markerCache)
end

return CombatModule