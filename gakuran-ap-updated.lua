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

-- ===== Striker accelerating timing curve =====
local STRIKER_FIRST_REACTION = 0.200
local STRIKER_EARLY_STEP = 0.020
local STRIKER_LATE_ACCELERATION = 0.110
local STRIKER_REACTION_FLOOR = 0.050
local STRIKER_HIT_COUNT = 4
local STRIKER_FEINT_REACTION = 0.300

local function GetStrikerReactionTime(displayName)
    local name = tostring(displayName or "")
    local hitIndex = tonumber(string.match(name, "^(%d+)"))

    if hitIndex and hitIndex >= 1 and hitIndex <= STRIKER_HIT_COUNT then
        local step = hitIndex - 1
        local lateStep = math.max(0, step - 1)

        local reactionTime =
            STRIKER_FIRST_REACTION
            - (STRIKER_EARLY_STEP * step)
            - (
                STRIKER_LATE_ACCELERATION
                * lateStep
                * lateStep
            )

        return math.max(
            STRIKER_REACTION_FLOOR,
            reactionTime
        )
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
-- ===== end Striker accelerating timing curve =====
]====]local _f=[====[
-- ===== v7.2.4 merge: Ali timing update only =====
local ALI_REACTION_TIMINGS = {
    ["1stM1"] = 0.120,
    ["2ndM1"] = 0.170,
    ["3rdM1"] = 0.210,
    ["4thM1"] = 0.110,
    ["M2"] = 0.270,
    ["M2Right"] = 0.270,
}

local aliTimingPatchCount = 0

for _, info in pairs(GameConfig or {}) do
    if type(info) == "table"
        and info.Style == "AliAnims" then

        local updated =
            ALI_REACTION_TIMINGS[tostring(info.DisplayName or "")]

        if updated ~= nil then
            info.ReactionTime = updated
            info.DefaultReactionTime = nil
            aliTimingPatchCount += 1
        end
    end
end

print(
    "[Gakuran AP Share] Ali timings updated: "
        .. tostring(aliTimingPatchCount)
)
-- ===== end Ali timing update =====
]====]local _g=[====[
-- ===== Capoeira heavy classification fix =====
-- Upstream currently names the Capoeira heavy "Whirlwind", but its generic
-- heavy checks only recognize M2 / Heavy / attackConfig.Heavy.
-- Mark ONLY Capoeira Whirlwind as Heavy so:
--   * facing checks don't reject the spinning heavy as a normal M1;
--   * Auto Dodge recognizes it as a heavy;
--   * with Auto Dodge off, normal Auto Parry can still handle it.
-- Existing Capoeira reaction timing is preserved exactly.
local capoeiraHeavyPatchCount = 0

for _, info in pairs(GameConfig or {}) do
    if type(info) == "table"
        and tostring(info.Style or "") == "CapoeiraAnims"
        and tostring(info.DisplayName or "") == "Whirlwind" then

        info.Heavy = true
        capoeiraHeavyPatchCount += 1
    end
end

print(
    "[Gakuran AP Share] Capoeira heavy fix: "
        .. tostring(capoeiraHeavyPatchCount)
)
-- ===== end Capoeira heavy classification fix =====
]====]local _h=[====[
-- ===== Wing Chun timing update =====
-- Reverted to the original Wing Chun timings from the earlier base:
--   1stM1 = 160 ms
--   2ndM1 = 160 ms
--   3rdM1 = 160 ms
--   4thM1 = 520 ms
--   M2    =  60 ms
local WINGCHUN_REACTION_TIMINGS = {
    ["1stM1"] = 0.160,
    ["2ndM1"] = 0.160,
    ["3rdM1"] = 0.160,
    ["4thM1"] = 0.520,
    ["M2"] = 0.060,
}

local wingChunTimingPatchCount = 0

for _, info in pairs(GameConfig or {}) do
    if type(info) == "table" then
        local style =
            tostring(info.Style or "")

        if style == "WingChun"
            or style == "WingChunAnims" then

            local updated =
                WINGCHUN_REACTION_TIMINGS[
                    tostring(info.DisplayName or "")
                ]

            if updated ~= nil then
                info.ReactionTime = updated
                info.DefaultReactionTime = nil
                wingChunTimingPatchCount += 1
            end
        end
    end
end

print(
    "[Gakuran AP Share] Wing Chun timings updated: "
        .. tostring(wingChunTimingPatchCount)
)
-- ===== end Wing Chun timing update =====
]====]local _i=[====[
-- ==========================================================
-- v7.2.4 merge: shared living-target guard
-- ==========================================================
local function GakuranIsLivingTarget(character)
    if not character
        or not character.Parent
        or character.ClassName ~= "Model" then

        return false
    end

    local humanoid =
        character:FindFirstChildWhichIsA("Humanoid")

    local root =
        character:FindFirstChild("HumanoidRootPart")

    return humanoid ~= nil
        and humanoid.Health > 0
        and root ~= nil
        and root.Parent ~= nil
end

local function GakuranPruneDeadTargets()
    if type(TargetCharacters) ~= "table" then
        return
    end

    local hadTarget = #TargetCharacters > 0
    local removedDead = false

    for index = #TargetCharacters, 1, -1 do
        if not GakuranIsLivingTarget(TargetCharacters[index]) then
            table.remove(TargetCharacters, index)
            removedDead = true
        end
    end

    if BlatantFaceThreatCharacter
        and not GakuranIsLivingTarget(
            BlatantFaceThreatCharacter
        ) then

        BlatantFaceThreatCharacter = nil
    end

    -- If a selected target dies, replace it immediately with the nearest
    -- living target from the same configured target pool. This only auto-picks
    -- after a death; an intentionally empty target list stays empty.
    if removedDead
        and hadTarget
        and #TargetCharacters == 0 then

        local localCharacter =
            LocalPlayer and LocalPlayer.Character

        local localRoot =
            localCharacter
            and localCharacter:FindFirstChild("HumanoidRootPart")

        if not localRoot then
            return
        end

        local candidates =
            GetAllCharactersInFolder() or {}

        local best = nil
        local bestDistance = math.huge
        local maxRange =
            tonumber(MaxCycleRange) or math.huge

        for _, character in ipairs(candidates) do
            if character ~= localCharacter
                and GakuranIsLivingTarget(character) then

                local root =
                    character:FindFirstChild("HumanoidRootPart")

                local distance =
                    (root.Position - localRoot.Position).Magnitude

                if distance <= maxRange
                    and distance < bestDistance then

                    best = character
                    bestDistance = distance
                end
            end
        end

        if best then
            TargetCharacters[1] = best
            CurrentIndex = 1
        end
    end
end
]====]local _j=[====[
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

]====]local _k=[====[
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

    -- Keep AP bridged only while the exact attacker is still alive.
    if BlatantFaceThreat.character
        and GakuranIsLivingTarget(BlatantFaceThreat.character)
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
            and GakuranIsLivingTarget(BlatantFaceLock.character)
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

]====]local _l=[====[
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

]====]local _m=[====[
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

        local counterCharacter =
            targetRoot and targetRoot.Parent

        if targetRoot
            and targetRoot.Parent
            and GakuranIsLivingTarget(counterCharacter) then

            local away =
                localRoot.Position - targetRoot.Position

            GakuranExtraUI.CombatAssist.FaceDirection(
                localRoot,
                away,
                1.25
            )
        else
            GakuranExtraUI.CombatAssist.CounterEscapeTarget = nil
            GakuranExtraUI.CombatAssist.CounterEscapeAnimKey = nil
            GakuranExtraUI.CombatAssist.CounterEscapeUntil = 0
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

    local target =
        GakuranExtraUI.CombatAssist.CriticalAimTarget

    local targetRoot =
        GakuranExtraUI.CombatAssist.CriticalAimTargetRoot

    if not GakuranIsLivingTarget(target)
        or not targetRoot
        or not targetRoot.Parent then

        target, targetRoot =
            GakuranExtraUI.CombatAssist.FindNearestCriticalTarget(
                localRoot
            )

        GakuranExtraUI.CombatAssist.CriticalAimTarget =
            target

        GakuranExtraUI.CombatAssist.CriticalAimTargetRoot =
            targetRoot
    end

    if targetRoot
        and targetRoot.Parent
        and GakuranIsLivingTarget(target) then

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

]====]local _n=[====[
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

]====]local function _o(_p,_q,_r)local _s,_t=string.find(_p,_q,1,true)if not _s then return nil end return string.sub(_p,1,_s-1).._r..string.sub(_p,_t+1)end local _u=game:HttpGet(_b)local _v=string.char(108,111,99,97,108,32,75,110,111,119,110,79,102,102,115,101,116,115,32,61,32,123)_u=_o(_u,_v,_d.._v)if not _u then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,110,105,109,97,116,105,111,110,32,116,114,97,99,107,101,114,32,102,111,114,109,97,116,32,99,104,97,110,103,101,100))return end local _w=[[            local liveTime = GetTimePosition(address) or info.TimePosition
            info.TimePosition = liveTime]]_u=_o(_u,_w,[[            local liveTime = GetTimePosition(address) or info.TimePosition
            info.TimePosition = liveTime
            local liveSpeed = memory_read("float", address + KnownOffsets.Speed)
            if liveSpeed then
                info.Speed = liveSpeed
            end]])if not _u then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,110,105,109,97,116,105,111,110,32,116,114,97,99,107,101,114,32,115,112,101,101,100,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _x=game:HttpGet(_a)local _y=[[local URL = "https://raw.githubusercontent.com/artxficial/matchastuff/main/animationtracker.lua"
local ImportAnimationTracker = loadstring(game:HttpGet(URL))()]]local _z=string.char(108,111,99,97,108,32,73,109,112,111,114,116,65,110,105,109,97,116,105,111,110,84,114,97,99,107,101,114,32,61,32,108,111,97,100,115,116,114,105,110,103,40)..string.format(string.char(37,113),_u)..string.char(41,40,41)_x=_o(_x,_y,_z)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,117,116,111,45,112,97,114,114,121,32,116,114,97,99,107,101,114,32,105,109,112,111,114,116,32,102,111,114,109,97,116,32,99,104,97,110,103,101,100))return end local _A=string.char(71,97,109,101,67,111,110,102,105,103,32,61,32,70,108,97,116,116,101,110,101,100,67,111,110,102,105,103)_x=_o(_x,_A,_A.._e.._f.._h.._g)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,102,108,97,116,116,101,110,101,100,32,71,97,109,101,67,111,110,102,105,103,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end do local _B=0 _x,_B=string.gsub(_x,string.char(105,102,37,115,43,67,104,97,114,97,99,116,101,114,37,46,67,108,97,115,115,78,97,109,101,37,115,42,61,61,37,115,42,34,77,111,100,101,108,34,37,115,43,97,110,100,37,115,43,67,104,97,114,97,99,116,101,114,58,70,105,110,100,70,105,114,115,116,67,104,105,108,100,87,104,105,99,104,73,115,65,37,40,34,72,117,109,97,110,111,105,100,34,37,41,37,115,43,116,104,101,110),[[local targetHumanoid =
            Character:FindFirstChildWhichIsA("Humanoid")

        if Character.ClassName == "Model"
            and targetHumanoid
            and targetHumanoid.Health > 0 then]],1)if _B==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,97,114,103,101,116,45,112,111,111,108,32,104,101,97,108,116,104,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,116,97,114,103,101,116,45,112,111,111,108,32,104,101,97,108,116,104,32,99,104,101,99,107,32,112,97,116,99,104,101,100))end do local _C=[[local function EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
    -- CHARACTER VALIDATION]]local _D=[[local function EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
    -- CHARACTER VALIDATION
    local targetHumanoid =
        character
        and character:FindFirstChildWhichIsA("Humanoid")

    if not targetHumanoid
        or targetHumanoid.Health <= 0 then
        return
    end]]_x=_o(_x,_C,_D)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,65,80,32,104,101,97,108,116,104,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,65,80,32,104,101,97,108,116,104,32,99,104,101,99,107,32,112,97,116,99,104,101,100))end local _E=0 _x,_E=string.gsub(_x,string.char(105,102,37,115,43,118,37,115,42,126,61,37,115,42,68,101,102,97,117,108,116,82,101,97,99,116,105,111,110,84,105,109,101,37,115,43,116,104,101,110,37,115,43,73,110,102,111,37,46,82,101,97,99,116,105,111,110,84,105,109,101,37,115,42,61,37,115,42,118,37,115,43,101,110,100),string.char(73,110,102,111,46,82,101,97,99,116,105,111,110,84,105,109,101,32,61,32,118),1)if _E==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,114,101,97,99,116,105,111,110,32,115,108,105,100,101,114,32,99,97,108,108,98,97,99,107,32,112,97,116,99,104,32,115,107,105,112,112,101,100,59,32,99,111,110,116,105,110,117,105,110,103))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,114,101,97,99,116,105,111,110,32,115,108,105,100,101,114,32,99,97,108,108,98,97,99,107,32,112,97,116,99,104,101,100))end local _F=[[    if not AnimationRegistry[animKey] then
        local adjustedNow = now - ConstLatency -- - currentTrackTime
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)]]_x=_o(_x,_F,[[    if not AnimationRegistry[animKey] then
        local playbackSpeed = math.abs(tonumber(anim.Speed) or 1)
        if playbackSpeed < 0.05 then playbackSpeed = 1 end
        local elapsedReal = math.max(tonumber(currentTrackTime) or 0, 0) / playbackSpeed
        local adjustedNow = now - elapsedReal - ConstLatency
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,115,116,97,114,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _H=0 _x,_H=string.gsub(_x,string.char(108,111,99,97,108,37,115,43,66,108,111,99,107,83,116,97,114,116,44,37,115,42,66,108,111,99,107,69,120,112,105,114,101,37,115,42,61,37,115,42,67,97,108,99,117,108,97,116,101,80,97,114,114,121,84,105,109,105,110,103,37,40,37,115,42,97,116,116,97,99,107,67,111,110,102,105,103,44,37,115,42,110,111,119,37,115,42,37,45,37,115,42,99,117,114,114,101,110,116,84,114,97,99,107,84,105,109,101,44,37,115,42,84,97,114,103,101,116,67,104,97,114,97,99,116,101,114,37,115,42,37,41),[[local playbackSpeed = math.abs(tonumber(anim.Speed) or 1)
        if playbackSpeed < 0.05 then playbackSpeed = 1 end
        local elapsedReal = math.max(tonumber(currentTrackTime) or 0, 0) / playbackSpeed
        local adjustedNow = now - elapsedReal - ConstLatency
        local BlockStart, BlockExpire = CalculateParryTiming(attackConfig, adjustedNow, TargetCharacter)]],1)local _I=0 if _H>0 then _x,_I=string.gsub(_x,string.char(114,101,103,68,97,116,97,37,46,83,116,97,114,116,84,105,109,101,37,115,42,61,37,115,42,110,111,119,37,115,42,37,45,37,115,42,67,111,110,115,116,76,97,116,101,110,99,121,91,94,13,10,93,42),string.char(114,101,103,68,97,116,97,46,83,116,97,114,116,84,105,109,101,32,61,32,97,100,106,117,115,116,101,100,78,111,119),1)end if _H==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,108,111,111,112,32,116,105,109,105,110,103,32,112,97,116,99,104,32,115,107,105,112,112,101,100,59,32,99,111,110,116,105,110,117,105,110,103))elseif _I==0 then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,108,111,111,112,32,83,116,97,114,116,84,105,109,101,32,112,97,116,99,104,32,115,107,105,112,112,101,100,59,32,99,111,110,116,105,110,117,105,110,103))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,97,110,105,109,97,116,105,111,110,32,114,101,103,105,115,116,114,121,32,108,111,111,112,32,116,105,109,105,110,103,32,112,97,116,99,104,101,100))end _x=_o(_x,string.char(108,111,99,97,108,32,72,101,105,103,104,116,84,111,103,103,108,101),string.char(108,111,99,97,108,32,72,101,105,103,104,116,84,111,103,103,108,101,10,108,111,99,97,108,32,71,97,107,117,114,97,110,69,120,116,114,97,85,73,32,61,32,123,125))if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,115,116,97,116,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _J=[[local Config_Tab = UI_Window:Tab("Style Configurations", "swords")]]_x=_o(_x,_J,_J..[[
local Blatant_Tab = UI_Window:Tab("Combat", "swords")]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,67,111,109,98,97,116,32,116,97,98,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _K=[[local Folders_Section   = AP_Tab:Section("Folders", "Right")]]_x=_o(_x,_K,_K..[[
local Combat_Section = Blatant_Tab:Section("Combat", "Left")
local Movement_Section = Blatant_Tab:Section("Movement", "Left")
local Performance_Section = Blatant_Tab:Section("Performance", "Right")
local TimingDiag_Section = Blatant_Tab:Section("Timing", "Right")]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,67,111,109,98,97,116,32,115,101,99,116,105,111,110,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _L=[[    HeightToggle = AP_Section:Toggle("Height Multiplier (May crash some users)", true)]]_x=_o(_x,_L,_L..[[
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
    end)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,67,111,109,98,97,116,32,85,73,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _M=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,69,118,97,108,117,97,116,101,67,104,97,114,97,99,116,101,114,40,99,104,97,114,97,99,116,101,114,44,32,108,111,99,97,108,67,104,97,114,97,99,116,101,114,44,32,108,111,99,97,108,82,111,111,116,44,32,99,117,114,114,101,110,116,65,99,116,105,118,101,73,100,115,41)_x=_o(_x,_M,_j.._M)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,102,114,97,109,101,32,99,97,99,104,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _N=[[    -- ANIMATION LOOP
    local activeAnimations = AnimationTracker:Update(character)
    if not activeAnimations or #activeAnimations == 0 then return end]]_x=_o(_x,_N,[[    -- ANIMATION LOOP
    local activeAnimations = GetFrameAnimations(character)
    if not activeAnimations or #activeAnimations == 0 then return end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,69,118,97,108,117,97,116,101,67,104,97,114,97,99,116,101,114,32,116,114,97,99,107,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _O=[[        -- Fetch active animations using your AnimationTracker system
        local activeAnimations = AnimationTracker:Update(character) or {}]]_x=_o(_x,_O,[[        -- Reuse this frame's target animation snapshot when available.
        local activeAnimations = GetFrameAnimations(character) or {}]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,69,83,80,32,116,114,97,99,107,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _P=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,82,101,115,101,116,80,97,114,114,121,83,116,97,116,101,40,41)_x=_o(_x,_P,_n.._P)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,114,117,110,116,105,109,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _Q=[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    if regData.Processed then return end]]_x=_o(_x,_Q,[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    AdaptiveTiming.Observe(regData, attackConfig, anim, character, now, animKey)
    if regData.Processed then return end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,69,118,97,108,117,97,116,101,65,110,105,109,97,116,105,111,110,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _R=[[           attackConfig.ParryFunction({]]_x=_o(_x,_R,[[           AdaptiveTiming.MarkCustom(regData, attackConfig, anim, character, now, animKey)
           attackConfig.ParryFunction({]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,99,117,115,116,111,109,45,112,97,114,114,121,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _S=[[    local HoldFor = HoldFor or BlockHoldTime]]_x=_o(_x,_S,[[    AdaptiveTiming.OnBlockStart(StartTime, HoldFor)
    local HoldFor = HoldFor or BlockHoldTime]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,66,108,111,99,107,83,116,97,114,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _T=[[        InputRegisteredTime = os.clock()
        TransitionToState(ParryState.INPUT_PENDING)]]_x=_o(_x,_T,[[        InputRegisteredTime = os.clock()
        AdaptiveTiming.OnInputRegistered(InputRegisteredTime)
        TransitionToState(ParryState.INPUT_PENDING)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,105,110,112,117,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _U=[[        ParryRegisteredTime = os.clock()
        InputLatency = os.clock() - InputRegisteredTime]]_x=_o(_x,_U,[[        ParryRegisteredTime = os.clock()
        InputLatency = os.clock() - InputRegisteredTime
        AdaptiveTiming.OnParryRegistered(ParryRegisteredTime, InputLatency)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,114,101,103,105,115,116,101,114,101,100,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _V=[[        LastPendingRegData.Success = true]]_x=_o(_x,_V,[[        LastPendingRegData.Success = true
        AdaptiveTiming.Finish("PARRY_SUCCESS", LastPendingRegData)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,115,117,99,99,101,115,115,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _W=[[local function OnParryingAnimationFailed()
    if CurrentParryState == ParryState.INPUT_PENDING then]]_x=_o(_x,_W,[[local function OnParryingAnimationFailed()
    if CurrentParryState == ParryState.INPUT_PENDING then
        AdaptiveTiming.Finish("PARRY_ANIM_FAILED", AdaptiveTiming.InputRegData)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,102,97,105,108,117,114,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _X=[[local function OnWindowExceeded()
    if CurrentParryState == ParryState.PARRYING then]]_x=_o(_x,_X,[[local function OnWindowExceeded()
    if CurrentParryState == ParryState.PARRYING then
        AdaptiveTiming.Finish("WINDOW_EXCEEDED", AdaptiveTiming.InputRegData)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,116,105,109,105,110,103,32,100,105,97,103,110,111,115,116,105,99,115,32,119,105,110,100,111,119,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end do local _Y=[[        return stateFolder:GetAttribute("CurrentHeight")]]local _Z=_o(_x,_Y,[[        local heightValue =
            stateFolder
            and stateFolder:GetAttribute("CurrentHeight")

        if type(heightValue) == "number"
            and heightValue > 0 then
            return math.clamp(heightValue, 0.65, 1.45)
        end

        return 1]])if _Z then _x=_Z print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,97,102,101,32,104,101,105,103,104,116,32,112,97,116,99,104,101,100))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,115,97,102,101,32,104,101,105,103,104,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100,59,32,99,111,110,116,105,110,117,105,110,103,32,119,105,116,104,111,117,116,32,104,101,105,103,104,116,32,115,97,102,101,116,121,32,112,97,116,99,104))end end do local _aa=[[function Dodge()
    --keyrelease(DodgeKey)]]_x=_o(_x,_aa,[[function Dodge()
    if GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.MarkDodge then
        GakuranExtraUI.CombatAssist.MarkDodge("AutoDodge")
    end
    --keyrelease(DodgeKey)]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,100,111,100,103,101,32,116,114,97,99,107,105,110,103,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _ba=[[    if attackConfig.Jump then]]local _ca=_o(_x,_ba,[[    if isHeavy
        and GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.HandleHeavy
        and GakuranExtraUI.CombatAssist.HandleHeavy(
            regData,
            attackConfig
        ) then
        -- handled by optional Critical Defense mode
    elseif attackConfig.Jump then]])if _ca then _x=_ca print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,114,105,116,105,99,97,108,32,100,101,102,101,110,115,101,32,112,97,116,99,104,101,100))else print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,119,97,114,110,105,110,103,58,32,99,114,105,116,105,99,97,108,32,100,101,102,101,110,115,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100,59,32,99,111,110,116,105,110,117,105,110,103,32,119,105,116,104,32,100,101,102,97,117,108,116,32,99,114,105,116,105,99,97,108,32,104,97,110,100,108,105,110,103))end end do local _da=[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
    AdaptiveTiming.Observe(regData, attackConfig, anim, character, now, animKey)
    if regData.Processed then return end]]_x=_o(_x,_da,[[    local regData = UpdateAnimationRegistry(animKey, anim, now, anim.TimePosition or 0, attackConfig, character)
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

    if regData.Processed then return end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,87,105,110,103,32,67,104,117,110,32,99,111,117,110,116,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _ea=[[UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessedEvent then warn("NO") return end]]_x=_o(_x,_ea,[[UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessedEvent then warn("NO") return end

    if input.KeyCode == string.byte("q")
        and GakuranExtraUI
        and GakuranExtraUI.CombatAssist
        and GakuranExtraUI.CombatAssist.MarkDodge then

        GakuranExtraUI.CombatAssist.MarkDodge("ManualQ")
    end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,109,97,110,117,97,108,32,100,97,115,104,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _fa=[[        ProcessEspAndLogging()]]_x=_o(_x,_fa,[[        if not (
            GakuranExtraUI
            and GakuranExtraUI.LowLagMode
            and GakuranExtraUI.LowLagMode.Get
            and GakuranExtraUI.LowLagMode.Get()
        ) then
            ProcessEspAndLogging()
        end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,76,111,119,32,76,97,103,32,69,83,80,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end do local _ga=[[    local optimalReactionTime = (attackConfig.ReactionTime or DefaultReactionTime)]]_x=_o(_x,_ga,[[    local optimalReactionTime = (
        attackConfig.ReactionTime
        or attackConfig.DefaultReactionTime
        or DefaultReactionTime
    )

    -- Learned values are additive and never overwrite the base style config.
    if AdaptiveTiming and AdaptiveTiming.GetAdjustment then
        optimalReactionTime += AdaptiveTiming.GetAdjustment(attackConfig)
    end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,76,101,97,114,110,105,110,103,32,77,111,100,101,32,116,105,109,105,110,103,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end end local _ha=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,69,118,97,108,117,97,116,101,80,97,114,114,121,84,114,105,103,103,101,114,115,40,41)_x=_o(_x,_ha,string.char(108,111,99,97,108,32,66,108,97,116,97,110,116,70,97,99,101,84,104,114,101,97,116,67,104,97,114,97,99,116,101,114,32,61,32,110,105,108,10).._ha)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,116,104,114,101,97,116,32,98,114,105,100,103,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _ia=[[    -- CHARACTER ITERATION
    for _, character in ipairs(TargetCharacters) do
        EvaluateCharacter(character, localCharacter, localRoot, currentActiveIds)
    end]]_x=_o(_x,_ia,[[    -- CHARACTER ITERATION
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
    end]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,65,80,32,116,104,114,101,97,116,32,105,116,101,114,97,116,105,111,110,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _ja=string.char(108,111,99,97,108,32,102,117,110,99,116,105,111,110,32,77,97,105,110,76,111,111,112,40,41)_x=_o(_x,_ja,_i.._l.._k.._m..[[local function MainLoop()
    GakuranPruneDeadTargets()]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,83,110,97,112,32,76,111,99,107,32,114,117,110,116,105,109,101,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _ka=[[    LocalTracker:Update(localChar)
    EvaluateParryTriggers()]]_x=_o(_x,_ka,[[    table.clear(FrameAnimationCache)
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
    EvaluateParryTriggers()]])if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32,109,97,105,110,45,108,111,111,112,32,83,110,97,112,32,76,111,99,107,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end do local _la=[[-- 5. Files Section
local function CreateFilesSection()]]local _ma=[==[
_G.__GakuranSharedConfigManager =
    _G.__GakuranSharedConfigManager
    or {
        Format = "GakuranTimingConfig",
        Version = 2,
        Folder = "GakuranConfigs",
        Selected = "Basic",
        PendingName = "MyConfig",
        BasicTimings = nil,
        Dropdown = nil,
        NameBox = nil,
    }

function _G.__GakuranSharedConfigManager.Notify(title, message)
    local ok =
        pcall(function()
            UI_Library:Notify(
                tostring(title or "Config"),
                tostring(message or "")
            )
        end)

    if not ok then
        print(
            "[Gakuran Config] "
                .. tostring(title or "Config")
                .. ": "
                .. tostring(message or "")
        )
    end
end

function _G.__GakuranSharedConfigManager.SortedAnimationIds()
    local ids = {}

    for animationId, info in pairs(GameConfig or {}) do
        if type(info) == "table"
            and (
                info.DisplayName ~= nil
                or info.Style ~= nil
            ) then

            ids[#ids + 1] =
                tostring(animationId)
        end
    end

    table.sort(ids)
    return ids
end

function _G.__GakuranSharedConfigManager.CaptureTimings()
    local timings = {}

    for _, animationId
        in ipairs(
            _G.__GakuranSharedConfigManager.SortedAnimationIds()
        ) do

        local info =
            GameConfig[animationId]

        if type(info) == "table" then
            local reaction =
                tonumber(
                    info.ReactionTime
                    or info.DefaultReactionTime
                    or DefaultReactionTime
                )

            if reaction ~= nil then
                timings[animationId] =
                    reaction
            end
        end
    end

    return timings
end

function _G.__GakuranSharedConfigManager.CaptureBasic()
    if _G.__GakuranSharedConfigManager.BasicTimings then
        return
    end

    _G.__GakuranSharedConfigManager.BasicTimings =
        _G.__GakuranSharedConfigManager.CaptureTimings()

    _G.__GakuranBasicTimingConfig =
        _G.__GakuranSharedConfigManager.BasicTimings
end

function _G.__GakuranSharedConfigManager.ClearLearnedOffsets()
    if AdaptiveTiming
        and type(AdaptiveTiming.Learned) == "table" then

        table.clear(
            AdaptiveTiming.Learned
        )
    end
end

function _G.__GakuranSharedConfigManager.Apply(config, sourceName)
    if type(config) ~= "table" then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Config is not a table."
        )
        return false
    end

    local timings =
        config.Timings
        or config.timings
        or config

    if type(timings) ~= "table" then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "No Timings table found."
        )
        return false
    end

    local applied = 0
    local skipped = 0

    for animationId, value in pairs(timings) do
        animationId =
            tostring(animationId)

        local reaction =
            tonumber(value)

        local info =
            GameConfig[animationId]

        if reaction
            and type(info) == "table" then

            reaction =
                math.clamp(
                    reaction,
                    0,
                    1
                )

            info.ReactionTime =
                reaction

            info.DefaultReactionTime =
                nil

            local slider =
                AnimationIdSliders
                and AnimationIdSliders[animationId]

            if slider and slider.Set then
                pcall(function()
                    slider:Set(reaction)
                end)
            end

            applied += 1
        else
            skipped += 1
        end
    end

    _G.__GakuranSharedConfigManager.ClearLearnedOffsets()

    _G.__GakuranSharedConfigManager.Notify(
        "Timing Config",
        string.format(
            "Loaded %s | %d applied, %d skipped",
            tostring(
                sourceName
                or config.Name
                or "shared config"
            ),
            applied,
            skipped
        )
    )

    return applied > 0
end

function _G.__GakuranSharedConfigManager.SanitizeName(value)
    local name =
        tostring(value or "")

    name =
        string.gsub(
            name,
            "^%s+",
            ""
        )

    name =
        string.gsub(
            name,
            "%s+$",
            ""
        )

    name =
        string.gsub(
            name,
            "[^%w%s%-%_]",
            "_"
        )

    name =
        string.gsub(
            name,
            "%s+",
            " "
        )

    if name == ""
        or string.lower(name) == "basic" then

        name = "Custom"
    end

    if #name > 48 then
        name =
            string.sub(
                name,
                1,
                48
            )
    end

    return name
end

function _G.__GakuranSharedConfigManager.EnsureFolder()
    if type(isfolder) == "function" then
        local ok, exists =
            pcall(
                isfolder,
                _G.__GakuranSharedConfigManager.Folder
            )

        if ok and exists then
            return true
        end
    end

    if type(makefolder) == "function" then
        local ok =
            pcall(
                makefolder,
                _G.__GakuranSharedConfigManager.Folder
            )

        if ok then
            return true
        end
    end

    -- Some executors create the folder implicitly after the first write.
    -- Return true when writefile exists so SaveNamed can still try.
    return type(writefile) == "function"
end

function _G.__GakuranSharedConfigManager.PathForName(value)
    local name =
        _G.__GakuranSharedConfigManager.SanitizeName(
            value
        )

    return
        _G.__GakuranSharedConfigManager.Folder
        .. "/"
        .. name
        .. ".lua"
end

function _G.__GakuranSharedConfigManager.ScanConfigNames()
    _G.__GakuranSharedConfigManager.EnsureFolder()

    local result = {
        "Basic",
    }

    local seen = {
        Basic = true,
    }

    if type(listfiles) ~= "function" then
        return result
    end

    local ok, files =
        pcall(
            listfiles,
            _G.__GakuranSharedConfigManager.Folder
        )

    if not ok
        or type(files) ~= "table" then

        return result
    end

    local custom = {}

    for _, path in ipairs(files) do
        path =
            tostring(path or "")

        path =
            string.gsub(
                path,
                "\\",
                "/"
            )

        local name =
            string.match(
                path,
                "([^/]+)%.lua$"
            )

        if name
            and name ~= ""
            and not seen[name] then

            seen[name] = true
            custom[#custom + 1] =
                name
        end
    end

    table.sort(
        custom,
        function(a, b)
            return string.lower(a)
                < string.lower(b)
        end
    )

    for _, name in ipairs(custom) do
        result[#result + 1] =
            name
    end

    return result
end

function _G.__GakuranSharedConfigManager.SerializeCurrent(configName)
    local safeName =
        _G.__GakuranSharedConfigManager.SanitizeName(
            configName
            or "Custom"
        )

    local lines = {
        "-- Gakuran shareable timing config",
        "-- Put this file inside the GakuranConfigs folder.",
        "-- The public script will automatically show it in the Config dropdown.",
        "",
        "return {",
        '    Format = "GakuranTimingConfig",',
        "    Version = 2,",
        "    Name = "
            .. string.format(
                "%q",
                safeName
            )
            .. ",",
        "    Timings = {",
    }

    local current =
        _G.__GakuranSharedConfigManager.CaptureTimings()

    for _, animationId
        in ipairs(
            _G.__GakuranSharedConfigManager.SortedAnimationIds()
        ) do

        local reaction =
            current[animationId]

        if reaction ~= nil then
            local info =
                GameConfig[animationId]
                or {}

            local style =
                tostring(
                    info.Style
                    or "Unknown"
                )

            local display =
                tostring(
                    info.DisplayName
                    or "Unknown"
                )

            style =
                string.gsub(
                    style,
                    "[\r\n]",
                    " "
                )

            display =
                string.gsub(
                    display,
                    "[\r\n]",
                    " "
                )

            lines[#lines + 1] =
                string.format(
                    '        ["%s"] = %.4f, -- %s | %s',
                    animationId,
                    reaction,
                    style,
                    display
                )
        end
    end

    lines[#lines + 1] =
        "    },"

    lines[#lines + 1] =
        "}"

    return table.concat(
        lines,
        "\n"
    )
end

function _G.__GakuranSharedConfigManager.LoadSource(source, sourceName)
    if type(source) ~= "string" then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Config source is invalid."
        )
        return false
    end

    local chunk, compileError =
        loadstring(source)

    if not chunk then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Config compile failed: "
                .. tostring(compileError)
        )
        return false
    end

    local previous =
        rawget(
            _G,
            "GAKURAN_SHARED_CONFIG"
        )

    local runOk, returned =
        pcall(chunk)

    local legacy =
        rawget(
            _G,
            "GAKURAN_SHARED_CONFIG"
        )

    _G.GAKURAN_SHARED_CONFIG =
        previous

    if not runOk then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Config runtime failed: "
                .. tostring(returned)
        )
        return false
    end

    local config =
        type(returned) == "table"
        and returned
        or legacy

    return _G.__GakuranSharedConfigManager.Apply(
        config,
        sourceName
    )
end

function _G.__GakuranSharedConfigManager.LoadNamed(configName)
    configName =
        tostring(
            configName
            or _G.__GakuranSharedConfigManager.Selected
            or "Basic"
        )

    if configName == "Basic" then
        _G.__GakuranSharedConfigManager.Selected =
            "Basic"

        if _G.__GakuranSharedConfigManager.Dropdown
            and _G.__GakuranSharedConfigManager.Dropdown.Set then

            pcall(function()
                _G.__GakuranSharedConfigManager.Dropdown:Set(
                    {"Basic"}
                )
            end)
        end

        return _G.__GakuranSharedConfigManager.ResetBasic()
    end

    if type(readfile) ~= "function"
        or type(isfile) ~= "function" then

        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "readfile/isfile unavailable."
        )
        return false
    end

    local path =
        _G.__GakuranSharedConfigManager.PathForName(
            configName
        )

    local existsOk, exists =
        pcall(
            isfile,
            path
        )

    if not existsOk
        or not exists then

        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Config file not found: "
                .. tostring(configName)
        )
        return false
    end

    local readOk, source =
        pcall(
            readfile,
            path
        )

    if not readOk then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Could not read "
                .. tostring(configName)
        )
        return false
    end

    local loaded =
        _G.__GakuranSharedConfigManager.LoadSource(
            source,
            configName
        )

    if loaded then
        _G.__GakuranSharedConfigManager.Selected =
            configName
    end

    return loaded
end

function _G.__GakuranSharedConfigManager.RefreshDropdown()
    local dropdown =
        _G.__GakuranSharedConfigManager.Dropdown

    if dropdown then
        if dropdown.Refresh then
            pcall(function()
                dropdown:Refresh()
            end)
        elseif dropdown.UpdateChoices then
            pcall(function()
                dropdown:UpdateChoices(
                    _G.__GakuranSharedConfigManager.ScanConfigNames()
                )
            end)
        end
    end

    return _G.__GakuranSharedConfigManager.ScanConfigNames()
end

function _G.__GakuranSharedConfigManager.SaveNamed(configName)
    if type(writefile) ~= "function" then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "writefile unavailable."
        )
        return false
    end

    if not _G.__GakuranSharedConfigManager.EnsureFolder() then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Could not create GakuranConfigs folder."
        )
        return false
    end

    local safeName =
        _G.__GakuranSharedConfigManager.SanitizeName(
            configName
            or _G.__GakuranSharedConfigManager.PendingName
            or "Custom"
        )

    local path =
        _G.__GakuranSharedConfigManager.PathForName(
            safeName
        )

    local source =
        _G.__GakuranSharedConfigManager.SerializeCurrent(
            safeName
        )

    local ok =
        pcall(
            writefile,
            path,
            source
        )

    if not ok then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Could not save "
                .. tostring(safeName)
        )
        return false
    end

    _G.__GakuranSharedConfigManager.Selected =
        safeName

    _G.__GakuranSharedConfigManager.PendingName =
        safeName

    _G.__GakuranSharedConfigManager.RefreshDropdown()

    if _G.__GakuranSharedConfigManager.Dropdown
        and _G.__GakuranSharedConfigManager.Dropdown.Set then

        pcall(function()
            _G.__GakuranSharedConfigManager.Dropdown:Set(
                {safeName}
            )
        end)
    end

    _G.__GakuranSharedConfigManager.Notify(
        "Timing Config",
        "Saved "
            .. safeName
            .. " to GakuranConfigs/"
    )

    return true
end

function _G.__GakuranSharedConfigManager.CopyCurrent(configName)
    if type(setclipboard) ~= "function" then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "setclipboard unavailable."
        )
        return false
    end

    local safeName =
        _G.__GakuranSharedConfigManager.SanitizeName(
            configName
            or _G.__GakuranSharedConfigManager.PendingName
            or "Custom"
        )

    local source =
        _G.__GakuranSharedConfigManager.SerializeCurrent(
            safeName
        )

    local ok =
        pcall(
            setclipboard,
            source
        )

    if ok then
        _G.__GakuranSharedConfigManager.Notify(
            "Timing Config",
            "Copied "
                .. safeName
                .. " config."
        )
    end

    return ok
end

function _G.__GakuranSharedConfigManager.DeleteNamed(configName)
    configName =
        tostring(
            configName
            or _G.__GakuranSharedConfigManager.Selected
            or "Basic"
        )

    if configName == "Basic" then
        _G.__GakuranSharedConfigManager.Notify(
            "Timing Config",
            "Basic cannot be deleted."
        )
        return false
    end

    if type(delfile) ~= "function" then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "delfile unavailable."
        )
        return false
    end

    local path =
        _G.__GakuranSharedConfigManager.PathForName(
            configName
        )

    local ok =
        pcall(
            delfile,
            path
        )

    if not ok then
        _G.__GakuranSharedConfigManager.Notify(
            "Config Error",
            "Could not delete "
                .. configName
        )
        return false
    end

    _G.__GakuranSharedConfigManager.Selected =
        "Basic"

    _G.__GakuranSharedConfigManager.RefreshDropdown()

    if _G.__GakuranSharedConfigManager.Dropdown
        and _G.__GakuranSharedConfigManager.Dropdown.Set then

        pcall(function()
            _G.__GakuranSharedConfigManager.Dropdown:Set(
                {"Basic"}
            )
        end)
    end

    _G.__GakuranSharedConfigManager.Notify(
        "Timing Config",
        "Deleted "
            .. configName
    )

    return true
end

function _G.__GakuranSharedConfigManager.ResetBasic()
    _G.__GakuranSharedConfigManager.CaptureBasic()

    _G.__GakuranSharedConfigManager.Selected =
        "Basic"

    return _G.__GakuranSharedConfigManager.Apply(
        {
            Name = "Basic",
            Timings =
                _G.__GakuranSharedConfigManager.BasicTimings,
        },
        "Basic"
    )
end

function _G.__GakuranSharedConfigManager.AutoLoad()
    local shared =
        rawget(
            _G,
            "GAKURAN_SHARED_CONFIG"
        )

    if type(shared) == "table" then
        _G.__GakuranSharedConfigManager.Apply(
            shared,
            shared.Name or "loader config"
        )
    end

    local requested =
        rawget(
            _G,
            "GAKURAN_CONFIG_NAME"
        )

    if requested ~= nil then
        _G.__GakuranSharedConfigManager.LoadNamed(
            requested
        )
    end
end

-- 5. Files Section
local function CreateFilesSection()
]==]_x=_o(_x,_la,_ma)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32)..string.char(99,111,110,102,105,103,32,102,111,108,100,101,114,32,104,101,108,112,101,114,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _na=[[    Files_Section:Button("Save Configuration", function()
        UI_Library:SaveConfig(GameName)
        UI_Library:Notify("Success", "Saved configuration")
    end)
end]]local _oa=[==[    Files_Section:Button("Save Configuration", function()
        UI_Library:SaveConfig(GameName)
        UI_Library:Notify("Success", "Saved configuration")
    end)

    Files_Section:Divider("Timing Configs")

    _G.__GakuranSharedConfigManager.NameBox =
        Files_Section:Textbox(
            "Config Name",
            "MyConfig",
            function(value)
                _G.__GakuranSharedConfigManager.PendingName =
                    tostring(value or "MyConfig")
            end
        )

    _G.__GakuranSharedConfigManager.Dropdown =
        Files_Section:Dropdown(
            "Config",
            {"Basic"},
            function()
                return _G.__GakuranSharedConfigManager.ScanConfigNames()
            end,
            false,
            function(list)
                _G.__GakuranSharedConfigManager.Selected =
                    list and list[1] or "Basic"
            end,
            "Reads .lua files from GakuranConfigs",
            true
        )

    Files_Section:Button(
        "Load Selected",
        function()
            _G.__GakuranSharedConfigManager.LoadNamed(
                _G.__GakuranSharedConfigManager.Selected
            )
        end
    )

    Files_Section:Button(
        "Save Current",
        function()
            _G.__GakuranSharedConfigManager.SaveNamed(
                _G.__GakuranSharedConfigManager.NameBox
                and _G.__GakuranSharedConfigManager.NameBox:Get()
                or _G.__GakuranSharedConfigManager.PendingName
            )
        end
    )

    Files_Section:Button(
        "Refresh Config List",
        function()
            _G.__GakuranSharedConfigManager.RefreshDropdown()
        end
    )

    Files_Section:Button(
        "Copy Current Config",
        function()
            _G.__GakuranSharedConfigManager.CopyCurrent(
                _G.__GakuranSharedConfigManager.NameBox
                and _G.__GakuranSharedConfigManager.NameBox:Get()
                or _G.__GakuranSharedConfigManager.PendingName
            )
        end
    )

    Files_Section:Button(
        "Delete Selected",
        function()
            _G.__GakuranSharedConfigManager.DeleteNamed(
                _G.__GakuranSharedConfigManager.Selected
            )
        end
    )

    Files_Section:Button(
        "Reset Basic Timings",
        function()
            _G.__GakuranSharedConfigManager.ResetBasic()

            if _G.__GakuranSharedConfigManager.Dropdown
                and _G.__GakuranSharedConfigManager.Dropdown.Set then

                _G.__GakuranSharedConfigManager.Dropdown:Set(
                    {"Basic"}
                )
            end
        end
    )

    Files_Section:Label(
        "Folder: GakuranConfigs | Drop shared .lua configs there, then Refresh."
    )
end]==]_x=_o(_x,_na,_oa)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32)..string.char(99,111,110,102,105,103,32,100,114,111,112,100,111,119,110,47,98,117,116,116,111,110,115,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end local _pa=[[InitializeUI()

UpdateClipboardSection()]]local _qa=[[InitializeUI()

_G.__GakuranSharedConfigManager.CaptureBasic()
_G.__GakuranSharedConfigManager.EnsureFolder()
_G.__GakuranSharedConfigManager.RefreshDropdown()
_G.__GakuranSharedConfigManager.AutoLoad()

UpdateClipboardSection()]]_x=_o(_x,_pa,_qa)if not _x then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,115,116,97,114,116,117,112,32,102,97,105,108,101,100,58,32)..string.char(99,111,110,102,105,103,32,105,110,105,116,32,109,97,114,107,101,114,32,99,104,97,110,103,101,100))return end print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,111,110,102,105,103,32,102,111,108,100,101,114,47,100,114,111,112,100,111,119,110,32,112,97,116,99,104,101,100,32,40,108,111,119,45,114,101,103,105,115,116,101,114,41))end local _ra=_x local _sa,_ta=loadstring(_ra)if not _sa then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,111,109,112,105,108,101,32,102,97,105,108,101,100,58,32)..tostring(_ta))return end if rawget(_G,string.char(95,95,71,97,107,117,114,97,110,67,111,109,98,105,110,101,100,67,111,109,112,105,108,101,79,110,108,121))==true then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,99,111,109,112,105,108,101,32,99,104,101,99,107,32,112,97,115,115,101,100))return end local _ua=rawget(_G,_c)if type(_ua)==string.char(116,97,98,108,101)and _ua.jobId==game.JobId then print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,97,108,114,101,97,100,121,32,108,111,97,100,101,100,32,105,110,32,116,104,105,115,32,77,97,116,99,104,97,32,115,101,115,115,105,111,110,59,32)..string.char(114,101,115,116,97,114,116,32,77,97,116,99,104,97,32,98,101,102,111,114,101,32,108,111,97,100,105,110,103,32,97,110,111,116,104,101,114,32,71,97,107,117,114,97,110,32,98,117,105,108,100))return end _G[_c]={jobId=game.JobId,version=string.char(118,55,46,50,46,52,45,112,117,98,108,105,99,45,99,111,110,102,105,103,45,102,111,108,100,101,114,45,100,114,111,112,100,111,119,110,45,108,111,119,114,101,103,45,115,116,114,105,107,101,114,45,99,117,114,118,101,45,119,105,110,103,99,104,117,110,45,114,101,118,101,114,116,45,115,110,97,112,45,104,111,116,107,101,121,45,99,97,112,111,101,105,114,97,45,104,101,97,118,121,102,105,120),}local _va,_wa=pcall(_sa)if not _va then _G[_c]=nil print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,114,117,110,116,105,109,101,32,102,97,105,108,101,100,58,32)..tostring(_wa))return end print(string.char(91,71,97,107,117,114,97,110,32,65,80,32,83,104,97,114,101,93,32,108,111,97,100,101,100,32,118,55,46,50,46,52,32,112,117,98,108,105,99,32,43,32,99,111,110,102,105,103,32,102,111,108,100,101,114,47,100,114,111,112,100,111,119,110))
