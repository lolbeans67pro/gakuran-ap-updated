local _a=string.char(104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,97,114,116,120,102,105,99,105,97,108,47,109,97,116,99,104,97,115,116,117,102,102,47,114,101,102,115,47,104,101,97,100,115,47,109,97,105,110,47,103,97,107,114,97,110,46,108,117,97)local _b=string.char(104,116,116,112,115,58,47,47,114,97,119,46,103,105,116,104,117,98,117,115,101,114,99,111,110,116,101,110,116,46,99,111,109,47,97,114,116,120,102,105,99,105,97,108,47,109,97,116,99,104,97,115,116,117,102,102,47,114,101,102,115,47,104,101,97,100,115,47,109,97,105,110,47,97,110,105,109,97,116,105,111,110,116,114,97,99,107,101,114,46,108,117,97)local _c=string.char(95,95,71,97,107,117,114,97,110,67,111,109,98,105,110,101,100,66,97,115,101,76,111,97,100,101,100)local _d=[====[
local _gakuranOffsetsValid = type(offsets) == "table"
    and type(offsets.Misc) == "table"
    and type(offsets.Instance) == "table"
    and type(offsets.AnimationTrack) == "table"
    and type(offsets.Animator) == "table"
    and type(offsets.Misc.AnimationId) == "number"
    and type(offsets.Instance.ClassDescriptor) == "number"
    and type(offsets.Instance.ClassName) == "number"
    and type(offsets.Instance.Name) == "number"
    and type(offsets.AnimationTrack.TimePosition) == "number"
    and type(offsets.AnimationTrack.Animation) == "number"
    and type(offsets.AnimationTrack.Speed) == "number"
    and type(offsets.AnimationTrack.IsPlaying) == "number"
    and type(offsets.Animator.ActiveAnimations) == "number"

if not _gakuranOffsetsValid then
    print("[Gakuran AP Share] offset mirrors unavailable; using embedded fallback")
    offsets = {
        Misc = { AnimationId = 192 },
        Instance = { ClassDescriptor = 24, ClassName = 8, Name = 8 },
        AnimationTrack = {
            Animation = 184,
            Speed = 212,
            TimePosition = 216,
            IsPlaying = 2704,
        },
        Animator = { ActiveAnimations = 2944 },
    }
end

]====]local _e=[====[

-- ===== v6.8.2 Striker runtime registration/timing patch =====
local STRIKER_FIRST_WINDUP = 0.35
local STRIKER_LAST_WINDUP = 0.12
local STRIKER_HIT_COUNT = 4
local STRIKER_PARRY_PHASE = 0.20 / 0.35
local STRIKER_FEINT_REACTION = 0.30

local function GetStrikerReactionTime(displayName)
    local name = tostring(displayName or "")
    local hitIndex = tonumber(string.match(name, "^(%d+)"))

    if hitIndex and hitIndex >= 1 and hitIndex <= STRIKER_HIT_COUNT then
        local alpha = (hitIndex - 1) / (STRIKER_HIT_COUNT - 1)
        local windup = STRIKER_FIRST_WINDUP
            + ((STRIKER_LAST_WINDUP - STRIKER_FIRST_WINDUP) * alpha)
        return math.max(0.01, windup * STRIKER_PARRY_PHASE)
    end

    if name == "M2" or name == "FeintM2" or name == "StrikerFeint" then
        return STRIKER_FEINT_REACTION
    end

    return nil
end

local function ApplyStrikerAnimationConfig(assetId, displayName)
    if not assetId then return false end

    local reactionTime = GetStrikerReactionTime(displayName)
    if reactionTime == nil then return false end

    local key = tostring(assetId)
    local info = GameConfig[key] or {}

    info.Style = "StrikerAnims"
    info.ReactionTime = reactionTime
    info.DefaultReactionTime = nil

    if tostring(displayName) == "M2"
        or tostring(displayName) == "FeintM2"
        or tostring(displayName) == "StrikerFeint" then
        -- Do NOT leave this named M2: the upstream ExecuteParry treats M2 as a
        -- generic heavy and Auto Dodge consumes it. Striker specifically wants
        -- us to ignore the 0.15s fake and parry the real 0.45s kick.
        info.DisplayName = "StrikerFeint"
        info.Heavy = false
        info.StrikerFeint = true
    else
        info.DisplayName = tostring(displayName)
    end

    GameConfig[key] = info
    return true
end

-- First patch whatever Striker IDs the live upstream base already knows.
local patchedUpstreamStrikerCount = 0
for assetId, info in pairs(GameConfig) do
    if type(info) == "table" and info.Style == "StrikerAnims" then
        if ApplyStrikerAnimationConfig(assetId, info.DisplayName) then
            patchedUpstreamStrikerCount += 1
        end
    end
end

-- Emergency fallback IDs cover both the current upstream set and the older set
-- from v6.7. They are only added if neither upstream nor live folder discovery
-- supplies Striker animations, so the Style Configurations tab stays clean.
local STRIKER_FALLBACK_IDS = {
    -- Current upstream IDs.
    ["rbxassetid://127909081017342"] = "1stM1",
    ["rbxassetid://79563637573277"] = "2ndM1",
    ["rbxassetid://118070233153900"] = "3rdM1",
    ["rbxassetid://77710266587706"] = "4thM1",
    ["rbxassetid://114364673509520"] = "M2",
    ["rbxassetid://132840225082238"] = "1stM1",
    ["rbxassetid://88761422474765"] = "2ndM1",
    ["rbxassetid://98462236639320"] = "3rdM1",
    ["rbxassetid://122451562066756"] = "4thM1",

    -- Older IDs used by the v6.7 wrapper.
    ["rbxassetid://116642061934550"] = "1stM1",
    ["rbxassetid://115234849770695"] = "2ndM1",
    ["rbxassetid://85554794950365"] = "3rdM1",
    ["rbxassetid://73777821288331"] = "4thM1",
    ["rbxassetid://99309341097380"] = "M2",
}

local function ReadLiveAnimationId(animationObject)
    -- Prefer the normal property when Matcha exposes it.
    local okProperty, propertyId = pcall(function()
        return animationObject.AnimationId
    end)
    if okProperty and type(propertyId) == "string" and propertyId ~= "" then
        return propertyId
    end

    -- Match the upstream LiteGrabber fallback when the property is unavailable.
    if animationObject and animationObject.Address and memory_read then
        local okMemory, memoryId = pcall(function()
            local animationIdPointer = memory_read("uintptr_t", animationObject.Address + 192)
            if not animationIdPointer or animationIdPointer == 0 then return nil end
            return memory_read("string", animationIdPointer)
        end)
        if okMemory and type(memoryId) == "string" and memoryId ~= "" then
            return memoryId
        end
    end

    return nil
end

local function RegisterLiveStrikerAnimations()
    local ok, registered = pcall(function()
        local replicatedStorage = game:GetService("ReplicatedStorage")
        local animations = replicatedStorage and replicatedStorage:FindFirstChild("Animations")
        local combat = animations and animations:FindFirstChild("Combat")
        local strikerFolder = combat and (
            combat:FindFirstChild("StrikerAnims")
            or combat:FindFirstChild("Striker")
        )

        if not strikerFolder then
            return 0
        end

        local count = 0
        for _, animationObject in ipairs(strikerFolder:GetChildren()) do
            local displayName = animationObject.Name
            if GetStrikerReactionTime(displayName) ~= nil then
                local liveId = ReadLiveAnimationId(animationObject)
                if liveId and ApplyStrikerAnimationConfig(liveId, displayName) then
                    count += 1
                end
            end
        end

        return count
    end)

    if ok and registered and registered > 0 then
        print(string.format("[Gakuran AP Share] registered %d live Striker animations", registered))
        return registered
    elseif not ok then
        warn("[Gakuran AP Share] live Striker animation discovery failed")
    else
        print("[Gakuran AP Share] live Striker folder unavailable")
    end

    return 0
end

local liveStrikerCount = RegisterLiveStrikerAnimations() or 0
if patchedUpstreamStrikerCount == 0 and liveStrikerCount == 0 then
    local fallbackCount = 0
    for assetId, displayName in pairs(STRIKER_FALLBACK_IDS) do
        if ApplyStrikerAnimationConfig(assetId, displayName) then
            fallbackCount += 1
        end
    end
    print(string.format("[Gakuran AP Share] registered %d fallback Striker animations", fallbackCount))
end
-- ===== end v6.8.1 Striker patch =====
]====]local _f=[====[
local FrameAnimationCache = {}

local function GetFrameAnimations(character)
    if FrameAnimationCache[character] ~= nil then
        return FrameAnimationCache[character]
    end

    local ok, activeAnimations = pcall(function()
        return AnimationTracker:Update(character)
    end)

    if not ok or not activeAnimations then
        activeAnimations = {}
    end

    FrameAnimationCache[character] = activeAnimations
    return activeAnimations
end

]====]local _g=[====[
-- ==========================================================
-- v7.1.6 Snap Lock - Shift-Lock Sticky Parry Fix
-- ==========================================================
-- Regression fix:
-- v7.0+ changed Snap Lock to ONE CFrame write and then only relied on
-- Humanoid.AutoRotate=false. In Shift Lock, Roblox can still reclaim the body
-- facing, which makes the character briefly face the attacker and then snap
-- back before Auto Parry actually fires.
--
-- This restores the last known-good sticky-face behavior:
--   * select ONE attacker for the attack;
--   * never rotate the camera;
--   * never switch targets while that attack lock is active;
--   * keep AutoRotate disabled through the complete parry window;
--   * reassert BODY yaw only if Shift Lock actually drifts it away;
--   * reassert against the SAME target only, so there is no multi-target spin;
--   * Auto Parry still runs immediately after Snap Lock in the same frame;
--   * Snap Lock never changes BlockStart / BlockExpire / reaction timings.

local BLATANT_FACE_LEAD_TIME = 0.10
local BLATANT_FACE_SEEN_TTL = 0.90

-- Hold long enough for the actual F/parry window to finish before Shift Lock
-- regains control. This is intentionally longer than the broken single-write
-- version's effective facing duration.
local BLATANT_FACE_MIN_HOLD = 0.22
local BLATANT_FACE_AFTER_WINDOW = 0.12
local BLATANT_FACE_MAX_HOLD = 0.80

-- Reapply only after meaningful drift. This keeps the lock sticky without
-- hammering CFrame every render frame or causing visible jitter.
local BLATANT_FACE_REAPPLY_ANGLE = math.rad(1.25)

local BlatantFaceSeen = {}
local BlatantFaceThreat = {
    character = nil,
    animKey = nil,
    expireAt = 0,
}

local BlatantFaceLock = {
    animKey = nil,
    character = nil,
    targetRoot = nil,
    humanoid = nil,
    savedAutoRotate = nil,
    releaseAt = 0,
}

local function ClearBlatantFaceThreat()
    BlatantFaceThreat.character = nil
    BlatantFaceThreat.animKey = nil
    BlatantFaceThreat.expireAt = 0
    BlatantFaceThreatCharacter = nil
end

local function ReleaseBlatantFaceLock()
    local humanoid = BlatantFaceLock.humanoid
    local savedAutoRotate = BlatantFaceLock.savedAutoRotate

    if humanoid and humanoid.Parent and savedAutoRotate ~= nil then
        pcall(function()
            humanoid.AutoRotate = savedAutoRotate
        end)
    end

    BlatantFaceLock.animKey = nil
    BlatantFaceLock.character = nil
    BlatantFaceLock.targetRoot = nil
    BlatantFaceLock.humanoid = nil
    BlatantFaceLock.savedAutoRotate = nil
    BlatantFaceLock.releaseAt = 0
end

local function GetShortestYaw(localRoot, targetRoot)
    local offset = targetRoot.Position - localRoot.Position
    local flatOffset = Vector3.new(offset.X, 0, offset.Z)

    if flatOffset.Magnitude <= 0.001 then
        return nil, nil
    end

    local targetDirection = flatOffset.Unit
    local currentLook = localRoot.CFrame.LookVector

    local currentYaw = math.atan2(
        -currentLook.X,
        -currentLook.Z
    )

    local desiredYaw = math.atan2(
        -targetDirection.X,
        -targetDirection.Z
    )

    -- atan2(sin, cos) normalizes to [-pi, pi], so every correction uses the
    -- shortest possible rotational direction.
    local deltaYaw = math.atan2(
        math.sin(desiredYaw - currentYaw),
        math.cos(desiredYaw - currentYaw)
    )

    return currentYaw + deltaYaw, deltaYaw
end

local function ApplyTargetYaw(localRoot, targetRoot, forceWrite)
    local finalYaw, deltaYaw =
        GetShortestYaw(localRoot, targetRoot)

    if not finalYaw or not deltaYaw then
        return false, nil
    end

    if not forceWrite
        and math.abs(deltaYaw) < BLATANT_FACE_REAPPLY_ANGLE then
        return true, deltaYaw
    end

    local position = localRoot.Position

    localRoot.CFrame =
        CFrame.new(position.X, position.Y, position.Z)
        * CFrame.Angles(0, finalYaw, 0)

    return true, deltaYaw
end

local function BlatantFaceTask()
    -- EvaluateParryTriggers reads this later in the SAME RenderStepped frame.
    BlatantFaceThreatCharacter = nil

    local enabled =
        GakuranExtraUI
        and GakuranExtraUI.SnapToggle
        and GakuranExtraUI.SnapToggle.Get
        and GakuranExtraUI.SnapToggle.Get()

    local now = os.clock()

    if not enabled then
        ReleaseBlatantFaceLock()
        ClearBlatantFaceThreat()
        table.clear(BlatantFaceSeen)
        return
    end

    local localCharacter =
        LocalPlayer and LocalPlayer.Character

    local localRoot =
        localCharacter
        and localCharacter:FindFirstChild("HumanoidRootPart")

    local localHumanoid =
        localCharacter
        and localCharacter:FindFirstChildWhichIsA("Humanoid")

    if not localCharacter
        or not localRoot
        or not localHumanoid then
        ReleaseBlatantFaceLock()
        ClearBlatantFaceThreat()
        return
    end

    -- Keep AP bridged to the exact attacker only during the real parry window.
    if BlatantFaceThreat.character
        and BlatantFaceThreat.character.Parent
        and now <= BlatantFaceThreat.expireAt then

        BlatantFaceThreatCharacter =
            BlatantFaceThreat.character
    else
        ClearBlatantFaceThreat()
    end

    -- SHIFT-LOCK RESISTANT STICKY HOLD.
    -- Once an attack owns the lock, we do not search for another target until
    -- this lock finishes. We only correct yaw if Shift Lock actually pulls the
    -- body away from the SAME attacker.
    if BlatantFaceLock.humanoid then
        local lockStillValid =
            BlatantFaceLock.humanoid == localHumanoid
            and BlatantFaceLock.character
            and BlatantFaceLock.character.Parent
            and BlatantFaceLock.targetRoot
            and BlatantFaceLock.targetRoot.Parent
            and now < BlatantFaceLock.releaseAt

        if lockStillValid then
            if BlatantFaceThreat.character
                == BlatantFaceLock.character
                and now <= BlatantFaceThreat.expireAt then

                BlatantFaceThreatCharacter =
                    BlatantFaceLock.character
            end

            local _, correctionDelta =
                ApplyTargetYaw(
                    localRoot,
                    BlatantFaceLock.targetRoot,
                    false
                )

            if correctionDelta
                and math.abs(correctionDelta)
                    >= BLATANT_FACE_REAPPLY_ANGLE
                and AdaptiveTiming
                and AdaptiveTiming.OnSnapCorrection then

                AdaptiveTiming.OnSnapCorrection(
                    BlatantFaceLock.animKey
                )
            end

            return
        end

        ReleaseBlatantFaceLock()
    end

    -- Do not acquire a second target while the AP threat bridge from the
    -- previous attack is still alive for a few milliseconds.
    if BlatantFaceThreatCharacter then
        return
    end

    for animKey, expireAt in pairs(BlatantFaceSeen) do
        if expireAt <= now then
            BlatantFaceSeen[animKey] = nil
        end
    end

    -- PERFORMANCE: scan the exact AP target pool only.
    -- The old build walked every model in the selected workspace folder every
    -- RenderStepped while Snap Lock was armed. In populated servers that could
    -- become the largest extra per-frame cost in this wrapper.
    if not TargetCharacters or #TargetCharacters == 0 then
        return
    end

    local bestCharacter = nil
    local bestTargetRoot = nil
    local bestAnimKey = nil
    local bestBlockStart = nil
    local bestBlockExpire = math.huge
    local bestDistance = math.huge

    for _, character in ipairs(TargetCharacters) do
        if character
            and character ~= localCharacter
            and character.ClassName == "Model" then

            local targetRoot =
                character:FindFirstChild("HumanoidRootPart")

            local targetHumanoid =
                character:FindFirstChildWhichIsA("Humanoid")

            if targetRoot
                and targetHumanoid
                and targetHumanoid.Health > 0 then

                local distance =
                    (targetRoot.Position - localRoot.Position).Magnitude

                if distance <= AutoParryRange
                    and distance > 0.001 then

                    local activeAnimations =
                        GetFrameAnimations(character)

                    for _, anim in ipairs(activeAnimations) do
                        if not anim.AnimationId then
                            continue
                        end

                        local attackConfig =
                            GameConfig[tostring(anim.AnimationId)]

                        if not attackConfig then
                            continue
                        end

                        -- Heavy/counter/dodge paths are intentionally left alone.
                        -- Snap Lock should not steal control from Dodge().
                        local isHeavy =
                            attackConfig.DisplayName == "M2"
                            or attackConfig.DisplayName == "Heavy"
                            or attackConfig.Heavy

                        if isHeavy then
                            continue
                        end

                        local animKey =
                            anim.Address or anim

                        if BlatantFaceSeen[animKey] then
                            continue
                        end

                        local regData =
                            AnimationRegistry[animKey]

                        if regData
                            and regData.Processed then
                            continue
                        end

                        local blockStart =
                            regData and regData.BlockStart

                        local blockExpire =
                            regData and regData.BlockExpire

                        -- On the very first detected frame AP may not have a
                        -- registry entry yet. Estimate using AP's exact timing
                        -- helper, then AP will create/use its normal registry
                        -- data immediately after this task in the same frame.
                        if not blockStart
                            or not blockExpire then

                            local playbackSpeed =
                                math.abs(
                                    tonumber(anim.Speed) or 1
                                )

                            if playbackSpeed < 0.05 then
                                playbackSpeed = 1
                            end

                            local elapsedReal =
                                math.max(
                                    tonumber(anim.TimePosition) or 0,
                                    0
                                ) / playbackSpeed

                            local estimatedStart =
                                now
                                - elapsedReal
                                - ConstLatency

                            blockStart, blockExpire =
                                CalculateParryTiming(
                                    attackConfig,
                                    estimatedStart,
                                    character
                                )
                        end

                        if blockStart and blockExpire then
                            local timeUntilInput =
                                blockStart - now

                            local stillParryable =
                                now <= blockExpire

                            if stillParryable
                                and timeUntilInput
                                    <= BLATANT_FACE_LEAD_TIME then

                                -- One sticky threat only. Earliest expiring
                                -- parry window wins; distance is the tie-breaker.
                                if blockExpire < bestBlockExpire
                                    or (
                                        math.abs(
                                            blockExpire
                                            - bestBlockExpire
                                        ) <= 0.001
                                        and distance < bestDistance
                                    ) then

                                    bestBlockExpire = blockExpire
                                    bestBlockStart = blockStart
                                    bestDistance = distance
                                    bestCharacter = character
                                    bestTargetRoot = targetRoot
                                    bestAnimKey = animKey
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not bestTargetRoot
        or not bestAnimKey
        or not bestBlockStart
        or bestBlockExpire == math.huge then
        return
    end

    -- Bridge the exact faced attacker into AP through the complete parry
    -- window. This prevents "face them, then AP checks somebody else".
    BlatantFaceThreat.character = bestCharacter
    BlatantFaceThreat.animKey = bestAnimKey
    BlatantFaceThreat.expireAt =
        math.min(
            now + 0.65,
            bestBlockExpire + 0.08
        )

    BlatantFaceThreatCharacter = bestCharacter

    BlatantFaceSeen[bestAnimKey] =
        now + BLATANT_FACE_SEEN_TTL

    local _, deltaYaw =
        GetShortestYaw(localRoot, bestTargetRoot)

    if not deltaYaw then
        return
    end

    local savedAutoRotate = nil

    local gotAutoRotate, autoRotateValue =
        pcall(function()
            return localHumanoid.AutoRotate
        end)

    if gotAutoRotate then
        savedAutoRotate = autoRotateValue

        pcall(function()
            localHumanoid.AutoRotate = false
        end)
    end

    -- Initial shortest-path face. After this, only meaningful Shift-Lock drift
    -- is corrected and always toward the SAME attacker.
    ApplyTargetYaw(
        localRoot,
        bestTargetRoot,
        math.abs(deltaYaw) > math.rad(1.0)
    )

    BlatantFaceLock.animKey = bestAnimKey
    BlatantFaceLock.character = bestCharacter
    BlatantFaceLock.targetRoot = bestTargetRoot
    BlatantFaceLock.humanoid = localHumanoid
    BlatantFaceLock.savedAutoRotate = savedAutoRotate

    -- Do not give Shift Lock the body back until after the complete parry
    -- window. This is the core fix for snapping back before F actually fires.
    BlatantFaceLock.releaseAt =
        math.min(
            now + BLATANT_FACE_MAX_HOLD,
            math.max(
                now + BLATANT_FACE_MIN_HOLD,
                bestBlockExpire
                    + BLATANT_FACE_AFTER_WINDOW
            )
        )

    if AdaptiveTiming
        and AdaptiveTiming.OnSnap then

        AdaptiveTiming.OnSnap(
            bestAnimKey,
            bestCharacter,
            deltaYaw,
            bestBlockStart,
            bestBlockExpire
        )
    end
end

]====]local _h=[====[
local ShadowStepTech = {
    BusyUntil = 0,
    CriticalKey = string.byte("R"),
}

function ShadowStepTech.GetNumber(name, fallback)
    local value = GakuranExtraUI and GakuranExtraUI[name]
    value = tonumber(value)
    if value == nil then return fallback end
    return math.max(0, value)
end

function ShadowStepTech.Trigger(withCritical)
    local now = os.clock()
    if now < ShadowStepTech.BusyUntil then return end

    local fDelay = ShadowStepTech.GetNumber("ShadowStepFDelay", 0.000)
    local chordHold = ShadowStepTech.GetNumber("ShadowStepHold", 0.035)
    local criticalDelay = ShadowStepTech.GetNumber("ShadowCriticalDelay", 0.255)
    local criticalHold = ShadowStepTech.GetNumber("ShadowCriticalHold", 0.080)

    local duration = fDelay + chordHold
        + (withCritical and (criticalDelay + criticalHold) or 0)

    ShadowStepTech.BusyUntil = now + math.max(0.10, duration + 0.035)

    task.spawn(function()
        if GakuranExtraUI
            and GakuranExtraUI.CombatAssist
            and GakuranExtraUI.CombatAssist.MarkDodge then
            GakuranExtraUI.CombatAssist.MarkDodge("ShadowStep")
        end

        keypress(DodgeKey)

        if fDelay > 0 then
            task.wait(fDelay)
        end

        keypress(ParryKey)

        if chordHold > 0 then
            task.wait(chordHold)
        end

        keyrelease(ParryKey)
        keyrelease(DodgeKey)

        if withCritical then
            if criticalDelay > 0 then
                task.wait(criticalDelay)
            end

            keypress(ShadowStepTech.CriticalKey)

            if criticalHold > 0 then
                task.wait(criticalHold)
            end

            keyrelease(ShadowStepTech.CriticalKey)
        end
    end)
end

_G.__GakuranShadowStep = function()
    ShadowStepTech.Trigger(false)
end

_G.__GakuranShadowStepCritical = function()
    ShadowStepTech.Trigger(true)
end

]====]local _i=[====[
-- ==========================================================
-- v7.2 Combat Assist
-- ==========================================================
-- Optional features:
--   * Critical Defense: Default / 50-50 / Dash-CD fallback-to-parry
--   * Wing Chun Counter Escape (experimental)
--   * Critical Aim Lock for the LOCAL player's R/M2
--
-- All are OFF/default-neutral at startup. Defensive Auto Parry remains the
-- highest-priority facing/input path.

GakuranExtraUI.CombatAssist = GakuranExtraUI.CombatAssist or {
    DashReadyAt = 0,
    CounterEscapeUntil = 0,
    CounterEscapeTarget = nil,
    CounterEscapeAnimKey = nil,

    CriticalAimAnimKey = nil,
    CriticalAimTarget = nil,
    CriticalAimTargetRoot = nil,
}

function GakuranExtraUI.CombatAssist.GetNumber(name, fallback)
    local value = tonumber(GakuranExtraUI[name])
    if value == nil then
        return fallback
    end
    return value
end

function GakuranExtraUI.CombatAssist.MarkDodge(source)
    local cooldown = math.max(
        0.10,
        GakuranExtraUI.CombatAssist.GetNumber(
            "CriticalDashCooldownEstimate",
            2.00
        )
    )

    GakuranExtraUI.CombatAssist.DashReadyAt =
        os.clock() + cooldown

    GakuranExtraUI.CombatAssist.LastDodgeSource =
        tostring(source or "unknown")
end

function GakuranExtraUI.CombatAssist.DashReady()
    return os.clock()
        >= (GakuranExtraUI.CombatAssist.DashReadyAt or 0)
end

function GakuranExtraUI.CombatAssist.IsHeavy(attackConfig)
    if not attackConfig then return false end

    local name = tostring(attackConfig.DisplayName or "")
    return attackConfig.Heavy == true
        or name == "M2"
        or name == "M2Right"
        or name == "Heavy"
        or name == "MomentumM2"
        or name == "Whirlwind"
        or string.find(name, "M2", 1, true) ~= nil
end

function GakuranExtraUI.CombatAssist.IsWingChunCounter(attackConfig)
    if not attackConfig then
        return false
    end

    local style = tostring(attackConfig.Style or "")
    local name = tostring(attackConfig.DisplayName or "")

    return (style == "WingChun" or style == "WingChunAnims")
        and name == "M2"
end

function GakuranExtraUI.CombatAssist.HandleHeavy(regData, attackConfig)
    local mode = tostring(
        GakuranExtraUI.CriticalDefenseMode or "Default"
    )

    if mode == "Default" then
        return false
    end

    -- Every non-default mode owns the critical decision so upstream Auto Dodge
    -- cannot immediately override it.
    if mode == "50/50 Parry/Dodge" then
        -- Use the registry's already-stable per-animation random number so the
        -- choice cannot flip back and forth across render frames.
        if AutoDodgeToggle.Get()
            and (tonumber(regData.RandomNum) or 100) <= 50 then

            Dodge()
        else
            if LastPendingRegData ~= regData then
                LastPendingRegData = regData
            end
            BlockStart(regData.BlockStart)
        end

        return true
    end

    if mode == "Dash CD -> Parry" then
        if AutoDodgeToggle.Get()
            and GakuranExtraUI.CombatAssist.DashReady() then

            Dodge()
        else
            if LastPendingRegData ~= regData then
                LastPendingRegData = regData
            end
            BlockStart(regData.BlockStart)
        end

        return true
    end

    return false
end

function GakuranExtraUI.CombatAssist.GetYawForDirection(direction)
    local flat = Vector3.new(direction.X, 0, direction.Z)
    if flat.Magnitude <= 0.001 then
        return nil
    end

    flat = flat.Unit
    return math.atan2(-flat.X, -flat.Z)
end

function GakuranExtraUI.CombatAssist.FaceDirection(
    localRoot,
    direction,
    minimumDegrees
)
    if not localRoot or not localRoot.Parent then
        return false
    end

    local yaw =
        GakuranExtraUI.CombatAssist.GetYawForDirection(direction)

    if not yaw then
        return false
    end

    local currentLook = localRoot.CFrame.LookVector
    local currentYaw =
        math.atan2(-currentLook.X, -currentLook.Z)

    local delta = math.atan2(
        math.sin(yaw - currentYaw),
        math.cos(yaw - currentYaw)
    )

    if math.abs(delta)
        < math.rad(tonumber(minimumDegrees) or 1.5) then
        return true
    end

    local position = localRoot.Position
    localRoot.CFrame =
        CFrame.new(position.X, position.Y, position.Z)
        * CFrame.Angles(0, currentYaw + delta, 0)

    return true
end

function GakuranExtraUI.CombatAssist.LocalIsM1ing()
    local active =
        GakuranExtraUI.CombatAssist.LocalAnimations or {}

    for _, anim in ipairs(active) do
        if anim and anim.AnimationId then
            local config =
                GameConfig[tostring(anim.AnimationId)]

            if config then
                local name =
                    tostring(config.DisplayName or anim.Name or "")

                if string.find(name, "M1", 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

function GakuranExtraUI.CombatAssist.HandleWingChunCounter(
    character,
    localCharacter,
    localRoot,
    attackConfig,
    anim
)
    -- Wing Chun M2 is a counter, not a normal incoming parry attack. It is
    -- always excluded from normal AP execution below. This optional feature
    -- only tries to make an already-started local M1 whiff the counter.
    local toggle = GakuranExtraUI.WingChunCounterEscape

    if not toggle
        or not toggle.Get
        or not toggle.Get() then
        return
    end

    if not GakuranExtraUI.CombatAssist.LocalIsM1ing() then
        return
    end

    local targetRoot =
        character
        and character:FindFirstChild("HumanoidRootPart")

    if not targetRoot or not localRoot then
        return
    end

    local duration = math.clamp(
        GakuranExtraUI.CombatAssist.GetNumber(
            "WingChunEscapeHold",
            0.18
        ),
        0.08,
        0.35
    )

    local animKey = anim and (anim.Address or anim) or character

    if GakuranExtraUI.CombatAssist.CounterEscapeAnimKey
        ~= animKey then

        GakuranExtraUI.CombatAssist.CounterEscapeAnimKey =
            animKey

        GakuranExtraUI.CombatAssist.CounterEscapeTarget =
            targetRoot

        GakuranExtraUI.CombatAssist.CounterEscapeUntil =
            os.clock() + duration
    end

    -- Turn directly AWAY from the counter user. This is deliberately body-only;
    -- camera is never changed.
    local away =
        localRoot.Position - targetRoot.Position

    GakuranExtraUI.CombatAssist.FaceDirection(
        localRoot,
        away,
        0.75
    )
end

function GakuranExtraUI.CombatAssist.FindCriticalAnimation()
    local active =
        GakuranExtraUI.CombatAssist.LocalAnimations or {}

    for _, anim in ipairs(active) do
        if anim and anim.AnimationId then
            local config =
                GameConfig[tostring(anim.AnimationId)]

            if config
                and GakuranExtraUI.CombatAssist.IsHeavy(config)
                and not GakuranExtraUI.CombatAssist.IsWingChunCounter(config) then
                return anim, config
            end
        end
    end

    return nil, nil
end

function GakuranExtraUI.CombatAssist.FindNearestCriticalTarget(
    localRoot
)
    local maxRange = math.clamp(
        GakuranExtraUI.CombatAssist.GetNumber(
            "CriticalAimRange",
            12
        ),
        4,
        30
    )

    local bestCharacter = nil
    local bestRoot = nil
    local bestDistance = math.huge

    for _, character in ipairs(TargetCharacters or {}) do
        local root =
            character
            and character:FindFirstChild("HumanoidRootPart")

        local humanoid =
            character
            and character:FindFirstChildWhichIsA("Humanoid")

        if root
            and humanoid
            and humanoid.Health > 0 then

            local distance =
                (root.Position - localRoot.Position).Magnitude

            if distance <= maxRange
                and distance < bestDistance then

                bestDistance = distance
                bestCharacter = character
                bestRoot = root
            end
        end
    end

    return bestCharacter, bestRoot
end

function GakuranExtraUI.CombatAssist.Task(localCharacter, localAnimations)
    GakuranExtraUI.CombatAssist.LocalAnimations =
        localAnimations or {}

    local localRoot =
        localCharacter
        and localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return
    end

    local now = os.clock()

    -- Experimental Wing Chun counter escape hold.
    if now
        < (GakuranExtraUI.CombatAssist.CounterEscapeUntil or 0) then

        local targetRoot =
            GakuranExtraUI.CombatAssist.CounterEscapeTarget

        if targetRoot and targetRoot.Parent then
            local away =
                localRoot.Position - targetRoot.Position

            GakuranExtraUI.CombatAssist.FaceDirection(
                localRoot,
                away,
                1.25
            )
        end
    else
        GakuranExtraUI.CombatAssist.CounterEscapeTarget = nil
        GakuranExtraUI.CombatAssist.CounterEscapeAnimKey = nil
    end

    local aimToggle = GakuranExtraUI.CriticalAimLock

    if not aimToggle
        or not aimToggle.Get
        or not aimToggle.Get() then

        GakuranExtraUI.CombatAssist.CriticalAimAnimKey = nil
        GakuranExtraUI.CombatAssist.CriticalAimTarget = nil
        GakuranExtraUI.CombatAssist.CriticalAimTargetRoot = nil
        return
    end

    -- Defensive Snap/Parry always wins over offensive Critical Aim.
    if BlatantFaceLock
        and BlatantFaceLock.humanoid then
        return
    end

    if BlatantFaceThreatCharacter then
        return
    end

    local criticalAnim =
        GakuranExtraUI.CombatAssist.FindCriticalAnimation()

    if not criticalAnim then
        GakuranExtraUI.CombatAssist.CriticalAimAnimKey = nil
        GakuranExtraUI.CombatAssist.CriticalAimTarget = nil
        GakuranExtraUI.CombatAssist.CriticalAimTargetRoot = nil
        return
    end

    local animKey =
        criticalAnim.Address or criticalAnim

    if GakuranExtraUI.CombatAssist.CriticalAimAnimKey
        ~= animKey then

        local target, targetRoot =
            GakuranExtraUI.CombatAssist.FindNearestCriticalTarget(
                localRoot
            )

        GakuranExtraUI.CombatAssist.CriticalAimAnimKey =
            animKey

        GakuranExtraUI.CombatAssist.CriticalAimTarget =
            target

        GakuranExtraUI.CombatAssist.CriticalAimTargetRoot =
            targetRoot
    end

    local targetRoot =
        GakuranExtraUI.CombatAssist.CriticalAimTargetRoot

    if targetRoot and targetRoot.Parent then
        local direction =
            targetRoot.Position - localRoot.Position

        -- Sticky only for the duration of the user's own critical animation.
        -- No camera movement, and defensive Snap can override next frame.
        GakuranExtraUI.CombatAssist.FaceDirection(
            localRoot,
            direction,
            1.5
        )
    end
end

]====]local _j=[====[
-- ==========================================================
-- v7.0 All-Style Diagnostics + Conservative Learning Mode
-- ==========================================================
-- Low-register design: all persistent state/helpers live behind ONE table.
--
-- Learning safety:
--   * disabled by default;
--   * normal parry attacks only (never Wing Chun M2 counter);
--   * custom ParryFunction attacks are observed but never auto-learned;
--   * minimum 8 eligible outcomes before any decision;
--   * if success rate is already >= 80%, timing is considered stable;
--   * requires >= 3 misses and >= 35% miss rate;
--   * requires a consistent execution-error direction;
--   * changes only 0.002s (2ms) at a time;
--   * at least 4 new eligible samples between changes;
--   * total learned adjustment is clamped to +/-0.030s.
--
-- The learner intentionally refuses to guess when the data cannot tell whether
-- a miss was early or late.

local AdaptiveTiming = {
    Rows = {},
    ByRegData = {},
    RowByAnimKey = {},
    SnapByAnimKey = {},

    InputRegData = nil,
    PendingCustomRegData = nil,
    PendingCustomUntil = 0,

    Learned = rawget(_G, "__GakuranLearnedTimingValues") or {},
    History = {},
    Meta = {},

    Settings = {
        MinSamples = 8,
        WindowSamples = 12,
        MinMisses = 3,
        MinMissRate = 0.35,
        StableSuccessRate = 0.80,
        DriftThreshold = 0.012,
        ConsistencyRatio = 0.70,
        Step = 0.002,
        MaxAdjustment = 0.030,
        MinNewSamplesBetweenAdjustments = 4,
    },
}

_G.__GakuranLearnedTimingValues = AdaptiveTiming.Learned

function AdaptiveTiming.Fmt(value)
    if value == nil then
        return "-"
    end

    local numberValue = tonumber(value)
    if numberValue then
        return string.format("%.4f", numberValue)
    end

    return tostring(value)
end

function AdaptiveTiming.Style(attackConfig)
    return tostring(
        attackConfig
        and attackConfig.Style
        or "Unknown"
    )
end

function AdaptiveTiming.Attack(attackConfig, anim)
    return tostring(
        attackConfig
        and attackConfig.DisplayName
        or anim
        and anim.Name
        or "Unknown"
    )
end

function AdaptiveTiming.Key(attackConfig, anim)
    return AdaptiveTiming.Style(attackConfig)
        .. "|"
        .. AdaptiveTiming.Attack(attackConfig, anim)
end

function AdaptiveTiming.IsWingChunCounter(attackConfig)
    if not attackConfig then
        return false
    end

    local style = AdaptiveTiming.Style(attackConfig)
    local attack = AdaptiveTiming.Attack(attackConfig)

    return (style == "WingChun" or style == "WingChunAnims")
        and attack == "M2"
end

function AdaptiveTiming.DiagnosticsEnabled()
    if not GakuranExtraUI
        or not GakuranExtraUI.DiagToggle
        or not GakuranExtraUI.DiagToggle.Get then
        return true
    end

    return GakuranExtraUI.DiagToggle.Get() == true
end

function AdaptiveTiming.LearningEnabled()
    return GakuranExtraUI
        and GakuranExtraUI.LearningToggle
        and GakuranExtraUI.LearningToggle.Get
        and GakuranExtraUI.LearningToggle.Get() == true
end

function AdaptiveTiming.StyleSelected(attackConfig)
    local filter = GakuranExtraUI
        and GakuranExtraUI.DiagStyleFilter
        or "All Styles"

    if not filter
        or filter == ""
        or filter == "All"
        or filter == "All Styles" then
        return true
    end

    return AdaptiveTiming.Style(attackConfig) == tostring(filter)
end

function AdaptiveTiming.ShouldRecord(attackConfig)
    if not attackConfig then
        return false
    end

    -- Wing Chun M2 is a counter, not a normal parry timing sample.
    if AdaptiveTiming.IsWingChunCounter(attackConfig) then
        return false
    end

    if not AdaptiveTiming.StyleSelected(attackConfig) then
        return false
    end

    return AdaptiveTiming.DiagnosticsEnabled()
        or AdaptiveTiming.LearningEnabled()
end

function AdaptiveTiming.IsLearnable(attackConfig)
    if not attackConfig
        or AdaptiveTiming.IsWingChunCounter(attackConfig)
        or attackConfig.ParryFunction then
        return false
    end

    return true
end

function AdaptiveTiming.BaseReaction(attackConfig)
    return tonumber(
        attackConfig
        and (
            attackConfig.ReactionTime
            or attackConfig.DefaultReactionTime
        )
        or DefaultReactionTime
    ) or DefaultReactionTime
end

function AdaptiveTiming.StoredAdjustment(attackConfig, anim)
    local style = AdaptiveTiming.Style(attackConfig)
    local attack = AdaptiveTiming.Attack(attackConfig, anim)
    local styleTable = AdaptiveTiming.Learned[style]

    if not styleTable then
        return 0
    end

    return tonumber(styleTable[attack]) or 0
end

function AdaptiveTiming.GetAdjustment(attackConfig)
    if not AdaptiveTiming.LearningEnabled()
        or not AdaptiveTiming.IsLearnable(attackConfig) then
        return 0
    end

    return AdaptiveTiming.StoredAdjustment(attackConfig)
end

function AdaptiveTiming.SetAdjustment(attackConfig, value)
    local style = AdaptiveTiming.Style(attackConfig)
    local attack = AdaptiveTiming.Attack(attackConfig)

    AdaptiveTiming.Learned[style] =
        AdaptiveTiming.Learned[style] or {}

    AdaptiveTiming.Learned[style][attack] =
        math.clamp(
            tonumber(value) or 0,
            -AdaptiveTiming.Settings.MaxAdjustment,
            AdaptiveTiming.Settings.MaxAdjustment
        )

    _G.__GakuranLearnedTimingValues = AdaptiveTiming.Learned
end

function AdaptiveTiming.OnSnap(animKey, character, deltaYaw, blockStart, blockExpire)
    if not animKey then
        return
    end

    local snap = AdaptiveTiming.SnapByAnimKey[animKey] or {
        Used = true,
        Corrections = 0,
    }

    snap.Used = true
    snap.Target = tostring(character and character.Name or "?")
    snap.YawDegrees = math.deg(tonumber(deltaYaw) or 0)
    snap.BlockStart = blockStart
    snap.BlockExpire = blockExpire

    AdaptiveTiming.SnapByAnimKey[animKey] = snap

    local row = AdaptiveTiming.RowByAnimKey[animKey]
    if row then
        row.SnapUsed = true
        row.SnapTarget = snap.Target
        row.SnapYawDegrees = snap.YawDegrees
        row.SnapCorrections = snap.Corrections or 0
    end
end

function AdaptiveTiming.OnSnapCorrection(animKey)
    if not animKey then
        return
    end

    local snap =
        AdaptiveTiming.SnapByAnimKey[animKey]
        or {
            Used = true,
            Corrections = 0,
        }

    snap.Corrections =
        (snap.Corrections or 0) + 1

    AdaptiveTiming.SnapByAnimKey[animKey] = snap

    local row =
        AdaptiveTiming.RowByAnimKey[animKey]

    if row then
        row.SnapUsed = true
        row.SnapCorrections = snap.Corrections
    end
end

function AdaptiveTiming.NewRow(regData, attackConfig, anim, character, animKey)
    local learned = AdaptiveTiming.StoredAdjustment(attackConfig, anim)
    local applied = AdaptiveTiming.LearningEnabled()
        and AdaptiveTiming.IsLearnable(attackConfig)
        and learned
        or 0

    local baseReaction = AdaptiveTiming.BaseReaction(attackConfig)
    local snap = animKey and AdaptiveTiming.SnapByAnimKey[animKey] or nil

    local row = {
        Index = #AdaptiveTiming.Rows + 1,
        RegData = regData,
        AnimKey = animKey,

        Style = AdaptiveTiming.Style(attackConfig),
        Attack = AdaptiveTiming.Attack(attackConfig, anim),
        AnimationId = tostring(anim.AnimationId or "?"),
        Target = tostring(character and character.Name or "?"),

        BaseReaction = baseReaction,
        StoredLearnedAdjustment = learned,
        AppliedLearnedAdjustment = applied,
        EffectiveReaction = baseReaction + applied,

        FirstSeenClock = os.clock(),
        FirstSeenTrack = tonumber(anim.TimePosition) or 0,
        FirstSeenSpeed = tonumber(anim.Speed) or 1,
        LastTrack = tonumber(anim.TimePosition) or 0,
        LastSpeed = tonumber(anim.Speed) or 1,

        AnimationStart = regData and regData.StartTime or nil,
        BlockStart = regData and regData.BlockStart or nil,
        BlockExpire = regData and regData.BlockExpire or nil,

        CustomParryFunction = attackConfig.ParryFunction ~= nil,
        Learnable = AdaptiveTiming.IsLearnable(attackConfig),
        LearningState = "collecting",

        SnapUsed = snap and snap.Used == true or false,
        SnapTarget = snap and snap.Target or "-",
        SnapYawDegrees = snap and snap.YawDegrees or nil,
        SnapCorrections = snap and snap.Corrections or 0,

        Finalized = false,
    }

    table.insert(AdaptiveTiming.Rows, row)
    AdaptiveTiming.ByRegData[regData] = row

    if animKey then
        AdaptiveTiming.RowByAnimKey[animKey] = row
    end

    print(string.format(
        "[TIMING-DIAG][SEEN] #%d | %s | %s | Base=%s | Learned=%s | Effective=%s | Track=%s | Speed=%s | Snap=%s",
        row.Index,
        row.Style,
        row.Attack,
        AdaptiveTiming.Fmt(row.BaseReaction),
        AdaptiveTiming.Fmt(row.AppliedLearnedAdjustment),
        AdaptiveTiming.Fmt(row.EffectiveReaction),
        AdaptiveTiming.Fmt(row.FirstSeenTrack),
        AdaptiveTiming.Fmt(row.FirstSeenSpeed),
        tostring(row.SnapUsed)
    ))

    return row
end

function AdaptiveTiming.GetRow(regData, attackConfig, anim, character, animKey)
    if not AdaptiveTiming.ShouldRecord(attackConfig)
        or not regData then
        return nil
    end

    local row = AdaptiveTiming.ByRegData[regData]

    if row and row.Finalized and regData.DidALoop then
        row = nil
        AdaptiveTiming.ByRegData[regData] = nil
    end

    if not row then
        row = AdaptiveTiming.NewRow(
            regData,
            attackConfig,
            anim,
            character,
            animKey
        )
    end

    return row
end

function AdaptiveTiming.Observe(
    regData,
    attackConfig,
    anim,
    character,
    now,
    animKey
)
    local row = AdaptiveTiming.GetRow(
        regData,
        attackConfig,
        anim,
        character,
        animKey
    )

    if not row then
        return
    end

    row.LastObserveClock = now or os.clock()
    row.LastTrack = tonumber(anim.TimePosition) or row.LastTrack
    row.LastSpeed = tonumber(anim.Speed) or row.LastSpeed
    row.AnimationStart = regData.StartTime or row.AnimationStart
    row.BlockStart = regData.BlockStart or row.BlockStart
    row.BlockExpire = regData.BlockExpire or row.BlockExpire

    local snap = animKey and AdaptiveTiming.SnapByAnimKey[animKey] or nil
    if snap then
        row.SnapUsed = snap.Used == true
        row.SnapTarget = snap.Target or row.SnapTarget
        row.SnapYawDegrees = snap.YawDegrees or row.SnapYawDegrees
        row.SnapCorrections = snap.Corrections or row.SnapCorrections
    end
end

function AdaptiveTiming.MarkCustom(
    regData,
    attackConfig,
    anim,
    character,
    now,
    animKey
)
    local row = AdaptiveTiming.GetRow(
        regData,
        attackConfig,
        anim,
        character,
        animKey
    )

    if not row then
        return
    end

    row.CustomInvokedClock = now or os.clock()
    row.CustomInvokedRel = regData.StartTime
        and (row.CustomInvokedClock - regData.StartTime)
        or nil

    AdaptiveTiming.PendingCustomRegData = regData
    AdaptiveTiming.PendingCustomUntil = os.clock() + 1.50
end

function AdaptiveTiming.ResolveBlockRegData()
    if LastPendingRegData then
        local row = AdaptiveTiming.ByRegData[LastPendingRegData]
        if row and not row.Finalized then
            return LastPendingRegData
        end
    end

    if AdaptiveTiming.PendingCustomRegData
        and os.clock() <= AdaptiveTiming.PendingCustomUntil then

        local row =
            AdaptiveTiming.ByRegData[
                AdaptiveTiming.PendingCustomRegData
            ]

        if row and not row.Finalized then
            return AdaptiveTiming.PendingCustomRegData
        end
    end

    return nil
end

function AdaptiveTiming.OnBlockStart(startTime, holdFor)
    if not AdaptiveTiming.DiagnosticsEnabled()
        and not AdaptiveTiming.LearningEnabled() then
        return
    end

    local regData = AdaptiveTiming.ResolveBlockRegData()
    if not regData then
        return
    end

    local row = AdaptiveTiming.ByRegData[regData]
    if not row or row.Finalized then
        return
    end

    local now = os.clock()

    AdaptiveTiming.InputRegData = regData

    row.BlockCallClock = now
    row.BlockCallRel = regData.StartTime
        and (now - regData.StartTime)
        or nil

    row.RequestedBlockRel = (
        startTime
        and regData.StartTime
        and (startTime - regData.StartTime)
    ) or nil

    row.HoldFor = holdFor
    row.TrackAtTrigger = row.LastTrack
    row.SpeedAtTrigger = row.LastSpeed
    row.BlockStart = regData.BlockStart or row.BlockStart
    row.BlockExpire = regData.BlockExpire or row.BlockExpire
end

function AdaptiveTiming.OnInputRegistered(inputTime)
    local regData = AdaptiveTiming.InputRegData
    local row = regData and AdaptiveTiming.ByRegData[regData]

    if not row or row.Finalized then
        return
    end

    row.InputClock = inputTime
    row.InputRel = regData.StartTime
        and (inputTime - regData.StartTime)
        or nil

    if row.InputRel and row.RequestedBlockRel then
        row.TimingError =
            row.InputRel - row.RequestedBlockRel
    end
end

function AdaptiveTiming.OnParryRegistered(parryTime, inputLatency)
    local regData = AdaptiveTiming.InputRegData
    local row = regData and AdaptiveTiming.ByRegData[regData]

    if not row or row.Finalized then
        return
    end

    row.ParryRegisteredClock = parryTime
    row.ParryRegisteredRel = regData.StartTime
        and (parryTime - regData.StartTime)
        or nil

    row.InputLatency = inputLatency
end

function AdaptiveTiming.PushHistory(row)
    if not row
        or not row.Learnable
        or not row.InputRel
        or not row.RequestedBlockRel then
        return
    end

    if row.Outcome ~= "PARRY_SUCCESS"
        and row.Outcome ~= "WINDOW_EXCEEDED" then
        return
    end

    local key = row.Style .. "|" .. row.Attack
    AdaptiveTiming.History[key] =
        AdaptiveTiming.History[key] or {}

    local history = AdaptiveTiming.History[key]

    table.insert(history, {
        Success = row.Outcome == "PARRY_SUCCESS",
        Drift = row.InputRel - row.RequestedBlockRel,
    })

    while #history > 20 do
        table.remove(history, 1)
    end
end

function AdaptiveTiming.EvaluateLearning(row)
    if not AdaptiveTiming.LearningEnabled()
        or not row
        or not row.Learnable then
        return
    end

    local settings = AdaptiveTiming.Settings
    local key = row.Style .. "|" .. row.Attack
    local history = AdaptiveTiming.History[key]

    if not history
        or #history < settings.MinSamples then
        row.LearningState =
            "collecting "
            .. tostring(history and #history or 0)
            .. "/"
            .. tostring(settings.MinSamples)
        return
    end

    local sampleCount =
        math.min(#history, settings.WindowSamples)

    local startIndex = #history - sampleCount + 1
    local successCount = 0
    local missCount = 0
    local missDriftSum = 0
    local positiveMissDrift = 0
    local negativeMissDrift = 0

    for i = startIndex, #history do
        local sample = history[i]

        if sample.Success then
            successCount += 1
        else
            missCount += 1
            missDriftSum += sample.Drift

            if sample.Drift >= settings.DriftThreshold then
                positiveMissDrift += 1
            elseif sample.Drift <= -settings.DriftThreshold then
                negativeMissDrift += 1
            end
        end
    end

    local successRate = successCount / sampleCount
    local missRate = missCount / sampleCount

    if successRate >= settings.StableSuccessRate then
        row.LearningState =
            string.format("stable %.0f%%", successRate * 100)
        return
    end

    if missCount < settings.MinMisses
        or missRate < settings.MinMissRate then
        row.LearningState =
            string.format("watching %.0f%% success", successRate * 100)
        return
    end

    local meta = AdaptiveTiming.Meta[key] or {
        LastAdjustedSample = 0,
    }

    AdaptiveTiming.Meta[key] = meta

    if (#history - meta.LastAdjustedSample)
        < settings.MinNewSamplesBetweenAdjustments then
        row.LearningState = "waiting for more samples"
        return
    end

    local averageMissDrift = missDriftSum / missCount
    local dominantCount =
        math.max(positiveMissDrift, negativeMissDrift)

    local consistency = dominantCount / missCount

    if math.abs(averageMissDrift) < settings.DriftThreshold
        or consistency < settings.ConsistencyRatio then
        row.LearningState = "miss direction inconsistent"
        return
    end

    local current =
        AdaptiveTiming.StoredAdjustment({
            Style = row.Style,
            DisplayName = row.Attack,
        })

    local step = 0

    -- Positive drift means the real F event is consistently later than the
    -- requested timing on misses, so move the requested reaction slightly earlier.
    if averageMissDrift > 0 then
        step = -settings.Step
    elseif averageMissDrift < 0 then
        step = settings.Step
    end

    local newValue = math.clamp(
        current + step,
        -settings.MaxAdjustment,
        settings.MaxAdjustment
    )

    if math.abs(newValue - current) < 0.0001 then
        row.LearningState = "adjustment limit reached"
        return
    end

    AdaptiveTiming.SetAdjustment({
        Style = row.Style,
        DisplayName = row.Attack,
    }, newValue)

    meta.LastAdjustedSample = #history
    row.StoredLearnedAdjustment = newValue
    row.LearningState =
        string.format(
            "adjusted %+.3f -> total %+.3f",
            step,
            newValue
        )

    print(string.format(
        "[LEARNING] %s | %s | samples=%d success=%.0f%% missDrift=%+.4f | step=%+.3f | learned=%+.3f",
        row.Style,
        row.Attack,
        sampleCount,
        successRate * 100,
        averageMissDrift,
        step,
        newValue
    ))
end

function AdaptiveTiming.Finish(outcome, preferredRegData)
    local regData =
        preferredRegData or AdaptiveTiming.InputRegData

    local row =
        regData and AdaptiveTiming.ByRegData[regData]

    if not row or row.Finalized then
        return
    end

    row.Finalized = true
    row.Outcome = outcome
    row.EndClock = os.clock()

    if regData.StartTime then
        row.EndRel =
            row.EndClock - regData.StartTime
    end

    if row.InputRel and row.RequestedBlockRel then
        row.TimingError =
            row.InputRel - row.RequestedBlockRel
    end

    AdaptiveTiming.PushHistory(row)
    AdaptiveTiming.EvaluateLearning(row)

    print(string.format(
        "[TIMING-DIAG][RESULT] #%d | %s | %s | Outcome=%s | Base=%s | Learned=%s | Effective=%s | F=%s | Error=%s | Snap=%s | Corrections=%s | Learning=%s",
        row.Index,
        row.Style,
        row.Attack,
        tostring(outcome),
        AdaptiveTiming.Fmt(row.BaseReaction),
        AdaptiveTiming.Fmt(row.AppliedLearnedAdjustment),
        AdaptiveTiming.Fmt(row.EffectiveReaction),
        AdaptiveTiming.Fmt(row.InputRel),
        AdaptiveTiming.Fmt(row.TimingError),
        tostring(row.SnapUsed),
        tostring(row.SnapCorrections or 0),
        tostring(row.LearningState or "-")
    ))

    if AdaptiveTiming.InputRegData == regData then
        AdaptiveTiming.InputRegData = nil
    end

    if AdaptiveTiming.PendingCustomRegData == regData then
        AdaptiveTiming.PendingCustomRegData = nil
        AdaptiveTiming.PendingCustomUntil = 0
    end
end

function AdaptiveTiming.BuildClipboard()
    local lines = {
        table.concat({
            "Index",
            "Style",
            "Attack",
            "AnimationId",
            "Target",
            "BaseReaction",
            "StoredLearnedAdjustment",
            "AppliedLearnedAdjustment",
            "EffectiveReaction",
            "FirstSeenTrack",
            "FirstSeenSpeed",
            "BlockStartRel",
            "BlockExpireRel",
            "TrackAtTrigger",
            "SpeedAtTrigger",
            "RequestedBlockRel",
            "BlockCallRel",
            "InputRel",
            "TimingError",
            "ParryRegisteredRel",
            "InputLatency",
            "CustomParryFunction",
            "SnapUsed",
            "SnapTarget",
            "SnapYawDegrees",
            "SnapCorrections",
            "LearningState",
            "Outcome",
        }, "	")
    }

    for _, row in ipairs(AdaptiveTiming.Rows) do
        local animationStart = row.AnimationStart

        local blockStartRel = (
            animationStart
            and row.BlockStart
            and (row.BlockStart - animationStart)
        ) or nil

        local blockExpireRel = (
            animationStart
            and row.BlockExpire
            and (row.BlockExpire - animationStart)
        ) or nil

        table.insert(lines, table.concat({
            tostring(row.Index or ""),
            tostring(row.Style or ""),
            tostring(row.Attack or ""),
            tostring(row.AnimationId or ""),
            tostring(row.Target or ""),
            AdaptiveTiming.Fmt(row.BaseReaction),
            AdaptiveTiming.Fmt(row.StoredLearnedAdjustment),
            AdaptiveTiming.Fmt(row.AppliedLearnedAdjustment),
            AdaptiveTiming.Fmt(row.EffectiveReaction),
            AdaptiveTiming.Fmt(row.FirstSeenTrack),
            AdaptiveTiming.Fmt(row.FirstSeenSpeed),
            AdaptiveTiming.Fmt(blockStartRel),
            AdaptiveTiming.Fmt(blockExpireRel),
            AdaptiveTiming.Fmt(row.TrackAtTrigger),
            AdaptiveTiming.Fmt(row.SpeedAtTrigger),
            AdaptiveTiming.Fmt(row.RequestedBlockRel),
            AdaptiveTiming.Fmt(row.BlockCallRel),
            AdaptiveTiming.Fmt(row.InputRel),
            AdaptiveTiming.Fmt(row.TimingError),
            AdaptiveTiming.Fmt(row.ParryRegisteredRel),
            AdaptiveTiming.Fmt(row.InputLatency),
            tostring(row.CustomParryFunction == true),
            tostring(row.SnapUsed == true),
            tostring(row.SnapTarget or "-"),
            AdaptiveTiming.Fmt(row.SnapYawDegrees),
            tostring(row.SnapCorrections or 0),
            tostring(row.LearningState or "-"),
            tostring(row.Outcome or "INCOMPLETE"),
        }, "	"))
    end

    return table.concat(lines, string.char(10))
end

function AdaptiveTiming.BuildLearnedClipboard()
    local lines = {
        table.concat({
            "Style",
            "Attack",
            "LearnedAdjustment",
        }, "	")
    }

    local styles = {}
    for style in pairs(AdaptiveTiming.Learned) do
        table.insert(styles, style)
    end
    table.sort(styles)

    for _, style in ipairs(styles) do
        local attacks = {}
        for attack in pairs(AdaptiveTiming.Learned[style]) do
            table.insert(attacks, attack)
        end
        table.sort(attacks)

        for _, attack in ipairs(attacks) do
            table.insert(lines, table.concat({
                tostring(style),
                tostring(attack),
                AdaptiveTiming.Fmt(
                    AdaptiveTiming.Learned[style][attack]
                ),
            }, "	"))
        end
    end

    return table.concat(lines, string.char(10))
end

_G.__GakuranTimingDiagnosticsCopy = function()
    local output = AdaptiveTiming.BuildClipboard()

    if setclipboard then
        setclipboard(output)
        print(string.format(
            "[TIMING-DIAG] copied %d samples",
            #AdaptiveTiming.Rows
        ))
    else
        print(output)
    end
end

_G.__GakuranTimingDiagnosticsClear = function()
    table.clear(AdaptiveTiming.Rows)
    table.clear(AdaptiveTiming.ByRegData)
    table.clear(AdaptiveTiming.RowByAnimKey)
    table.clear(AdaptiveTiming.SnapByAnimKey)

    AdaptiveTiming.InputRegData = nil
    AdaptiveTiming.PendingCustomRegData = nil
    AdaptiveTiming.PendingCustomUntil = 0

    print("[TIMING-DIAG] cleared samples")
end

_G.__GakuranLearningReset = function()
    table.clear(AdaptiveTiming.Learned)
    table.clear(AdaptiveTiming.History)
    table.clear(AdaptiveTiming.Meta)
    _G.__GakuranLearnedTimingValues = AdaptiveTiming.Learned
    print("[LEARNING] reset all learned timing adjustments to 0")
end

_G.__GakuranLearningCopy = function()
    local output = AdaptiveTiming.BuildLearnedClipboard()

    if setclipboard then
        setclipboard(output)
        print("[LEARNING] copied learned timing adjustments")
    else
        print(output)
    end
end

_G.__GakuranTimingDiagnosticsGet = function()
    return AdaptiveTiming.Rows
end

]====]local function _k(_l,_m,_n)local _o,_p=string.find(_l,_m,1,true)if not _o then return nil end return string.sub(_l,1,_o-1).._n..string.sub(_l,_p+1)end local _q=game:HttpGet(_b)local _r=string.char(108,111,99,97,108,32,75,110,111,119,110,79,102,102,115,101,116,115,32,61,32,123)_q=_k(_q,_r,_d.._r)if not _q then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,110,105,109,97,116,105,111,110,32,116,114,97,99,107,101,114,32,102,111,114,109,97,116,32,99,104,97,110,103,101,100))return end local _s=[[            local liveTime = GetTimePosition(address) or info.TimePosition
            info.TimePosition = liveTime]]_q=_k(_q,_s,[[            local liveTime = GetTimePosition(address) or info.TimePosition
            info.TimePosition = liveTime
            local liveSpeed = memory_read("float", address + KnownOffsets.Speed)
            if liveSpeed then
                info.Speed = liveSpeed
            end]])if not _q then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,110,105,109,97,116,105,111,110,32,116,114,97,99,107,101,114,32,115,112,101,101,100,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _t=game:HttpGet(_a)local _u=[[local URL = "https://raw.githubusercontent.com/artxficial/matchastuff/main/animationtracker.lua"
local ImportAnimationTracker = loadstring(game:HttpGet(URL))()]]local _v=string.char(108,111,99,97,108,32,73,109,112,111,114,116,65,110,105,109,97,116,105,111,110,84,114,97,99,107,101,114,32,61,32,108,111,97,100,115,116,114,105,110,103,40)..string.format(string.char(37,113),_q)..string.char(41,40,41)_t=_k(_t,_u,_v)if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,117,116,111,45,112,97,114,114,121,32,116,114,97,99,107,101,114,32,105,109,112,111,114,116,32,102,111,114,109,97,116,32,99,104,97,110,103,101,100))return end do local _w=[[local UI_Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua"))() or INSui]]local _x=[[local _gakuranUiSource = game:HttpGet("https://raw.githubusercontent.com/neaxusxgod-png/INS-ui/main/uilib.min.lua")
local _gakuranUiChunk, _gakuranUiCompileError = loadstring(_gakuranUiSource)
local UI_Library = nil

if _gakuranUiChunk then
    local _gakuranUiOk, _gakuranUiResult = pcall(_gakuranUiChunk)
    if _gakuranUiOk then
        UI_Library = _gakuranUiResult
    else
        warn("[Gakuran UI] INS-ui runtime error: " .. tostring(_gakuranUiResult))
    end
else
    warn("[Gakuran UI] INS-ui compile error: " .. tostring(_gakuranUiCompileError))
end

-- Current INS-ui publishes the library as INSUI. Keep the old casing too in
-- case an older build is already present in the executor environment.
if not UI_Library then
    pcall(function()
        if getgenv then
            UI_Library =
                rawget(getgenv(), "INSUI")
                or rawget(getgenv(), "INSui")
        end
    end)
end

UI_Library =
    UI_Library
    or rawget(_G, "INSUI")
    or rawget(_G, "INSui")

if not UI_Library or type(UI_Library.CreateWindow) ~= "function" then
    error("INS-ui failed to load: CreateWindow missing")
end]]local _y=_k(_t,_w,_x)if _y then _t=_y print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,85,73,32,108,111,97,100,101,114,32,112,97,116,99,104,101,100))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,85,73,32,108,111,97,100,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end local _z=string.char(71,97,109,101,67,111,110,102,105,103,32,61,32,70,108,97,116,116,101,110,101,100,67,111,110,102,105,103)_t=_k(_t,_z,_z.._e)if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,102,108,97,116,116,101,110,101,100,32,71,97,109,101,67,111,110,102,105,103,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _A=0 _t,_A=string.gsub(_t,string.char(105,102,37,115,43,118,37,115,42,126,61,37,115,42,68,101,102,97,117,108,116,82,101,97,99,116,105,111,110,84,105,109,101,37,115,43,116,104,101,110,37,115,43,73,110,102,111,37,46,82,101,97,99,116,105,111,110,84,105,109,101,37,115,42,61,37,115,42,118,37,115,43,101,110,100),string.char(73,110,102,111,46,82,101,97,99,116,105,111,110,84,105,109,101,32,61,32,118),1)if _A==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,114,101,97,99,116,105,111,110,32,115,108,105,100,101,114,32,99,97,108,108,98,97,99,107,32,112,97,116,99,104,32,115,107,105,112,112,101,100,59,32,99,111,110,116,105,110,117,105,110,103))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,114,101,97,99,116,105,111,110,32,115,108,105,100,101,114,32,99,97,108,108,98,97,99,107,32,112,97,116,99,104,101,100))end local _B=[[    if not AnimationRegistry[animKey] then
        local adjustedNow = now - ConstLatency -- - currentTrackTime
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)]]_t=_k(_t,_B,[[    if not AnimationRegistry[animKey] then
        local playbackSpeed = math.abs(tonumber(anim.Speed) or 1)
        if playbackSpeed < 0.05 then playbackSpeed = 1 end
        local elapsedReal = math.max(tonumber(currentTrackTime) or 0, 0) / playbackSpeed
        local adjustedNow = now - elapsedReal - ConstLatency
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,115,116,97,114,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _C=0 _t,_C=string.gsub(_t,string.char(108,111,99,97,108,37,115,43,66,108,111,99,107,83,116,97,114,116,44,37,115,42,66,108,111,99,107,69,120,112,105,114,101,37,115,42,61,37,115,42,67,97,108,99,117,108,97,116,101,80,97,114,114,121,84,105,109,105,110,103,37,40,37,115,42,97,116,116,97,99,107,67,111,110,102,105,103,44,37,115,42,110,111,119,37,115,42,37,45,37,115,42,99,117,114,114,101,110,116,84,114,97,99,107,84,105,109,101,44,37,115,42,84,97,114,103,101,116,67,104,97,114,97,99,116,101,114,37,115,42,37,41),[[local playbackSpeed = math.abs(tonumber(anim.Speed) or 1)
        if playbackSpeed < 0.05 then playbackSpeed = 1 end
        local elapsedReal = math.max(tonumber(currentTrackTime) or 0, 0) / playbackSpeed
        local adjustedNow = now - elapsedReal - ConstLatency
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)]],1)local _D=0 if _C>0 then _t,_D=string.gsub(_t,string.char(114,101,103,68,97,116,97,37,46,83,116,97,114,116,84,105,109,101,37,115,42,61,37,115,42,110,111,119,37,115,42,37,45,37,115,42,67,111,110,115,116,76,97,116,101,110,99,121,91,94,13,10,93,42),string.char(114,101,103,68,97,116,97,46,83,116,97,114,116,84,105,109,101,32,61,32,97,100,106,117,115,116,101,100,78,111,119),1)end if _C==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,108,111,111,112,32,116,105,109,105,110,103,32,112,97,116,99,104,32,115,107,105,112,112,101,100,59,32,99,111,110,116,105,110,117,105,110,103))elseif _D==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,108,111,111,112,32,83,116,97,114,116,84,105,109,101,32,112,97,116,99,104,32,115,107,105,112,112,101,100,59,32,99,111,110,116,105,110,117,105,110,103))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,108,111,111,112,32,116,105,109,105,110,103,32,112,97,116,99,104,101,100))end _t=_k(_t,string.char(108,111,99,97,108,32,72,101,105,103,104,116,84,111,103,103,108,101),string.char(108,111,99,97,108,32,72,101,105,103,104,116,84,111,103,103,108,101,10,108,111,99,97,108,32,71,97,107,117,114,97,110,69,120,116,114,97,85,73,32,61,32,123,125))if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,115,116,97,116,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _E=[[local Config_Tab = UI_Window:Tab("Style Configurations", "swords")]]_t=_k(_t,_E,_E..[[
local Blatant_Tab = UI_Window:Tab("Combat", "swords")]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,67,111,109,98,97,116,32,116,97,98,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _F=[[local Folders_Section   = AP_Tab:Section("Folders", "Right")]]_t=_k(_t,_F,_F..[[
local Combat_Section = Blatant_Tab:Section("Combat", "Left")
local Movement_Section = Blatant_Tab:Section("Movement", "Left")
local Performance_Section = Blatant_Tab:Section("Performance", "Right")
local TimingDiag_Section = Blatant_Tab:Section("Timing", "Right")]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,67,111,109,98,97,116,32,115,101,99,116,105,111,110,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _H=[[    HeightToggle = AP_Section:Toggle("Height Multiplier (May crash some users)", true)]]_t=_k(_t,_H,_H..[[
    -- Combat
    GakuranExtraUI.SnapToggle =
        Combat_Section:Toggle("Snap Lock", false)
    GakuranExtraUI.SnapToggle:AddKeybind("h", "Toggle")
    Combat_Section:Label("Keeps you facing them until F goes off. Bind: H")

    GakuranExtraUI.CriticalDefenseMode = "Default"
    local criticalDefenseDropdown = Combat_Section:Dropdown(
        "Crit Defense",
        nil,
        {
            "Normal",
            "50/50 F/Q",
            "Q CD = F",
        },
        false,
        function(list)
            local shown = list and list[1] or "Normal"

            if shown == "50/50 F/Q" then
                GakuranExtraUI.CriticalDefenseMode =
                    "50/50 Parry/Dodge"
            elseif shown == "Q CD = F" then
                GakuranExtraUI.CriticalDefenseMode =
                    "Dash CD -> Parry"
            else
                GakuranExtraUI.CriticalDefenseMode =
                    "Default"
            end
        end
    )
    criticalDefenseDropdown:Set({"Normal"})

    GakuranExtraUI.CriticalDashCooldownEstimate = 2.00
    local criticalDashCooldownSlider = Combat_Section:Slider(
        "Q Cooldown",
        0,
        0.05,
        0.25,
        3.00,
        "s",
        function(v)
            GakuranExtraUI.CriticalDashCooldownEstimate = v
        end
    )
    criticalDashCooldownSlider:Set(2.00)

    GakuranExtraUI.WingChunCounterEscape =
        Combat_Section:Toggle(
            "Wing Chun Counter Fake Wiff",
            false
        )

    GakuranExtraUI.WingChunEscapeHold = 0.18
    local wingChunEscapeSlider = Combat_Section:Slider(
        "Fake Wiff Time",
        0,
        0.01,
        0.08,
        0.35,
        "s",
        function(v)
            GakuranExtraUI.WingChunEscapeHold = v
        end
    )
    wingChunEscapeSlider:Set(0.18)
    Combat_Section:Label("Turns your M1 away from Wing Chun M2 so the counter misses.")

    GakuranExtraUI.CriticalAimLock =
        Combat_Section:Toggle("Crit Aim", false)

    GakuranExtraUI.CriticalAimRange = 12
    local criticalAimRangeSlider = Combat_Section:Slider(
        "Crit Aim Range",
        12,
        1,
        4,
        30,
        "studs",
        function(v)
            GakuranExtraUI.CriticalAimRange = v
        end
    )
    criticalAimRangeSlider:Set(12)
    Combat_Section:Label("Faces your target while your R/crit is playing.")

    -- Movement
    Movement_Section:Label("Z = Shadow Step | B = Shadow Crit")

    GakuranExtraUI.ShadowStepFDelay = 0.000
    GakuranExtraUI.ShadowStepHold = 0.035
    GakuranExtraUI.ShadowCriticalDelay = 0.255
    GakuranExtraUI.ShadowCriticalHold = 0.080

    GakuranExtraUI.ShadowFDelaySlider = Movement_Section:Slider(
        "Q > F Delay", 0, 0.005, 0, 0.080, "s",
        function(v)
            GakuranExtraUI.ShadowStepFDelay = v
        end
    )
    GakuranExtraUI.ShadowFDelaySlider:Set(0.000)

    GakuranExtraUI.ShadowHoldSlider = Movement_Section:Slider(
        "Q+F Hold", 0, 0.005, 0.010, 0.120, "s",
        function(v)
            GakuranExtraUI.ShadowStepHold = v
        end
    )
    GakuranExtraUI.ShadowHoldSlider:Set(0.035)

    GakuranExtraUI.ShadowCriticalDelaySlider = Movement_Section:Slider(
        "R Delay", 0, 0.005, 0.030, 0.300, "s",
        function(v)
            GakuranExtraUI.ShadowCriticalDelay = v
        end
    )
    GakuranExtraUI.ShadowCriticalDelaySlider:Set(0.255)

    GakuranExtraUI.ShadowCriticalHoldSlider = Movement_Section:Slider(
        "R Hold", 0, 0.005, 0.030, 0.200, "s",
        function(v)
            GakuranExtraUI.ShadowCriticalHold = v
        end
    )
    GakuranExtraUI.ShadowCriticalHoldSlider:Set(0.080)

    GakuranExtraUI.ShadowStepAction =
        Movement_Section:Toggle("Shadow Step", false)

    GakuranExtraUI.ShadowStepAction:AddKeybind(
        "z",
        "Hold",
        function(active)
            if not active then return end

            if not GakuranExtraUI.ShadowStepAction
                or not GakuranExtraUI.ShadowStepAction.Get
                or not GakuranExtraUI.ShadowStepAction:Get() then
                return
            end

            local fn = rawget(_G, "__GakuranShadowStep")
            if fn then
                fn()
            else
                print("[Shadow Step] runtime is not ready")
            end
        end
    )

    GakuranExtraUI.ShadowCriticalAction =
        Movement_Section:Toggle("Shadow Crit", false)

    GakuranExtraUI.ShadowCriticalAction:AddKeybind(
        "b",
        "Hold",
        function(active)
            if not active then return end

            if not GakuranExtraUI.ShadowCriticalAction
                or not GakuranExtraUI.ShadowCriticalAction.Get
                or not GakuranExtraUI.ShadowCriticalAction:Get() then
                return
            end

            local fn = rawget(_G, "__GakuranShadowStepCritical")
            if fn then
                fn()
            else
                print("[Shadow Step] critical runtime is not ready")
            end
        end
    )

    -- Performance
    GakuranExtraUI.LowLagMode =
        Performance_Section:Toggle("Low Lag Mode", true)
    Performance_Section:Label("Cuts extra ESP and scan work.")

    -- Timing
    TimingDiag_Section:Label("Records F timing by style. Wing Chun M2 is skipped.")

    local timingStyleOptions = {"All Styles"}
    local timingStyleSeen = {}

    for _, timingInfo in pairs(GameConfig) do
        if type(timingInfo) == "table" and timingInfo.Style then
            local timingStyleName = tostring(timingInfo.Style)
            if not timingStyleSeen[timingStyleName] then
                timingStyleSeen[timingStyleName] = true
                table.insert(timingStyleOptions, timingStyleName)
            end
        end
    end

    table.sort(timingStyleOptions, function(a, b)
        if a == b then return false end
        if a == "All Styles" then return true end
        if b == "All Styles" then return false end
        return a < b
    end)

    GakuranExtraUI.DiagStyleFilter = "All Styles"
    local timingStyleDropdown = TimingDiag_Section:Dropdown(
        "Style",
        nil,
        timingStyleOptions,
        false,
        function(list)
            GakuranExtraUI.DiagStyleFilter =
                list and list[1] or "All Styles"
        end
    )
    timingStyleDropdown:Set({"All Styles"})

    GakuranExtraUI.DiagToggle =
        TimingDiag_Section:Toggle("Record Timing", false)

    TimingDiag_Section:Button("Copy Results", function()
        local fn = rawget(_G, "__GakuranTimingDiagnosticsCopy")
        if fn then
            fn()
        else
            print("[TIMING-DIAG] diagnostics runtime is not ready")
        end
    end)

    TimingDiag_Section:Button("Clear Results", function()
        local fn = rawget(_G, "__GakuranTimingDiagnosticsClear")
        if fn then
            fn()
        end
    end)

    TimingDiag_Section:Divider("Timing Learner")
    TimingDiag_Section:Label("Learns small F timing fixes after enough parries.")

    GakuranExtraUI.LearningToggle =
        TimingDiag_Section:Toggle("Timing Learner", false)

    TimingDiag_Section:Button("Copy Learned Timings", function()
        local fn = rawget(_G, "__GakuranLearningCopy")
        if fn then
            fn()
        end
    end)

    TimingDiag_Section:Button("Reset Learned Timings", function()
        local fn = rawget(_G, "__GakuranLearningReset")
        if fn then
            fn()
        end
    end)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,67,111,109,98,97,116,32,85,73,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _I=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,69,118,97,108,117,97,116,101,67,104,97,114,97,99,116,101,114,40,99,104,97,114,97,99,116,101,114,44,32,108,111,99,97,108,67,104,97,114,97,99,116,101,114,44,32,108,111,99,97,108,82,111,111,116,44,32,99,117,114,114,101,110,116,65,99,116,105,118,101,73,100,115,41)_t=_k(_t,_I,_f.._I)if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,102,114,97,109,101,32,99,97,99,104,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _J=[[    -- ANIMATION LOOP
    local activeAnimations = AnimationTracker:Update(character)
    if not activeAnimations or #activeAnimations == 0 then return end]]_t=_k(_t,_J,[[    -- ANIMATION LOOP
    local activeAnimations = GetFrameAnimations(character)
    if not activeAnimations or #activeAnimations == 0 then return end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,69,118,97,108,117,97,116,101,67,104,97,114,97,99,116,101,114,32,116,114,97,99,107,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _K=[[        -- Fetch active animations using your AnimationTracker system
        local activeAnimations = AnimationTracker:Update(character) or {}]]_t=_k(_t,_K,[[        -- Reuse this frame's target animation snapshot when available.
        local activeAnimations = GetFrameAnimations(character) or {}]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,69,83,80,32,116,114,97,99,107,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _L=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,82,101,115,101,116,80,97,114,114,121,83,116,97,116,101,40,41)_t=_k(_t,_L,_j.._L)if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,114,117,110,116,105,109,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _M=[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    if regData.Processed then return end]]_t=_k(_t,_M,[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    AdaptiveTiming.Observe(regData, attackConfig, anim, character, now, animKey)
    if regData.Processed then return end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,69,118,97,108,117,97,116,101,65,110,105,109,97,116,105,111,110,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _N=[[           attackConfig.ParryFunction({]]_t=_k(_t,_N,[[           AdaptiveTiming.MarkCustom(regData, attackConfig, anim, character, now, animKey)
           attackConfig.ParryFunction({]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,99,117,115,116,111,109,45,112,97,114,114,121,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _O=[[    local HoldFor = HoldFor or BlockHoldTime]]_t=_k(_t,_O,[[    AdaptiveTiming.OnBlockStart(StartTime, HoldFor)
    local HoldFor = HoldFor or BlockHoldTime]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,66,108,111,99,107,83,116,97,114,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _P=[[        InputRegisteredTime = os.clock()
        TransitionToState(ParryState.INPUT_PENDING)]]_t=_k(_t,_P,[[        InputRegisteredTime = os.clock()
        AdaptiveTiming.OnInputRegistered(InputRegisteredTime)
        TransitionToState(ParryState.INPUT_PENDING)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,105,110,112,117,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _Q=[[        ParryRegisteredTime = os.clock()
        InputLatency = os.clock() - InputRegisteredTime]]_t=_k(_t,_Q,[[        ParryRegisteredTime = os.clock()
        InputLatency = os.clock() - InputRegisteredTime
        AdaptiveTiming.OnParryRegistered(ParryRegisteredTime, InputLatency)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,114,101,103,105,115,116,101,114,101,100,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _R=[[        LastPendingRegData.Success = true]]_t=_k(_t,_R,[[        LastPendingRegData.Success = true
        AdaptiveTiming.Finish("PARRY_SUCCESS", LastPendingRegData)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,115,117,99,99,101,115,115,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _S=[[local function OnParryingAnimationFailed()
    if CurrentParryState == ParryState.INPUT_PENDING then]]_t=_k(_t,_S,[[local function OnParryingAnimationFailed()
    if CurrentParryState == ParryState.INPUT_PENDING then
        AdaptiveTiming.Finish("PARRY_ANIM_FAILED", AdaptiveTiming.InputRegData)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,102,97,105,108,117,114,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _T=[[local function OnWindowExceeded()
    if CurrentParryState == ParryState.PARRYING then]]_t=_k(_t,_T,[[local function OnWindowExceeded()
    if CurrentParryState == ParryState.PARRYING then
        AdaptiveTiming.Finish("WINDOW_EXCEEDED", AdaptiveTiming.InputRegData)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,119,105,110,100,111,119,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end do local _U=[[        return stateFolder:GetAttribute("CurrentHeight")]]local _V=_k(_t,_U,[[        local heightValue =
            stateFolder
            and stateFolder:GetAttribute("CurrentHeight")

        if type(heightValue) == "number"
            and heightValue > 0 then
            return math.clamp(heightValue, 0.65, 1.45)
        end

        return 1]])if _V then _t=_V print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,97,102,101,32,104,101,105,103,104,116,32,112,97,116,99,104,101,100))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,115,97,102,101,32,104,101,105,103,104,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100,59,32,99,111,110,116,105,110,117,105,110,103,32,119,105,116,104,111,117,116,32,104,101,105,103,104,116,32,115,97,102,101,116,121,32,112,97,116,99,104))end end do local _W=[[function Dodge()
    --keyrelease(DodgeKey)]]_t=_k(_t,_W,[[function Dodge()
    if GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.MarkDodge then
        GakuranExtraUI.CombatAssist.MarkDodge("AutoDodge")
    end
    --keyrelease(DodgeKey)]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,100,111,100,103,101,32,116,114,97,99,107,105,110,103,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _X=[[    if attackConfig.Jump then]]local _Y=_k(_t,_X,[[    if isHeavy
        and GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.HandleHeavy
        and GakuranExtraUI.CombatAssist.HandleHeavy(
            regData,
            attackConfig
        ) then
        -- handled by optional Critical Defense mode
    elseif attackConfig.Jump then]])if _Y then _t=_Y print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,114,105,116,105,99,97,108,32,100,101,102,101,110,115,101,32,112,97,116,99,104,101,100))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,99,114,105,116,105,99,97,108,32,100,101,102,101,110,115,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100,59,32,99,111,110,116,105,110,117,105,110,103,32,119,105,116,104,32,100,101,102,97,117,108,116,32,99,114,105,116,105,99,97,108,32,104,97,110,100,108,105,110,103))end end do local _Z=[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    AdaptiveTiming.Observe(regData, attackConfig, anim, character, now, animKey)
    if regData.Processed then return end]]_t=_k(_t,_Z,[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    AdaptiveTiming.Observe(regData, attackConfig, anim, character, now, animKey)

    if GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.IsWingChunCounter
        and GakuranExtraUI.CombatAssist.IsWingChunCounter(
            attackConfig
        ) then

        if GakuranExtraUI.CombatAssist.HandleWingChunCounter then
            GakuranExtraUI.CombatAssist.HandleWingChunCounter(
                character,
                localCharacter,
                localRoot,
                attackConfig,
                anim
            )
        end

        return
    end

    if regData.Processed then return end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,87,105,110,103,32,67,104,117,110,32,99,111,117,110,116,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _aa=[[UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessedEvent then warn("NO") return end]]_t=_k(_t,_aa,[[UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessedEvent then warn("NO") return end

    if input.KeyCode == string.byte("q")
        and GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.MarkDodge then

        GakuranExtraUI.CombatAssist.MarkDodge("ManualQ")
    end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,109,97,110,117,97,108,32,100,97,115,104,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _ba=[[        ProcessEspAndLogging()]]_t=_k(_t,_ba,[[        if not (
            GakuranExtraUI
            and GakuranExtraUI.LowLagMode
            and GakuranExtraUI.LowLagMode.Get
            and GakuranExtraUI.LowLagMode.Get()
        ) then
            ProcessEspAndLogging()
        end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,76,111,119,32,76,97,103,32,69,83,80,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _ca=[[    local optimalReactionTime = (attackConfig.ReactionTime or DefaultReactionTime)]]_t=_k(_t,_ca,[[    local optimalReactionTime = (
        attackConfig.ReactionTime
        or attackConfig.DefaultReactionTime
        or DefaultReactionTime
    )

    -- Learned values are additive and never overwrite the base style config.
    if AdaptiveTiming and AdaptiveTiming.GetAdjustment then
        optimalReactionTime += AdaptiveTiming.GetAdjustment(attackConfig)
    end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,76,101,97,114,110,105,110,103,32,77,111,100,101,32,116,105,109,105,110,103,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end local _da=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,69,118,97,108,117,97,116,101,80,97,114,114,121,84,114,105,103,103,101,114,115,40,41)_t=_k(_t,_da,string.char(108,111,99,97,108,32,66,108,97,116,97,110,116,70,97,99,101,84,104,114,101,97,116,67,104,97,114,97,99,116,101,114,32,61,32,110,105,108,10).._da)if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,116,104,114,101,97,116,32,98,114,105,100,103,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _ea=[[    -- CHARACTER ITERATION
    for _, character in ipairs(TargetCharacters) do
        EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
    end]]_t=_k(_t,_ea,[[    -- CHARACTER ITERATION
    if BlatantFaceThreatCharacter
        and BlatantFaceThreatCharacter ~= localCharacter
        and BlatantFaceThreatCharacter.ClassName == "Model" then
        EvaluateCharacter(
            BlatantFaceThreatCharacter,
            localCharacter,
            localRoot,
            currentActiveIds
        )
    else
        for _, character in ipairs(TargetCharacters) do
            EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
        end
    end]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,65,80,32,116,104,114,101,97,116,32,105,116,101,114,97,116,105,111,110,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _fa=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,77,97,105,110,76,111,111,112,40,41)_t=_k(_t,_fa,_h.._g.._i.._fa)if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,114,117,110,116,105,109,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _ga=[[    LocalTracker:Update(localChar)
    EvaluateParryTriggers()]]_t=_k(_t,_ga,[[    table.clear(FrameAnimationCache)
    local localAnimations = LocalTracker:Update(localChar)

    if GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.Task then
        GakuranExtraUI.CombatAssist.Task(
            localChar,
            localAnimations
        )
    end

    -- Defensive Snap/Parry runs after offensive aim helpers, so parry wins any
    -- same-frame facing conflict.
    BlatantFaceTask()
    EvaluateParryTriggers()]])if not _t then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,109,97,105,110,45,108,111,111,112,32,83,110,97,112,32,76,111,99,107,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _ha,_ia=loadstring(_t)if not _ha then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,111,109,112,105,108,101,32,102,97,105,108,101,100,58,32)..tostring(_ia))return end if rawget(_G,string.char(95,95,71,97,107,117,114,97,110,67,111,109,98,105,110,101,100,67,111,109,112,105,108,101,79,110,108,121))==true then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,111,109,112,105,108,101,32,99,104,101,99,107,32,112,97,115,115,101,100))return end local _ja=rawget(_G,_c)if type(_ja)==string.char(116,97,98,108,101)and _ja.jobId==game.JobId then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,97,108,114,101,97,100,121,32,108,111,97,100,101,100,32,105,110,32,116,104,105,115,32,77,97,116,99,104,97,32,115,101,115,115,105,111,110,59,32)..string.char(114,101,115,116,97,114,116,32,77,97,116,99,104,97,32,98,101,102,111,114,101,32,108,111,97,100,105,110,103,32,97,110,111,116,104,101,114,32,71,97,107,117,114,97,110,32,98,117,105,108,100))return end _G[_c]={jobId=game.JobId,version=string.char(97,112,45,111,110,108,121,45,118,55,46,50,46,53,45,117,105,45,99,114,101,97,116,101,119,105,110,100,111,119,45,102,105,120),}local _ka,_la=pcall(_ha)if not _ka then _G[_c]=nil print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,114,117,110,116,105,109,101,32,102,97,105,108,101,100,58,32)..tostring(_la))return end print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,108,111,97,100,101,100,32,118,55,46,50,46,53,32,43,32,85,73,32,108,111,97,100,101,114,32,102,105,120))
