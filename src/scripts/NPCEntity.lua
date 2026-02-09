-- =========================================================
-- TODO / FUTURE VISION - NPC Visual & Entity System
-- =========================================================
-- [x] 3D model loading via g_i3DManager (shared i3d, clone, delete)
-- [x] Per-NPC color tinting via colorScale shader parameter
-- [x] Debug node fallback when models are unavailable (text above head)
-- [ ] Map hotspots via MapHotspot API (code exists but hotspots do not appear in-game)
-- [x] LOD-based batch updates (closer NPCs update more frequently)
-- [x] Visibility culling based on player distance (maxVisibleDistance)
-- [x] Deterministic appearance generation (scale, color) via appearanceSeed
-- [x] Animation state tracking (idle, walk, work, drive, talk, rest)
-- [x] Animation speed modulation based on movement/AI state
-- [ ] Actual character animations (walk cycle, work gesture, talk, rest)
--     - Currently tracks currentAnimation and animationSpeed but doesn't play animations
--     - Need AnimatedObject integration or custom animation controller
-- [ ] Multiple NPC appearance variants (elderly/child)
--     - Model selection based on npc.age, npc.profession
-- [ ] Clothing/accessory variation (hat, overalls, boots, etc.)
--     - Shader-based clothing color variation (workwear vs casual)
--     - Detachable accessories (hat, tool belt, clipboard)
-- [ ] Shadow casting for NPC models
--     - setVisibility() called but no castsShadows flag set on nodes
--     - Need to enable shadow casting on model load for realistic lighting
-- [ ] NPC collision with player/vehicles
--     - Currently setRigidBodyType(NONE) → visual-only, no physics
--     - Need kinematic or dynamic rigid bodies for pushback
--     - Collision callbacks to detect player/vehicle contact
-- [ ] Facial expressions or emoji bubbles above NPC heads
--     - Happy/angry/confused icons based on relationship/interaction state
--     - Speech bubbles during conversations
--     - Thought bubbles when idle
-- [ ] Tractor visual prop (code exists but models don't load from game pak archives)
--     - loadTractorProp() falls back to invisible placeholder transform group
--     - showTractorProp()/updateWorkingVisuals() exist but no visible tractor appears
-- [ ] Vehicle commuting prop (code exists but models don't load from game pak archives)
--     - loadVehicleProp() falls back to invisible placeholder transform group
--     - showVehicleProp()/parkVehicle() exist but no visible vehicle appears
-- [ ] Vehicle visual attachment (NPC seated in tractor when driving)
--     - aiState == "driving" tracked but NPC not visually placed in vehicle
--     - Need to link entity.node to vehicle seat node
--     - Dismount/mount animations on state change
-- [ ] Footstep audio triggered by walk animation
--     - Sample audio based on terrain type (dirt, concrete, grass)
-- [ ] Smooth rotation interpolation
--     - Currently setRotation(0, yaw, 0) is instant snap
--     - Lerp toward target yaw over time for natural turning
-- [ ] Smooth position interpolation
--     - Currently setTranslation(x, y, z) is instant teleport
--     - Lerp toward target position to smooth out network jitter (MP)
-- [ ] Per-NPC equipment/tool rendering
--     - Attach wrench, rake, clipboard to hand bones based on currentAction
-- [x] Height variation reflected in model scale
--     - entity.height calculated and applied as Y-axis scale modifier
--     - Per-NPC height variation (0.95-1.05) for visual differentiation
-- [ ] Seasonal clothing variation
--     - Winter coat when environment.currentSeason == "winter"
--     - Sunhat in summer, raincoat in rain
-- [x] NPC name tag rendering (world-to-screen projected text above head)
--     - Personality-colored names visible within 15m with distance fade
--     - Mood indicator icons below name tag
-- [ ] Interaction highlight (outline/glow when canInteract == true)
--     - Visual feedback that NPC is interactable (within range)
-- [x] Walking on terrain (Y position adjustment)
--     - Terrain height clamping safety net in updateNPCEntity()
--     - Snaps entity Y to getTerrainHeightAtWorldPos() every frame
--     - Prevents floating/sinking regardless of AI movement code
-- [ ] AI state transition animations
--     - Blend from "walk" to "idle" over 0.5s instead of instant swap
-- [ ] Performance: Occlusion culling
--     - Currently only distance-based visibility
--     - Check if NPC behind buildings/terrain before rendering
-- [ ] Performance: Imposter rendering for distant NPCs
--     - Beyond 150m, render as 2D billboard instead of 3D model
-- =========================================================

-- =========================================================
-- FS25 NPC Favor Mod - NPC Entity Management
-- =========================================================
-- Visual representation layer for NPCs. Manages:
--   - 3D model loading via g_i3DManager (shared i3d, clone, delete)
--   - Per-NPC color tinting via colorScale shader parameter
--   - Debug node fallback when models are unavailable
--   - Map hotspots via FS25 MapHotspot API
--   - LOD-based batch updates (closer NPCs update more frequently)
--   - Visibility culling based on player distance
--
-- Lifecycle: initialize() → createNPCEntity() per NPC → updateNPCEntity() per frame
--            → removeNPCEntity() on despawn → cleanupStaleEntities() periodically
-- =========================================================

NPCEntity = {}
NPCEntity_mt = Class(NPCEntity)

-- Y offset to align model feet with terrain surface.
-- Adjust this value if NPCs float above or sink below the ground.
-- Negative = push model down, Positive = push model up.
NPCEntity.MODEL_Y_OFFSET = 0.0

-- Whether to attempt HumanGraphicsComponent-based animated characters.
-- Falls back to a debug cube placeholder if this fails.
NPCEntity.USE_ANIMATED_CHARACTERS = true

--- Create a new NPCEntity manager.
-- @param npcSystem  NPCSystem reference (provides settings, activeNPCs)
-- @return NPCEntity instance
function NPCEntity.new(npcSystem)
    local self = setmetatable({}, NPCEntity_mt)

    self.npcSystem = npcSystem       -- Back-reference to parent system
    self.npcEntities = {}            -- Map of NPC ID → entity data table
    self.nextEntityId = 1            -- Auto-incrementing entity ID counter

    -- Animated character system
    self.animatedCharacterAvailable = false  -- True if HumanGraphicsComponent works
    self.animatedCharacterTested = false     -- True once we've tested the API

    -- Performance: batch updates to avoid processing all NPCs every frame
    self.maxVisibleDistance = 200     -- NPCs beyond this are hidden
    self.updateBatchSize = 5         -- Max entities updated per batchUpdate() call
    self.lastBatchIndex = 0          -- Rolling index for round-robin batching

    return self
end

--- Initialize NPC entity system
-- @param modDirectory The mod's directory path (with trailing slash)
function NPCEntity:initialize(modDirectory)
    if not modDirectory then return end

    -- Test animated character system availability
    if self.USE_ANIMATED_CHARACTERS then
        self:testAnimatedCharacterAPI()
    end

    print("[NPCEntity] Animated character API test: " .. tostring(self.animatedCharacterAvailable))
end

--- Test if the HumanGraphicsComponent API is available for animated characters.
-- This checks that all required classes and methods exist before we try to use them.
function NPCEntity:testAnimatedCharacterAPI()
    if self.animatedCharacterTested then return end
    self.animatedCharacterTested = true

    local ok = pcall(function()
        -- Check all required classes exist
        if not HumanGraphicsComponent then return end
        if not HumanGraphicsComponent.new then return end
        if not PlayerStyle then return end
        if not HumanModelLoadingState then return end

        -- Check PlayerStyle has defaultStyle or new
        if not PlayerStyle.defaultStyle and not PlayerStyle.new then return end

        -- All checks passed
        self.animatedCharacterAvailable = true
    end)

    if not ok then
        self.animatedCharacterAvailable = false
    end

    print("[NPCEntity] Animated character API test: " .. tostring(self.animatedCharacterAvailable))
end

--- Create a visual entity for an NPC: 3D model (or debug fallback) + map icon.
-- Seeds math.random with npc.appearanceSeed for deterministic appearance generation
-- (scale, color), then re-seeds with game time afterward to restore randomness.
-- @param npc  NPC data table (requires .id, .position, .rotation)
-- @return boolean  true if entity created successfully
function NPCEntity:createNPCEntity(npc)
    if not npc or not npc.position then
        print("NPCEntity: ERROR - Invalid NPC data")
        return false
    end

    local entityId = self.nextEntityId
    self.nextEntityId = self.nextEntityId + 1

    -- Seed RNG for deterministic appearance (scale, color) — restored after entity creation
    local appearanceSeed = npc.appearanceSeed or math.random(1, 1000)
    math.randomseed(appearanceSeed)

    local currentTime = (g_currentMission and g_currentMission.time) or 0

    local entity = {
        id = entityId,
        npcId = npc.id,
        node = nil,
        position = {
            x = npc.position.x,
            y = npc.position.y,
            z = npc.position.z
        },
        rotation = {
            x = npc.rotation.x or 0,
            y = npc.rotation.y or 0,
            z = npc.rotation.z or 0
        },
        scale = 0.95 + math.random() * 0.1,
        model = npc.model or "farmer",
        primaryColor = {
            r = 0.3 + math.random() * 0.5,
            g = 0.3 + math.random() * 0.5,
            b = 0.3 + math.random() * 0.5
        },
        collisionRadius = 0.5,
        height = 1.7 + math.random() * 0.2,
        heightScale = npc.heightScale or (0.95 + math.random() * 0.1),
        currentAnimation = "idle",
        animationSpeed = 1.0,
        animationState = "playing",
        isVisible = true,
        needsUpdate = true,
        lastUpdateTime = currentTime,
        updatePriority = 1,
        debugNode = nil,
        debugText = nil,
        mapHotspot = nil
    }

    -- Load animated character using game-native HumanModel system.
    -- Priority: 1) Direct HumanModel+cloneAnimCharacterSet (VehicleCharacter pattern)
    --           2) HumanGraphicsComponent (high-level ConditionalAnimation)
    local modelLoaded = false

    if self.animatedCharacterAvailable then
        -- Primary: VehicleCharacter pattern (most proven, game-native)
        modelLoaded = self:loadAnimatedCharacterDirect(entity, npc)

        -- Secondary: HumanGraphicsComponent wrapper
        if not modelLoaded then
            modelLoaded = self:loadAnimatedCharacter(entity, npc)
        end
    end

    -- Fallback to debug representation if animated model failed
    if not modelLoaded then
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            self:createDebugRepresentation(entity)
        end
    end

    -- Load tractor visual prop for farmer NPCs (hidden until NPC enters working state)
    local isFarmer = (npc.profession == "farmer" or entity.model == "farmer" or npc.assignedField ~= nil)
    if isFarmer then
        self:loadTractorProp(entity)
    end

    -- Load vehicle commuting prop (car/pickup for all NPCs; hidden until driving)
    self:loadVehicleProp(entity)

    self.npcEntities[npc.id] = entity
    npc.entityId = entityId

    self:createMapHotspot(entity, npc)

    -- Restore RNG to non-deterministic state (prevents other systems from
    -- getting the same sequence of random numbers for every NPC)
    math.randomseed((g_currentMission and g_currentMission.time) or 12345)

    return true
end

--- Load an animated character using HumanGraphicsComponent.
-- This creates a fully animated human NPC with walk/idle/run blending
-- using the game's built-in character animation system.
-- @param entity The entity data table
-- @param npc    NPC data table (for appearance seed, gender, etc.)
-- @return true if animated character loaded successfully
function NPCEntity:loadAnimatedCharacter(entity, npc)
    local debug = self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode

    local success = false
    local ok, err = pcall(function()
        -- Create the HumanGraphicsComponent
        local gfx = HumanGraphicsComponent.new()
        gfx:initialize()

        if not gfx.graphicsRootNode or gfx.graphicsRootNode == 0 then
            print("[NPCEntity] ANIMATED: graphicsRootNode creation failed")
            return
        end

        -- Position the graphics root node
        setTranslation(gfx.graphicsRootNode,
            entity.position.x, entity.position.y, entity.position.z)
        setRotation(gfx.graphicsRootNode, 0, entity.rotation.y, 0)

        -- Set animation parameters for NPC behavior
        if gfx.animationParameters then
            if gfx.animationParameters.isNPC then
                gfx.animationParameters.isNPC:setValue(true)
            end
            if gfx.animationParameters.isGrounded then
                gfx.animationParameters.isGrounded:setValue(true)
            end
            if gfx.animationParameters.isCloseToGround then
                gfx.animationParameters.isCloseToGround:setValue(true)
            end
            if gfx.animationParameters.isIdling then
                gfx.animationParameters.isIdling:setValue(true)
            end
        end

        -- Create a style for this NPC
        local style = nil

        -- Try PlayerStyle.defaultStyle() first
        if PlayerStyle.defaultStyle then
            local okStyle
            okStyle, style = pcall(PlayerStyle.defaultStyle)
            if not okStyle then style = nil end
        end

        -- Fallback: create a new PlayerStyle manually
        if not style then
            style = PlayerStyle.new()
        end

        -- Choose male or female model based on NPC's appearance seed
        -- Uses exact paths from game's pedestrianSystem.xml
        local isFemale = npc.isFemale or false
        local xmlFilename = nil
        if isFemale then
            xmlFilename = "dataS/character/playerF/playerF.xml"
        else
            xmlFilename = "dataS/character/playerM/playerM.xml"
        end

        -- Try to set the xmlFilename on the style
        pcall(function()
            if style.xmlFilename ~= nil or style.setXmlFilename then
                style.xmlFilename = xmlFilename
            end
        end)

        -- Try to load configuration from XML
        pcall(function()
            if style.loadConfigurationXML then
                style:loadConfigurationXML(xmlFilename)
            end
        end)

        -- Store references on the entity
        entity.graphicsComponent = gfx
        entity.node = gfx.graphicsRootNode
        entity.isAnimatedCharacter = true

        -- Async model load via setStyleAsync
        if gfx.setStyleAsync then
            gfx:setStyleAsync(style, function(target, loadingState, loadedNewModel, args)
                local loaded = (loadingState == HumanModelLoadingState.OK)
                if debug then
                    print(string.format("[NPCEntity] ANIMATED: setStyleAsync callback - state=%s loaded=%s entity=%d",
                        tostring(loadingState), tostring(loaded), entity.id))
                end
                if loaded then
                    entity.animatedModelLoaded = true
                    pcall(function()
                        gfx:setModelVisibility(true)
                    end)
                else
                    entity.animatedModelLoaded = false
                    -- Model failed to load async — will be handled on next update
                    print("[NPCEntity] ANIMATED: Model failed to load for entity " .. entity.id)
                end
            end, self, nil, false, nil, false)
        end

        success = true
        if debug then
            print(string.format("[NPCEntity] ANIMATED: HumanGraphicsComponent created for entity #%d (gfxRoot=%s)",
                entity.id, tostring(gfx.graphicsRootNode)))
        end
    end)

    if not ok then
        print("[NPCEntity] ANIMATED: Exception during loadAnimatedCharacter: " .. tostring(err))
        -- Clean up partial state
        if entity.graphicsComponent then
            pcall(function() entity.graphicsComponent:delete() end)
            entity.graphicsComponent = nil
        end
        entity.isAnimatedCharacter = false
        return false
    end

    if success then
        print(string.format("[NPCEntity] ANIMATED: Character creation initiated for entity #%d", entity.id))
    end
    return success
end

--- Fallback: Load animated character using direct HumanModel + cloneAnimCharacterSet.
-- Uses the VehicleCharacter pattern from the game engine.
-- This is tried if HumanGraphicsComponent approach fails.
-- @param entity The entity data table
-- @param npc    NPC data table
-- @return true if model loaded successfully
--- Outfit presets extracted from the game's pedestrianSystem.xml.
-- Each preset is a table of {slot = {name, color}} pairs.
-- Male presets use playerM.xml, female presets use playerF.xml.
NPCEntity.MALE_OUTFITS = {
    { -- Male 01A: denim jacket farmer (light skin)
        face = {name = "head01", color = 1}, bottom = {name = "jeans", color = 5},
        top = {name = "denimJacket", color = 1}, footwear = {name = "workBoots1", color = 1},
        hairStyle = {name = "hair06", color = 18}, beard = {name = "stubble_head01", color = 18}
    },
    { -- Male 01C: t-shirt casual (medium skin)
        face = {name = "head01", color = 2}, bottom = {name = "cargo", color = 2},
        top = {name = "tShirt01", color = 27}, footwear = {name = "eltenMaddoxLowYellow", color = 1},
        hairStyle = {name = "hair08", color = 5}, beard = {name = "horseshoe_head01", color = 5}
    },
    { -- Male 02A: mechanic overalls (olive skin)
        face = {name = "head02", color = 3}, onepiece = {name = "mechanic", color = 2},
        footwear = {name = "riding", color = 1},
        hairStyle = {name = "hair12", color = 2}, beard = {name = "goatee01_head02", color = 2}
    },
    { -- Male 02B: synthetic overalls (light skin)
        face = {name = "head02", color = 1}, onepiece = {name = "synthetic", color = 4},
        footwear = {name = "workBoots1", color = 1},
        hairStyle = {name = "hair13", color = 24}, beard = {name = "walrusXL_head02", color = 24}
    },
    { -- Male 02C: collared shirt office (dark skin)
        face = {name = "head02", color = 4}, bottom = {name = "chinos", color = 4},
        top = {name = "collaredShirt", color = 1}, glasses = {name = "reading", color = 1},
        footwear = {name = "chelsea02", color = 1},
        hairStyle = {name = "hair12", color = 16}, beard = {name = "trimmedBeard_head02", color = 16}
    },
    { -- Male 04: vest rugged (tanned skin)
        face = {name = "head04", color = 2}, bottom = {name = "leather", color = 4},
        top = {name = "topVest", color = 1}, footwear = {name = "workBoots2", color = 3},
        hairStyle = {name = "hair04", color = 18}
    },
    { -- Male 05: pullover casual (medium skin)
        face = {name = "head05", color = 3}, bottom = {name = "jeans", color = 9},
        top = {name = "zipNeckPullover", color = 68}, footwear = {name = "sneakers", color = 9},
        hairStyle = {name = "hair05", color = 16}, beard = {name = "goatee02_head05", color = 16}
    }
}

NPCEntity.FEMALE_OUTFITS = {
    { -- Female 01B: glasses pullover (light skin)
        face = {name = "head01", color = 1}, bottom = {name = "jeans", color = 8},
        top = {name = "zipNeckPullover", color = 22}, glasses = {name = "classic", color = 1},
        footwear = {name = "sneakers", color = 9}, hairStyle = {name = "hair12", color = 12}
    },
    { -- Female 01C: farm jacket (medium skin)
        face = {name = "head01", color = 2}, bottom = {name = "chinos", color = 2},
        top = {name = "topFarmJacketM", color = 2}, footwear = {name = "chelsea01", color = 1},
        hairStyle = {name = "hair03", color = 6}
    },
    { -- Female 02A: tank top sporty (dark skin)
        face = {name = "head02", color = 4}, bottom = {name = "botSlacks", color = 36},
        top = {name = "tankTop", color = 1}, footwear = {name = "sportSneakers", color = 8},
        hairStyle = {name = "hair16", color = 2}
    },
    { -- Female 02B: windbreaker shorts (olive skin)
        face = {name = "head02", color = 3}, bottom = {name = "jeanShorts", color = 5},
        top = {name = "windbreaker", color = 9}, footwear = {name = "laceUpSneaker", color = 1},
        hairStyle = {name = "hair10", color = 15}
    },
    { -- Female 04A: aviator jacket (tanned skin)
        face = {name = "head04", color = 2}, bottom = {name = "chinos", color = 3},
        top = {name = "aviatorJacket", color = 4}, footwear = {name = "laceUpSneaker", color = 1},
        hairStyle = {name = "hair06", color = 18}
    },
    { -- Female 06A: long sleeve shirt (light skin)
        face = {name = "head06", color = 1}, bottom = {name = "chinos", color = 7},
        top = {name = "topShirtLongSleeve", color = 12}, footwear = {name = "sneakers", color = 68},
        hairStyle = {name = "hair13", color = 18}
    }
}

function NPCEntity:loadAnimatedCharacterDirect(entity, npc)
    local debug = self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode

    print("[NPCEntity] DIRECT: Attempting for entity #" .. tostring(entity.id))

    local success = false
    local ok, err = pcall(function()
        if not HumanModel or not HumanModel.new then
            print("[NPCEntity] DIRECT: HumanModel or HumanModel.new not available")
            return
        end
        if not g_animCache or not AnimationCache then
            print("[NPCEntity] DIRECT: g_animCache or AnimationCache not available")
            return
        end

        local isFemale = npc.isFemale or false
        local xmlFilename = isFemale and "dataS/character/playerF/playerF.xml" or "dataS/character/playerM/playerM.xml"

        -- Create HumanModel and load from player XML
        local humanModel = HumanModel.new()

        print("[NPCEntity] DIRECT: Loading HumanModel from " .. xmlFilename .. " for entity #" .. entity.id)

        -- isRealPlayer=false, isOwner=false, isAnimated=true
        humanModel:load(xmlFilename, false, false, true,
            function(target, loadingState, args)
                print("[NPCEntity] DIRECT: HumanModel callback, state=" .. tostring(loadingState))

                if loadingState ~= HumanModelLoadingState.OK then
                    print("[NPCEntity] DIRECT: HumanModel load FAILED, state=" .. tostring(loadingState))
                    return
                end

                print("[NPCEntity] DIRECT: HumanModel loaded OK, rootNode=" .. tostring(humanModel.rootNode)
                    .. " skeleton=" .. tostring(humanModel.skeleton))

                -- Link to scene graph
                pcall(function()
                    link(getRootNode(), humanModel.rootNode)
                    setTranslation(humanModel.rootNode,
                        entity.position.x, entity.position.y, entity.position.z)
                    setRotation(humanModel.rootNode, 0, entity.rotation.y, 0)
                    -- Apply per-NPC height variation (0.95-1.05)
                    local hs = entity.heightScale or 1.0
                    setScale(humanModel.rootNode, 1, hs, 1)
                end)

                -- Clone animations from the animation cache onto our skeleton
                if humanModel.skeleton and humanModel.skeleton ~= 0 then
                    pcall(function()
                        local animNode = g_animCache:getNode(AnimationCache.CHARACTER)
                        if animNode and animNode ~= 0 then
                            cloneAnimCharacterSet(getChildAt(animNode, 0), humanModel.skeleton)
                            if debug then
                                print("[NPCEntity] DIRECT: cloneAnimCharacterSet succeeded")
                            end
                        end
                    end)

                    -- Set up animation playback
                    local charSet = nil
                    pcall(function()
                        charSet = getAnimCharacterSet(humanModel.skeleton)
                        if charSet == 0 then
                            -- Try first child of skeleton
                            charSet = getAnimCharacterSet(getChildAt(humanModel.skeleton, 0))
                        end
                    end)

                    if charSet and charSet ~= 0 then
                        if debug then
                            local numClips = getAnimNumOfClips(charSet)
                            print("[NPCEntity] DIRECT: charSet=" .. tostring(charSet) .. " clips=" .. tostring(numClips))
                        end

                        -- Helper: find first matching clip from a list of names
                        local function findClip(cs, names)
                            for _, name in ipairs(names) do
                                local okIdx, idx = pcall(function() return getAnimClipIndex(cs, name) end)
                                if okIdx and idx and idx >= 0 then
                                    return idx, name
                                end
                            end
                            return -1, nil
                        end

                        -- Try multiple clip names (NPC-specific first, then standard player clips)
                        local idleCandidates = isFemale
                            and {"idle1FemaleSource", "idle1Source", "idle2FemaleSource", "idle2Source", "idleSource"}
                            or  {"idle1Source", "idle2Source", "idleSource", "idle1FemaleSource"}
                        local walkCandidates = isFemale
                            and {"NPCWalkFemale01Source", "walkSource", "walk1Source", "walkFemaleSource", "runSource"}
                            or  {"NPCWalkMale01Source", "walkSource", "walk1Source", "runSource"}

                        -- Assign idle animation to track 0 (enabled — NPC starts idle)
                        -- Pattern: clearAnimTrackClip → assignAnimTrackClip → loop → enable
                        -- (matches VehicleCharacter.lua — no setAnimTrackSpeedScale needed,
                        --  engine auto-advances enabled tracks)
                        pcall(function()
                            local idleClip, idleName = findClip(charSet, idleCandidates)
                            if idleClip >= 0 then
                                clearAnimTrackClip(charSet, 0)
                                assignAnimTrackClip(charSet, 0, idleClip)
                                setAnimTrackLoopState(charSet, 0, true)
                                enableAnimTrack(charSet, 0)
                                entity.idleClipName = idleName
                                print("[NPCEntity] Idle clip: '" .. idleName .. "' (idx=" .. idleClip .. ")")
                            else
                                print("[NPCEntity] WARNING: No idle clip found for entity #" .. entity.id)
                            end
                        end)

                        -- Assign walk animation to track 1 (disabled initially — enabled when walking)
                        pcall(function()
                            local walkClip, walkName = findClip(charSet, walkCandidates)
                            if walkClip >= 0 then
                                clearAnimTrackClip(charSet, 1)
                                assignAnimTrackClip(charSet, 1, walkClip)
                                setAnimTrackLoopState(charSet, 1, true)
                                disableAnimTrack(charSet, 1)
                                entity.walkClipName = walkName
                                print("[NPCEntity] Walk clip: '" .. walkName .. "' (idx=" .. walkClip .. ")")
                            else
                                -- Last resort: try ANY clip that has "walk" or "run" in the name
                                local numClips = getAnimNumOfClips(charSet)
                                for ci = 0, numClips - 1 do
                                    local okCN, cn = pcall(function() return getAnimClipName(charSet, ci) end)
                                    if okCN and cn then
                                        local lower = cn:lower()
                                        if lower:find("walk") or lower:find("run") or lower:find("locomot") then
                                            clearAnimTrackClip(charSet, 1)
                                            assignAnimTrackClip(charSet, 1, ci)
                                            setAnimTrackLoopState(charSet, 1, true)
                                            disableAnimTrack(charSet, 1)
                                            entity.walkClipName = cn
                                            print("[NPCEntity] Walk clip (fuzzy match): '" .. cn .. "' (idx=" .. ci .. ")")
                                            return
                                        end
                                    end
                                end
                                print("[NPCEntity] WARNING: No walk clip found for entity #" .. entity.id
                                    .. " (tried " .. #walkCandidates .. " names + fuzzy search of " .. numClips .. " clips)")
                            end
                        end)

                        entity.animCharSet = charSet
                        entity.isFemale = isFemale
                        entity.lastWalkState = false  -- Starts idle (track 0 enabled, track 1 disabled)
                    end
                end

                -- Load appearance style (clothing) with variation per NPC
                pcall(function()
                    if humanModel.loadFromStyleAsync then
                        -- Start with defaultStyle as base
                        local style = nil
                        if PlayerStyle.defaultStyle then
                            local okDS, ds = pcall(PlayerStyle.defaultStyle)
                            if okDS and ds then style = ds end
                        end
                        if not style then
                            style = PlayerStyle.new()
                        end

                        -- Ensure the style knows which model XML to use
                        pcall(function() style.xmlFilename = xmlFilename end)

                        -- Try loading the configuration (available items)
                        pcall(function()
                            if style.loadConfigurationIfRequired then
                                style:loadConfigurationIfRequired()
                            elseif style.loadConfigurationXML then
                                style:loadConfigurationXML(xmlFilename)
                            end
                        end)

                        -- =====================================================
                        -- DEEP DIAGNOSTIC: style.configs inner structure
                        -- =====================================================
                        if entity.id <= 2 then
                            print("[NPCEntity] ========== STYLE DUMP for entity #" .. entity.id .. " ==========")

                            -- Dump top-level style keys (type only, not full contents)
                            for k, v in pairs(style) do
                                if type(v) == "table" then
                                    local count = 0
                                    for _ in pairs(v) do count = count + 1 end
                                    print("  style." .. tostring(k) .. " = table(" .. count .. " entries)")
                                else
                                    print("  style." .. tostring(k) .. " = " .. tostring(v) .. " (" .. type(v) .. ")")
                                end
                            end

                            -- Deep dump: style.configs["face"] inner structure
                            if style.configs and type(style.configs) == "table" then
                                local faceConfig = style.configs["face"]
                                if faceConfig then
                                    print("[NPCEntity] DEEP DUMP: style.configs['face'] structure:")
                                    for ck, cv in pairs(faceConfig) do
                                        if type(cv) == "table" then
                                            local subCount = 0
                                            for _ in pairs(cv) do subCount = subCount + 1 end
                                            print("  face." .. tostring(ck) .. " = table(" .. subCount .. " entries)")
                                            -- If it looks like a list of items, dump first 2
                                            local idx = 0
                                            for ik, iv in pairs(cv) do
                                                if idx < 2 then
                                                    if type(iv) == "table" then
                                                        local itemStr = ""
                                                        for iik, iiv in pairs(iv) do
                                                            itemStr = itemStr .. tostring(iik) .. "=" .. tostring(iiv) .. " "
                                                        end
                                                        print("    face." .. tostring(ck) .. "[" .. tostring(ik) .. "] = {" .. itemStr .. "}")
                                                    else
                                                        print("    face." .. tostring(ck) .. "[" .. tostring(ik) .. "] = " .. tostring(iv) .. " (" .. type(iv) .. ")")
                                                    end
                                                end
                                                idx = idx + 1
                                            end
                                        else
                                            print("  face." .. tostring(ck) .. " = " .. tostring(cv) .. " (" .. type(cv) .. ")")
                                        end
                                    end
                                else
                                    print("[NPCEntity] DEEP DUMP: style.configs['face'] is nil!")
                                end
                            else
                                print("[NPCEntity] DEEP DUMP: style.configs is nil or not a table!")
                            end

                            -- Dump what getPresetByName returns
                            if style.getPresetByName then
                                print("[NPCEntity] PRESET DUMP: style:getPresetByName('cropsFarmer'):")
                                local okPreset, presetResult = pcall(function()
                                    return style:getPresetByName("cropsFarmer")
                                end)
                                if okPreset and presetResult then
                                    print("  preset type = " .. type(presetResult))
                                    if type(presetResult) == "table" then
                                        for pk, pv in pairs(presetResult) do
                                            if type(pv) == "table" then
                                                local subStr = ""
                                                for spk, spv in pairs(pv) do
                                                    subStr = subStr .. tostring(spk) .. "=" .. tostring(spv) .. " "
                                                end
                                                print("  preset." .. tostring(pk) .. " = {" .. subStr .. "}")
                                            else
                                                print("  preset." .. tostring(pk) .. " = " .. tostring(pv) .. " (" .. type(pv) .. ")")
                                            end
                                        end
                                        -- Check preset metatable
                                        local pmt = getmetatable(presetResult)
                                        if pmt then
                                            print("  preset has metatable with keys:")
                                            for pmk, pmv in pairs(pmt) do
                                                print("    mt." .. tostring(pmk) .. " = " .. type(pmv))
                                            end
                                            if pmt.__index and type(pmt.__index) == "table" then
                                                for pmk, pmv in pairs(pmt.__index) do
                                                    print("    __index." .. tostring(pmk) .. " = " .. type(pmv))
                                                end
                                            end
                                        end
                                    end
                                elseif okPreset then
                                    print("  preset returned nil")
                                else
                                    print("  preset call FAILED: " .. tostring(presetResult))
                                end
                            else
                                print("[NPCEntity] PRESET DUMP: style.getPresetByName method not found!")
                            end

                            print("[NPCEntity] ========== END STYLE DUMP ==========")
                        end

                        -- =====================================================
                        -- APPROACH A: Apply a named preset from the game
                        -- Presets reference playerM.xml meshes, so applyToStyle overrides
                        -- female models with male meshes. Only apply presets to MALE NPCs.
                        -- Female NPCs use their default appearance (the engine loads appropriate
                        -- female clothing from playerF.xml automatically).
                        -- =====================================================
                        local PRESET_POOL = {
                            "cropsFarmer", "mechanic", "forestry", "rancher",
                            "livestockFarmer", "longHaulTrucker", "wetwork",
                            "beekeeper", "horsebackRider", "DefaultClothes",
                        }
                        -- Use entity.id directly for guaranteed variety (1,2,3... maps to different presets)
                        local presetIndex = ((entity.id - 1) % #PRESET_POOL) + 1
                        local presetName = PRESET_POOL[presetIndex]
                        local presetApplied = false

                        -- Only apply presets to MALE NPCs — presets reference playerM meshes
                        -- and override female models with male body parts.
                        -- Female NPCs use their default playerF appearance (engine assigns
                        -- appropriate feminine clothing automatically from playerF.xml).
                        if not isFemale and style.getPresetByName then
                            local okP, preset = pcall(function()
                                return style:getPresetByName(presetName)
                            end)
                            if okP and preset then
                                print("[NPCEntity] APPROACH A: Got preset '" .. presetName .. "' for MALE entity #" .. entity.id)
                                local okApply = pcall(function()
                                    if preset.applyToStyle then
                                        preset:applyToStyle(style)
                                        presetApplied = true
                                        print("[NPCEntity] APPROACH A: preset:applyToStyle succeeded")
                                    end
                                end)
                                if not presetApplied then
                                    pcall(function()
                                        if style.copySelectionFrom then
                                            style:copySelectionFrom(preset)
                                            presetApplied = true
                                            print("[NPCEntity] APPROACH A: copySelectionFrom succeeded")
                                        end
                                    end)
                                end
                                if not presetApplied then
                                    print("[NPCEntity] APPROACH A: preset obtained but no apply method worked")
                                end
                            end
                        elseif isFemale then
                            -- Female NPC: randomize config selections for variety.
                            -- Can't use male presets (they load male meshes), so we directly
                            -- randomize selectedItemIndex and selectedColorIndex on each config slot.
                            if style.configs and type(style.configs) == "table" then
                                local rng = entity.id * 7 + 3  -- deterministic seed per entity
                                local slotsChanged = 0
                                for slotName, config in pairs(style.configs) do
                                    pcall(function()
                                        if config.items and #config.items > 1 then
                                            -- Randomize item selection
                                            local itemIdx = (rng % #config.items) + 1
                                            config.selectedItemIndex = itemIdx
                                            rng = rng * 13 + 7  -- advance deterministic RNG
                                            slotsChanged = slotsChanged + 1
                                        end
                                        -- Randomize color if items have color options
                                        if config.items and config.selectedItemIndex then
                                            local item = config.items[config.selectedItemIndex]
                                            if item and item.possibleColors and #item.possibleColors > 0 then
                                                config.selectedColorIndex = (rng % #item.possibleColors) + 1
                                                rng = rng * 11 + 5
                                            end
                                        end
                                    end)
                                end
                                presetApplied = true
                                print("[NPCEntity] FEMALE entity #" .. entity.id .. " — randomized " .. slotsChanged .. " config slots")
                            else
                                presetApplied = true
                                print("[NPCEntity] Skipping preset for FEMALE entity #" .. entity.id .. " — no configs to randomize")
                            end
                        end

                        -- =====================================================
                        -- APPROACH B: Modify configs directly (fallback)
                        -- =====================================================
                        if not presetApplied then
                            local outfits = isFemale and NPCEntity.FEMALE_OUTFITS or NPCEntity.MALE_OUTFITS
                            local outfitIndex = ((seed - 1) % #outfits) + 1
                            local outfit = outfits[outfitIndex]

                            if outfit and style.configs and type(style.configs) == "table" then
                                print("[NPCEntity] APPROACH B: Modifying configs directly for entity #" .. entity.id
                                    .. " outfit #" .. outfitIndex .. " (" .. (isFemale and "female" or "male") .. ")")

                                for slotName, slotData in pairs(outfit) do
                                    local config = style.configs[slotName]
                                    if config then
                                        -- Dump config structure for diagnostics (first 2 entities only)
                                        if entity.id <= 2 then
                                            print("[NPCEntity]   APPROACH B config." .. slotName .. " keys:")
                                            for ck, cv in pairs(config) do
                                                print("    config." .. slotName .. "." .. tostring(ck) .. " = " .. type(cv))
                                            end
                                        end

                                        -- Try setting items/selection on the config
                                        pcall(function()
                                            if config.items and type(config.items) == "table" then
                                                -- Find the item index by name
                                                for idx, item in pairs(config.items) do
                                                    if type(item) == "table" and (item.name == slotData.name or item.id == slotData.name) then
                                                        if config.selectedIndex ~= nil then
                                                            config.selectedIndex = idx
                                                        end
                                                        if config.selectedColor ~= nil then
                                                            config.selectedColor = slotData.color
                                                        end
                                                        if entity.id <= 2 then
                                                            print("[NPCEntity]   APPROACH B: matched item idx=" .. tostring(idx) .. " for " .. slotName .. "." .. slotData.name)
                                                        end
                                                        break
                                                    end
                                                end
                                            end
                                        end)

                                        -- Also try: config:setSelection or config:setSelectedIndex
                                        pcall(function()
                                            if config.setSelection then
                                                config:setSelection(slotData.name, slotData.color)
                                                if entity.id <= 2 then
                                                    print("[NPCEntity]   APPROACH B: config:setSelection worked for " .. slotName)
                                                end
                                            end
                                        end)
                                        pcall(function()
                                            if config.setSelectedIndex then
                                                -- Need to find index first
                                                if config.items then
                                                    for idx, item in pairs(config.items) do
                                                        if type(item) == "table" and (item.name == slotData.name or item.id == slotData.name) then
                                                            config:setSelectedIndex(idx)
                                                            if entity.id <= 2 then
                                                                print("[NPCEntity]   APPROACH B: config:setSelectedIndex worked for " .. slotName)
                                                            end
                                                            break
                                                        end
                                                    end
                                                end
                                            end
                                        end)
                                    else
                                        if entity.id <= 2 then
                                            print("[NPCEntity]   APPROACH B: no config for slot '" .. slotName .. "'")
                                        end
                                    end
                                end
                            else
                                print("[NPCEntity] APPROACH B: skipped (outfit=" .. tostring(outfit ~= nil)
                                    .. " configs=" .. tostring(style.configs ~= nil) .. ")")
                            end
                        end

                        humanModel:loadFromStyleAsync(style, function(target2, styleState, styleArgs)
                            print("[NPCEntity] DIRECT: loadFromStyleAsync callback, state=" .. tostring(styleState)
                                .. " entity=#" .. tostring(entity.id))

                            -- loadFromStyleAsync modifies the skeleton mesh (clothing/appearance),
                            -- which can invalidate our animCharSet reference.
                            -- Re-clone animations and re-setup tracks to ensure animation works.
                            pcall(function()
                                if not humanModel.skeleton or humanModel.skeleton == 0 then return end

                                -- Re-clone animation set onto (possibly modified) skeleton
                                local animNode = g_animCache:getNode(AnimationCache.CHARACTER)
                                if animNode and animNode ~= 0 then
                                    cloneAnimCharacterSet(getChildAt(animNode, 0), humanModel.skeleton)
                                end

                                -- Re-acquire charSet
                                local newCS = getAnimCharacterSet(humanModel.skeleton)
                                if newCS == 0 then
                                    newCS = getAnimCharacterSet(getChildAt(humanModel.skeleton, 0))
                                end
                                if not newCS or newCS == 0 then return end

                                -- Re-setup idle on track 0 (enabled)
                                local idleCands = entity.isFemale
                                    and {"idle1FemaleSource", "idle1Source", "idle2FemaleSource", "idle2Source", "idleSource"}
                                    or  {"idle1Source", "idle2Source", "idleSource", "idle1FemaleSource"}
                                for _, name in ipairs(idleCands) do
                                    local okI, idx = pcall(function() return getAnimClipIndex(newCS, name) end)
                                    if okI and idx and idx >= 0 then
                                        clearAnimTrackClip(newCS, 0)
                                        assignAnimTrackClip(newCS, 0, idx)
                                        setAnimTrackLoopState(newCS, 0, true)
                                        enableAnimTrack(newCS, 0)
                                        break
                                    end
                                end

                                -- Re-setup walk on track 1 (disabled initially)
                                local walkCands = entity.isFemale
                                    and {"NPCWalkFemale01Source", "walkSource", "walk1Source", "walkFemaleSource", "runSource"}
                                    or  {"NPCWalkMale01Source", "walkSource", "walk1Source", "runSource"}
                                for _, name in ipairs(walkCands) do
                                    local okW, idx = pcall(function() return getAnimClipIndex(newCS, name) end)
                                    if okW and idx and idx >= 0 then
                                        clearAnimTrackClip(newCS, 1)
                                        assignAnimTrackClip(newCS, 1, idx)
                                        setAnimTrackLoopState(newCS, 1, true)
                                        disableAnimTrack(newCS, 1)
                                        break
                                    end
                                end

                                entity.animCharSet = newCS
                                entity.lastWalkState = nil  -- Force re-evaluation in update
                                print("[NPCEntity] DIRECT: Re-initialized animation after style load, newCS=" .. tostring(newCS))
                            end)
                        end, nil, nil)
                    end
                end)

                entity.humanModel = humanModel
                entity.node = humanModel.rootNode
                entity.isAnimatedCharacter = true
                entity.animatedModelLoaded = true
                entity.useDirectAnimation = true  -- Flag: uses track blending, not ConditionalAnimation

                pcall(function()
                    setVisibility(humanModel.rootNode, true)
                end)

                print("[NPCEntity] DIRECT: Animated character set up for entity #" .. entity.id
                    .. " rootNode=" .. tostring(humanModel.rootNode)
                    .. " skeleton=" .. tostring(humanModel.skeleton)
                    .. " charSet=" .. tostring(entity.animCharSet))
            end, self, {})

        success = true
    end)

    if not ok then
        print("[NPCEntity] DIRECT: Exception: " .. tostring(err))
        return false
    end

    return success
end

--- Update animation parameters on an animated character based on NPC AI state.
-- Called from updateNPCEntity for entities with isAnimatedCharacter = true.
-- Handles two modes:
--   1) Direct animation (VehicleCharacter pattern): track blending via animCharSet
--   2) ConditionalAnimation (HumanGraphicsComponent): parameter-driven animation
-- @param entity  Entity data table
-- @param npc     NPC data table with aiState, movementSpeed, etc.
-- @param dt      Delta time
function NPCEntity:updateAnimatedCharacter(entity, npc, dt)
    local aiState = npc.aiState or "idle"
    local speed = npc.movementSpeed or 0
    local isWalking = (aiState == "walking" or aiState == "traveling" or aiState == "driving")

    -- MODE 1: Direct track enable/disable (VehicleCharacter pattern)
    -- Uses enableAnimTrack/disableAnimTrack to toggle between idle (track 0) and walk (track 1).
    -- Engine auto-advances enabled tracks — no manual setAnimTrackTime or setAnimTrackSpeedScale needed.
    -- (Previous manual time advancement used seconds for a millisecond-scale clip, freezing animation.)
    if entity.useDirectAnimation and entity.animCharSet then
        local wantWalk = isWalking

        -- Only switch tracks when state changes (avoid per-frame enable/disable calls)
        if wantWalk ~= entity.lastWalkState then
            pcall(function()
                local cs = entity.animCharSet
                if wantWalk then
                    disableAnimTrack(cs, 0)  -- idle off
                    enableAnimTrack(cs, 1)   -- walk on
                else
                    enableAnimTrack(cs, 0)   -- idle on
                    disableAnimTrack(cs, 1)  -- walk off
                end
            end)
            entity.lastWalkState = wantWalk
        end

        return
    end

    -- MODE 2: ConditionalAnimation (HumanGraphicsComponent)
    local gfx = entity.graphicsComponent
    if not gfx then return end

    local params = gfx.animationParameters
    if not params then return end

    pcall(function()
        local isRunning = false
        local isIdling = not isWalking

        if isWalking and speed > 2.5 then
            isRunning = true
            isWalking = false
        end

        if params.isWalking then params.isWalking:setValue(isWalking) end
        if params.isRunning then params.isRunning:setValue(isRunning) end
        if params.isIdling then params.isIdling:setValue(isIdling) end
        if params.absSpeed then params.absSpeed:setValue(isWalking and speed or (isRunning and speed or 0)) end
        if params.isGrounded then params.isGrounded:setValue(true) end
        if params.isCloseToGround then params.isCloseToGround:setValue(true) end
        if params.isNPC then params.isNPC:setValue(true) end
        if params.distanceToGround then params.distanceToGround:setValue(0) end

        -- Direction parameters
        if isWalking or isRunning then
            local dirX = math.sin(npc.rotation.y or 0)
            local dirZ = math.cos(npc.rotation.y or 0)
            if params.movementDirX then params.movementDirX:setValue(dirX) end
            if params.movementDirZ then params.movementDirZ:setValue(dirZ) end
            if params.relativeVelocityZ then params.relativeVelocityZ:setValue(speed) end
        else
            if params.movementDirX then params.movementDirX:setValue(0) end
            if params.movementDirZ then params.movementDirZ:setValue(0) end
            if params.relativeVelocityZ then params.relativeVelocityZ:setValue(0) end
        end
    end)

    -- Update the animation system
    pcall(function()
        gfx:update(dt)
    end)
end

--- Load a tractor visual prop (raw i3d node, NOT a registered Vehicle).
-- Tries multiple base-game tractor paths; falls back to a transform group placeholder.
-- The prop is hidden initially and shown via showTractorProp() when the NPC is working.
-- @param entity The entity data table
function NPCEntity:loadTractorProp(entity)
    -- In realistic mode, real vehicles replace props — skip i3d loading entirely
    if self.npcSystem and self.npcSystem.settings
       and self.npcSystem.settings.npcVehicleMode == "realistic" then
        return
    end

    -- Vehicle i3d files are inside game pak archives and cannot be loaded via loadSharedI3DFile.
    -- Use placeholder transform group as the tractor prop (visual marker only).
    local tractorPaths = {}

    local tractorNode = nil

    for _, path in ipairs(tractorPaths) do
        local ok, result = pcall(function()
            if not g_i3DManager then return nil end
            local i3dNode = g_i3DManager:loadSharedI3DFile(path, false, false)
            if i3dNode == nil or i3dNode == 0 then return nil end

            local numChildren = getNumOfChildren(i3dNode)
            if numChildren == 0 then
                delete(i3dNode)
                return nil
            end

            local modelNode = getChildAt(i3dNode, 0)
            local cloned = clone(modelNode, true)
            delete(i3dNode) -- release source i3d

            if cloned == nil or cloned == 0 then return nil end
            return cloned
        end)

        if ok and result then
            tractorNode = result
            if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                print("[NPCEntity] Tractor prop loaded from: " .. path)
            end
            break
        end
    end

    -- Fallback: create a simple transform group as placeholder
    if not tractorNode then
        local ok2, placeholder = pcall(function()
            return createTransformGroup("TractorProp_" .. entity.id)
        end)
        if ok2 and placeholder then
            tractorNode = placeholder
            if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                print("[NPCEntity] Tractor prop: using placeholder transform group")
            end
        end
    end

    -- If we still have nothing, bail gracefully
    if not tractorNode then
        return
    end

    -- Link to scene root, scale, hide, disable physics
    pcall(function()
        link(getRootNode(), tractorNode)
        setScale(tractorNode, 0.9, 0.9, 0.9)
        setVisibility(tractorNode, false)
        if RigidBodyType ~= nil then
            setRigidBodyType(tractorNode, RigidBodyType.NONE)
        end
    end)

    entity.tractorProp = { node = tractorNode, visible = false }
    entity.npcYOffset = 0
end

--- Load a vehicle commuting prop (car/pickup, raw i3d node, NOT a registered Vehicle).
-- Tries a pickup truck first, then a roadster; falls back to a transform group placeholder.
-- The prop is hidden initially and shown via showVehicleProp() when the NPC commutes.
-- @param entity The entity data table
function NPCEntity:loadVehicleProp(entity)
    -- Vehicle i3d files are inside game pak archives and cannot be loaded via loadSharedI3DFile.
    -- Use empty paths to skip loading and fall through to placeholder transform group.
    local vehiclePaths = {}

    local vehicleNode = nil
    local vehicleType = "car"

    for _, path in ipairs(vehiclePaths) do
        local ok, result = pcall(function()
            if not g_i3DManager then return nil end
            local i3dNode = g_i3DManager:loadSharedI3DFile(path, false, false)
            if i3dNode == nil or i3dNode == 0 then return nil end

            local numChildren = getNumOfChildren(i3dNode)
            if numChildren == 0 then
                delete(i3dNode)
                return nil
            end

            local modelNode = getChildAt(i3dNode, 0)
            local cloned = clone(modelNode, true)
            delete(i3dNode) -- release source i3d

            if cloned == nil or cloned == 0 then return nil end
            return cloned
        end)

        if ok and result then
            vehicleNode = result
            -- Determine type from path
            if path:find("Pickup") then
                vehicleType = "pickup"
            else
                vehicleType = "car"
            end
            if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                print("[NPCEntity] Vehicle prop loaded from: " .. path)
            end
            break
        end
    end

    -- Fallback: create a simple transform group as placeholder
    if not vehicleNode then
        local ok2, placeholder = pcall(function()
            return createTransformGroup("VehicleProp_" .. entity.id)
        end)
        if ok2 and placeholder then
            vehicleNode = placeholder
            vehicleType = "placeholder"
            if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                print("[NPCEntity] Vehicle prop: using placeholder transform group")
            end
        end
    end

    -- If we still have nothing, bail gracefully
    if not vehicleNode then
        return
    end

    -- Link to scene root, scale, hide, disable physics
    pcall(function()
        link(getRootNode(), vehicleNode)
        setScale(vehicleNode, 1.0, 1.0, 1.0)
        setVisibility(vehicleNode, false)
        if RigidBodyType ~= nil then
            setRigidBodyType(vehicleNode, RigidBodyType.NONE)
        end
    end)

    entity.vehicleProp = {
        node = vehicleNode,
        type = vehicleType,
        visible = false,
        parkedPosition = nil
    }
end

--- Show or hide the vehicle commuting prop for an NPC.
-- Vehicle model is currently a placeholder (game pak i3ds can't be loaded),
-- so no Y offset is applied. When hidden, if a parked position is set the
-- vehicle stays visible there; otherwise it is fully hidden.
-- @param npc   NPC data table (requires .id)
-- @param show  boolean - true to show vehicle (NPC driving), false to stop driving
function NPCEntity:showVehicleProp(npc, show)
    if not npc or not npc.id then return end

    local entity = self.npcEntities[npc.id]
    if not entity then return end
    if not entity.vehicleProp or not entity.vehicleProp.node then return end

    if show then
        entity.vehicleProp.visible = true
        entity.vehicleProp.parkedPosition = nil -- clear any previous parked state
        pcall(function()
            setVisibility(entity.vehicleProp.node, true)
            -- Position vehicle at NPC location
            setTranslation(entity.vehicleProp.node,
                entity.position.x,
                entity.position.y,
                entity.position.z)
            -- Face movement direction (use NPC rotation)
            setRotation(entity.vehicleProp.node, 0, entity.rotation.y, 0)
        end)
        -- No Y offset — vehicle model is a placeholder, no visible car seat
        npc.canInteract = false

        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print(string.format("[NPCEntity] Vehicle prop shown for NPC %s", tostring(npc.name or npc.id)))
        end
    else
        entity.vehicleProp.visible = false
        -- If a parked position was set, move to that position and keep visible
        if entity.vehicleProp.parkedPosition then
            local pp = entity.vehicleProp.parkedPosition
            pcall(function()
                setTranslation(entity.vehicleProp.node, pp.x, pp.y, pp.z)
                -- Keep parked rotation
                setVisibility(entity.vehicleProp.node, true)
            end)
        else
            pcall(function()
                setVisibility(entity.vehicleProp.node, false)
            end)
        end
        -- Reset NPC Y offset back to ground
        entity.npcYOffset = 0
        npc.canInteract = true

        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print(string.format("[NPCEntity] Vehicle prop hidden/parked for NPC %s", tostring(npc.name or npc.id)))
        end
    end
end

--- Park the NPC's vehicle prop at a specific world position.
-- The vehicle stays visible at the parked location, creating a natural
-- parking lot appearance near buildings and fields.
-- @param npc  NPC data table (requires .id)
-- @param x    World X position to park
-- @param z    World Z position to park
function NPCEntity:parkVehicle(npc, x, z)
    if not npc or not npc.id then return end

    local entity = self.npcEntities[npc.id]
    if not entity then return end
    if not entity.vehicleProp or not entity.vehicleProp.node then return end

    -- Get terrain height at park location
    local parkY = 0
    if g_currentMission and g_currentMission.terrainRootNode then
        local okH, h = pcall(getTerrainHeightAtWorldPos,
            g_currentMission.terrainRootNode, x, 0, z)
        if okH and h then
            parkY = h
        end
    end

    entity.vehicleProp.parkedPosition = { x = x, y = parkY, z = z }

    -- Move vehicle to parked position, pick a random parked orientation
    local parkedYaw = math.random() * math.pi * 2
    pcall(function()
        setTranslation(entity.vehicleProp.node, x, parkY, z)
        setRotation(entity.vehicleProp.node, 0, parkedYaw, 0)
        setVisibility(entity.vehicleProp.node, true)
    end)

    -- NPC is no longer riding in the vehicle
    entity.vehicleProp.visible = false
    entity.npcYOffset = 0
    npc.canInteract = true

    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print(string.format("[NPCEntity] Vehicle parked for NPC %s at (%.1f, %.1f)", tostring(npc.name or npc.id), x, z))
    end
end

function NPCEntity:createDebugRepresentation(entity)
    if not createTransformGroup or not getRootNode then return end
    
    local success = pcall(function()
        entity.debugNode = createTransformGroup("NPC_Debug_" .. entity.id)
        if entity.debugNode then
            link(getRootNode(), entity.debugNode)
            setTranslation(entity.debugNode, entity.position.x, entity.position.y, entity.position.z)
            setRotation(entity.debugNode, entity.rotation.x, entity.rotation.y, entity.rotation.z)
            
            entity.debugText = createTextNode("NPC_DebugText_" .. entity.id)
            if entity.debugText then
                setText(entity.debugText, "NPC")
                setTextColor(entity.debugText, 1, 1, 1, 1)
                setTextAlignment(entity.debugText, TextAlignment.CENTER)
                link(entity.debugNode, entity.debugText)
                setTranslation(entity.debugText, 0, 2, 0)
            end
        end
    end)
    
    if not success then
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print("NPCEntity: Could not create debug representation")
        end
        entity.debugNode = nil
        entity.debugText = nil
    end
end

--- Sync entity position/rotation to NPC data, update animation and visibility.
-- For animated characters: updates position + ConditionalAnimation parameters.
-- For static models: applies Tier 1 procedural animation (bob, breathing, sway).
-- @param npc  NPC data table
-- @param dt   Delta time in seconds
function NPCEntity:updateNPCEntity(npc, dt)
    local entity = self.npcEntities[npc.id]
    if not entity then return end

    -- Hide NPC if sleeping (at home, not visible at night)
    if npc.isSleeping then
        if entity.node then
            pcall(function() setVisibility(entity.node, false) end)
        end
        if entity.isAnimatedCharacter then
            if entity.graphicsComponent then
                pcall(function() entity.graphicsComponent:setModelVisibility(false) end)
            end
            if entity.humanModel and entity.humanModel.rootNode then
                pcall(function() setVisibility(entity.humanModel.rootNode, false) end)
            end
        end
        return  -- Skip all other entity updates while sleeping
    end

    entity.position.x = npc.position.x
    entity.position.z = npc.position.z

    -- Terrain height clamping safety net: always snap entity Y to terrain surface.
    -- This prevents NPCs from floating in the air or sinking below ground regardless
    -- of what the AI movement code does (e.g., teleports, missed Y updates).
    local clampedY = npc.position.y
    if g_currentMission and g_currentMission.terrainRootNode then
        local okTerrain, terrainY = pcall(getTerrainHeightAtWorldPos,
            g_currentMission.terrainRootNode, npc.position.x, 0, npc.position.z)
        if okTerrain and terrainY then
            -- Allow NPC to be slightly above terrain (seated in vehicle offset handled later),
            -- but never below it. Also snap if Y drifts more than 2m above terrain
            -- (unless NPC has a vehicle Y offset, which raises them for cab seating).
            local entityYOffset = entity.npcYOffset or 0
            local expectedY = terrainY + 0.05 + entityYOffset
            if npc.position.y < terrainY or (entityYOffset == 0 and npc.position.y > terrainY + 2) then
                clampedY = terrainY + 0.05
                -- Also fix the source data so AI stays consistent
                npc.position.y = clampedY
            else
                clampedY = npc.position.y
            end
        end
    end
    entity.position.y = clampedY

    -- Smooth rotation: lerp toward target yaw instead of snapping
    local targetYaw = npc.rotation.y or 0
    if dt > 0 then
        local currentYaw = entity.rotation.y or targetYaw
        -- Normalize angle difference to [-pi, pi]
        local diff = targetYaw - currentYaw
        while diff > math.pi do diff = diff - 2 * math.pi end
        while diff < -math.pi do diff = diff + 2 * math.pi end
        entity.rotation.y = currentYaw + diff * math.min(1, dt * 5)
    else
        entity.rotation.y = targetYaw
    end

    self:updateAnimation(entity, npc)
    self:updateVisibility(entity)

    -- Update map hotspot position
    self:updateMapHotspot(entity, npc)

    -- Apply NPC Y offset when seated in tractor/vehicle, plus model origin correction
    local npcYOffset = entity.npcYOffset or 0
    local modelOffset = self.MODEL_Y_OFFSET or 0

    -- ===== ANIMATED CHARACTER PATH =====
    if entity.isAnimatedCharacter then
        -- Update position/rotation on the root node (works for both direct and GFX approaches)
        local rootNode = nil
        if entity.graphicsComponent and entity.graphicsComponent.graphicsRootNode then
            rootNode = entity.graphicsComponent.graphicsRootNode
        elseif entity.humanModel and entity.humanModel.rootNode then
            rootNode = entity.humanModel.rootNode
        elseif entity.node then
            rootNode = entity.node
        end

        if rootNode and rootNode ~= 0 then
            -- Validate node still exists in engine (entityExists returns true for valid nodes)
            local nodeValid = pcall(entityExists, rootNode) and entityExists(rootNode)
            if not nodeValid then
                -- Node was deleted by engine (stale reference) — clear it
                entity.node = nil
                if entity.humanModel then entity.humanModel.rootNode = nil end
                if entity.graphicsComponent then entity.graphicsComponent.graphicsRootNode = nil end
            else
                pcall(function()
                    setTranslation(rootNode,
                        entity.position.x,
                        entity.position.y + npcYOffset + modelOffset,
                        entity.position.z)
                    setRotation(rootNode, 0, entity.rotation.y, 0)
                end)
            end
        end

        -- Update animation (track blending or ConditionalAnimation)
        self:updateAnimatedCharacter(entity, npc, dt)

    else
        -- ===== STATIC MODEL PATH (procedural animation) =====
        -- Procedural animation timer (persistent per entity)
        entity.animTime = (entity.animTime or 0) + dt

        -- Calculate procedural animation offsets
        local yOffset = 0
        local scaleY = entity.scale or 1.0
        local yawOffset = 0
        local aiState = npc.aiState or "idle"
        local t = entity.animTime

        -- Walking bob: vertical sine wave while moving (visible bounce)
        if aiState == "walking" or aiState == "traveling" then
            yOffset = math.sin(t * 8) * 0.08
            -- Slight left-right lean while walking
            yawOffset = math.sin(t * 4) * 0.04
        end

        -- Breathing: Y-scale pulse (always active, visible chest expansion)
        local breathe = 1.0 + math.sin(t * 2) * 0.015
        scaleY = (entity.scale or 1.0) * breathe

        -- Idle sway: rotation oscillation when stationary (visible shifting weight)
        if aiState == "idle" or aiState == "socializing" or aiState == "resting" or aiState == "gathering" then
            yawOffset = math.sin(t * 0.7) * 0.06
            -- Subtle weight-shift bob when idle
            yOffset = math.sin(t * 1.5) * 0.02
        end

        -- Working bob: rhythmic motion when working
        if aiState == "working" then
            yOffset = math.sin(t * 3) * 0.05
            yawOffset = math.sin(t * 1.5) * 0.03
        end

        -- Socializing: animated gesturing feel
        if aiState == "socializing" or aiState == "gathering" then
            yOffset = yOffset + math.sin(t * 2.5) * 0.03
        end

        -- Apply to 3D model node (validate node is still alive)
        if entity.node and entity.node ~= 0 then
            local valid = pcall(entityExists, entity.node) and entityExists(entity.node)
            if not valid then
                entity.node = nil
            else
                pcall(function()
                    setTranslation(entity.node,
                        entity.position.x,
                        entity.position.y + yOffset + npcYOffset + modelOffset,
                        entity.position.z)
                    setRotation(entity.node, 0, entity.rotation.y + yawOffset, 0)
                    setScale(entity.node, entity.scale or 1.0, scaleY, entity.scale or 1.0)
                end)
            end
        end
    end

    -- Update tractor prop position/rotation when visible
    if entity.tractorProp and entity.tractorProp.visible and entity.tractorProp.node then
        pcall(function()
            setTranslation(entity.tractorProp.node,
                entity.position.x,
                entity.position.y,
                entity.position.z)
            setRotation(entity.tractorProp.node, 0, entity.rotation.y, 0)
        end)
    end

    -- Update vehicle prop position/rotation when actively driving (not parked)
    if entity.vehicleProp and entity.vehicleProp.visible and not entity.vehicleProp.parkedPosition and entity.vehicleProp.node then
        pcall(function()
            setTranslation(entity.vehicleProp.node,
                entity.position.x,
                entity.position.y,
                entity.position.z)
            setRotation(entity.vehicleProp.node, 0, entity.rotation.y, 0)
        end)
    end

    -- Update debug node (fallback representation)
    if entity.debugNode then
        local debugOk = pcall(function()
            setTranslation(entity.debugNode,
                entity.position.x,
                entity.position.y + yOffset + modelOffset,
                entity.position.z)
            setRotation(entity.debugNode, 0, entity.rotation.y + yawOffset, 0)

            if entity.debugText then
                local text = string.format("%s\n%s\nRel: %d",
                    npc.name or "Unknown",
                    npc.currentAction or "idle",
                    npc.relationship or 0)
                setText(entity.debugText, text)

                local color = self:getColorForAIState(npc)
                setTextColor(entity.debugText, color.r, color.g, color.b, 1)
            end
        end)
        if not debugOk then
            print("NPCEntity: Failed to update debug node")
        end
    end

    -- Feature 8a: Greeting display - store greeting text on entity for UI pickup
    pcall(function()
        if npc.greetingText and npc.greetingTimer and npc.greetingTimer > 0 then
            entity.greetingText = npc.greetingText
            entity.greetingTimer = npc.greetingTimer
        else
            entity.greetingText = nil
            entity.greetingTimer = nil
        end
    end)

    -- Feature 8c: Seasonal color variation (only update when season changes)
    pcall(function()
        self:updateSeasonalColors(entity)
    end)

    entity.lastUpdateTime = (g_currentMission and g_currentMission.time) or 0
end

function NPCEntity:updateAnimation(entity, npc)
    local targetAnimation = "idle"
    local animationSpeed = 1.0
    
    local aiState = npc.aiState or "idle"
    
    if aiState == "walking" or aiState == "traveling" then
        targetAnimation = "walk"
        animationSpeed = npc.movementSpeed or 1.0
    elseif aiState == "working" then
        targetAnimation = "work"
    elseif aiState == "driving" then
        targetAnimation = "drive"
    elseif aiState == "socializing" then
        targetAnimation = "talk"
        animationSpeed = 0.8 + math.random() * 0.4
    elseif aiState == "resting" then
        targetAnimation = "rest"
        animationSpeed = 0.5
    end
    
    if targetAnimation ~= entity.currentAnimation then
        entity.currentAnimation = targetAnimation
        entity.animationSpeed = animationSpeed
        entity.needsUpdate = true
    end
end

--- Map NPC AI state to a debug color for text/map icon display.
-- @param npc  NPC data table
-- @return table {r, g, b} color
function NPCEntity:getColorForAIState(npc)
    local aiState = npc.aiState or "idle"
    local color = {r=1, g=1, b=1} -- default white

    if aiState == "working" then
        color = {r=0, g=1, b=0} -- green
    elseif aiState == "walking" or aiState == "traveling" then
        color = {r=0, g=0, b=1} -- blue
    elseif aiState == "resting" then
        color = {r=1, g=0.5, b=0} -- orange
    elseif aiState == "socializing" then
        color = {r=1, g=0, b=1} -- purple
    elseif aiState == "driving" or npc.canInteract then
        color = {r=1, g=1, b=0} -- yellow
    end

    return color
end

function NPCEntity:updateVisibility(entity)
    if not g_currentMission or not g_currentMission.player then
        entity.isVisible = false
        return
    end

    local playerX, playerY, playerZ = 0,0,0
    pcall(function()
        playerX, playerY, playerZ = getWorldTranslation(g_currentMission.player.rootNode)
    end)

    local dx = playerX - entity.position.x
    local dy = playerY - entity.position.y
    local dz = playerZ - entity.position.z
    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

    entity.isVisible = distance < self.maxVisibleDistance

    if distance < 50 then
        entity.updatePriority = 1
    elseif distance < 150 then
        entity.updatePriority = 2
    else
        entity.updatePriority = 4
    end

    -- Update animated character visibility
    if entity.isAnimatedCharacter and entity.graphicsComponent then
        pcall(function()
            entity.graphicsComponent:setModelVisibility(entity.isVisible)
        end)
    elseif entity.isAnimatedCharacter and entity.humanModel and entity.humanModel.rootNode then
        pcall(function()
            setVisibility(entity.humanModel.rootNode, entity.isVisible)
        end)
    elseif entity.node then
        -- Update static 3D model visibility
        pcall(function()
            setVisibility(entity.node, entity.isVisible)
        end)
    end

    -- Update debug node visibility (fallback)
    if entity.debugNode then
        pcall(function()
            setVisibility(entity.debugNode, entity.isVisible)
        end)
    end
end

--- Update a rolling batch of entities (round-robin, self.updateBatchSize per call).
-- Only processes entities flagged with needsUpdate. Avoids updating all NPCs every frame.
-- @param dt  Delta time in seconds (clamped to 0.016 if invalid)
function NPCEntity:batchUpdate(dt)
    if not dt or dt <= 0 or dt > 1 then dt = 0.016 end
    if not self.npcSystem or not self.npcSystem.activeNPCs then return end
    
    local entities = self:getAllEntities()
    local entityCount = #entities
    if entityCount == 0 then return end
    
    local startIndex = self.lastBatchIndex + 1
    if startIndex > entityCount then startIndex = 1 end
    
    local endIndex = math.min(startIndex + self.updateBatchSize - 1, entityCount)
    
    for i = startIndex, endIndex do
        local entity = entities[i]
        if entity and entity.needsUpdate then
            local npc = nil
            for _, n in ipairs(self.npcSystem.activeNPCs) do
                if n and n.id == entity.npcId then
                    npc = n
                    break
                end
            end
            
            if npc then
                self:updateNPCEntity(npc, dt)
                entity.needsUpdate = false
            end
        end
    end
    
    self.lastBatchIndex = endIndex
    if self.lastBatchIndex >= entityCount then
        self.lastBatchIndex = 0
    end
end

function NPCEntity:removeNPCEntity(npc)
    if not npc or not npc.id then return end

    local entity = self.npcEntities[npc.id]
    if not entity then return end

    -- Clean up animated character
    if entity.isAnimatedCharacter then
        -- Clean up HumanGraphicsComponent (ConditionalAnimation approach)
        if entity.graphicsComponent then
            pcall(function() entity.graphicsComponent:delete() end)
            entity.graphicsComponent = nil
            entity.node = nil  -- owned by graphics component
        end
        -- Clean up HumanModel (VehicleCharacter pattern approach)
        if entity.humanModel then
            pcall(function() entity.humanModel:delete() end)
            entity.humanModel = nil
            entity.node = nil  -- owned by human model
        end
        entity.isAnimatedCharacter = false
        entity.animCharSet = nil
    end

    if entity.tractorProp and entity.tractorProp.node then
        pcall(function() delete(entity.tractorProp.node) end)
        entity.tractorProp = nil
    end
    if entity.vehicleProp and entity.vehicleProp.node then
        pcall(function() delete(entity.vehicleProp.node) end)
        entity.vehicleProp = nil
    end
    if entity.debugNode then pcall(function() delete(entity.debugNode) end) end
    if entity.node then pcall(function() delete(entity.node) end) end
    self:removeMapHotspot(entity)

    self.npcEntities[npc.id] = nil
    self.lastBatchIndex = 0
end

function NPCEntity:getAllEntities()
    local entities = {}
    for _, entity in pairs(self.npcEntities) do table.insert(entities, entity) end
    return entities
end

--- Remove entities that no longer have a corresponding active NPC, or
-- haven't been updated in >5 minutes (300000 ms).
function NPCEntity:cleanupStaleEntities()
    local currentTime = (g_currentMission and g_currentMission.time) or 0
    local toRemove = {}
    
    for npcId, entity in pairs(self.npcEntities) do
        local npcExists = false
        if self.npcSystem and self.npcSystem.activeNPCs then
            for _, npc in ipairs(self.npcSystem.activeNPCs) do
                if npc and npc.id == npcId then
                    npcExists = true
                    break
                end
            end
        end
        if not npcExists or (entity.lastUpdateTime and currentTime - entity.lastUpdateTime > 300000) then
            table.insert(toRemove, npcId)
        end
    end
    
    for _, npcId in ipairs(toRemove) do
        self:removeNPCEntity({id=npcId})
    end
    
    if #toRemove > 0 and self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print(string.format("NPCEntity: Cleaned up %d stale entities", #toRemove))
    end
end

-- =========================================================
-- Map Hotspot Functions (FS25 MapHotspot API)
-- =========================================================
-- FS25 uses MapHotspot (not MapIcon) for map markers.
-- g_currentMission:addMapHotspot() / :removeMapHotspot()

function NPCEntity:createMapHotspot(entity, npc)
    if not entity or entity.mapHotspot then return end
    if not g_currentMission or not g_currentMission.addMapHotspot then return end
    if not MapHotspot then return end

    local ok = pcall(function()
        local name = (npc and npc.name) or "NPC"
        local hotspot = MapHotspot.new()

        -- Set display name and category
        if hotspot.setName then
            hotspot:setName(name)
        end
        if hotspot.setCategory then
            -- CATEGORY_AI or CATEGORY_OTHER depending on FS25 version
            local category = MapHotspot.CATEGORY_AI or MapHotspot.CATEGORY_OTHER or 1
            hotspot:setCategory(category)
        end

        -- Set initial position
        if hotspot.setWorldPosition then
            hotspot:setWorldPosition(entity.position.x, entity.position.z)
        end

        -- Link to scene node for automatic position tracking (if available)
        if hotspot.setLinkedNode and entity.node then
            hotspot:setLinkedNode(entity.node)
        end

        g_currentMission:addMapHotspot(hotspot)
        entity.mapHotspot = hotspot
    end)

    if not ok then
        entity.mapHotspot = nil
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print("[NPCEntity] MapHotspot creation failed for " .. tostring(npc and npc.name))
        end
    end
end

function NPCEntity:removeMapHotspot(entity)
    if entity and entity.mapHotspot then
        pcall(function()
            if g_currentMission and g_currentMission.removeMapHotspot then
                g_currentMission:removeMapHotspot(entity.mapHotspot)
            end
            if entity.mapHotspot.delete then
                entity.mapHotspot:delete()
            end
        end)
        entity.mapHotspot = nil
    end
end

function NPCEntity:updateMapHotspot(entity, npc)
    if not entity or not entity.mapHotspot then return end

    -- If hotspot is linked to a node, position updates automatically.
    -- Otherwise, update manually.
    if not entity.node and entity.mapHotspot.setWorldPosition then
        pcall(function()
            entity.mapHotspot:setWorldPosition(entity.position.x, entity.position.z)
        end)
    end
end

-- =========================================================
-- Tractor Visual Prop Functions
-- =========================================================
-- The tractor is a visual-only raw i3d node (NOT a registered Vehicle).
-- Players cannot enter or interact with it. It appears when an NPC is
-- working on a field and disappears when they finish.

--- Show or hide the tractor prop for an NPC.
-- When shown, the NPC model is raised by ~1.2m to appear seated in the cab.
-- @param npc   NPC data table (requires .id)
-- @param show  boolean - true to show tractor, false to hide
function NPCEntity:showTractorProp(npc, show)
    if not npc or not npc.id then return end

    local entity = self.npcEntities[npc.id]
    if not entity then return end
    if not entity.tractorProp or not entity.tractorProp.node then return end

    if show then
        entity.tractorProp.visible = true
        -- Tractor model is currently a placeholder (game pak i3ds can't be loaded).
        -- Do NOT apply Y offset — no visible cab to sit in.

        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print(string.format("[NPCEntity] Tractor prop shown for NPC %s", tostring(npc.name or npc.id)))
        end
    else
        entity.tractorProp.visible = false
        pcall(function()
            setVisibility(entity.tractorProp.node, false)
        end)
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print(string.format("[NPCEntity] Tractor prop hidden for NPC %s", tostring(npc.name or npc.id)))
        end
    end
end

--- Called from the AI system when an NPC enters or exits the working state.
-- Shows the tractor prop and disables player interaction while working,
-- then hides the tractor and re-enables interaction when done.
-- @param npc      NPC data table
-- @param working  boolean - true if NPC is entering work state, false if leaving
function NPCEntity:updateWorkingVisuals(npc, working)
    if not npc then return end

    if working then
        self:showTractorProp(npc, true)
        npc.canInteract = false
    else
        npc.canInteract = true
    end
end

-- =========================================================
-- Feature 8c: Seasonal Clothing Colors
-- =========================================================
-- Applies seasonal color multipliers to NPC entity primary colors.
-- Only updates when the season actually changes (tracked via entity.lastSeason).
-- Summer: brighter/warmer, Winter: darker/muted, Spring: earth tones, Autumn: warm earth.

--- Determine current season from the game environment month.
-- @return string  "spring", "summer", "autumn", or "winter"
function NPCEntity:getCurrentSeason()
    local month = 6  -- default to summer
    pcall(function()
        if g_currentMission and g_currentMission.environment then
            local env = g_currentMission.environment
            if env.currentMonth then
                month = env.currentMonth
            elseif env.currentPeriod then
                -- FS25 uses period-based seasons (1-12 = months)
                month = env.currentPeriod
            end
        end
    end)

    if month >= 3 and month <= 5 then
        return "spring", month
    elseif month >= 6 and month <= 8 then
        return "summer", month
    elseif month >= 9 and month <= 11 then
        return "autumn", month
    else
        return "winter", month
    end
end

--- Apply seasonal color variation to an NPC entity's primary color.
-- Modifies the color in place and re-applies via setShaderParameter.
-- Only triggers when season changes (tracked via entity.lastSeason).
-- @param entity  Entity data table with primaryColor and node
function NPCEntity:updateSeasonalColors(entity)
    if not entity then return end

    local season, month = self:getCurrentSeason()

    -- Only update when season changes
    if entity.lastSeason == season then return end
    entity.lastSeason = season

    -- Store base color on first call (so we always modify from the original)
    if not entity.baseColor then
        entity.baseColor = {
            r = entity.primaryColor.r,
            g = entity.primaryColor.g,
            b = entity.primaryColor.b
        }
    end

    local base = entity.baseColor
    local r, g, b = base.r, base.g, base.b

    if season == "summer" then
        -- Brighter, warmer tones
        r = math.min(1.0, r * 1.1)
        g = math.min(1.0, g * 1.05)
        -- b stays the same
    elseif season == "winter" then
        -- Darker, muted tones
        r = r * 0.8
        g = g * 0.8
        b = b * 0.8
    elseif season == "spring" then
        -- Earth tones: boost green slightly
        g = math.min(1.0, g * 1.1)
    elseif season == "autumn" then
        -- Warm earth tones: boost red, reduce blue
        r = math.min(1.0, r * 1.15)
        b = b * 0.85
    end

    entity.primaryColor.r = r
    entity.primaryColor.g = g
    entity.primaryColor.b = b

    -- Re-apply color tint to model shaders
    if entity.node then
        pcall(function()
            if not ClassIds or not ClassIds.SHAPE then return end
            local numChildren = getNumOfChildren(entity.node)
            for i = 0, numChildren - 1 do
                local child = getChildAt(entity.node, i)
                if getHasClassId(child, ClassIds.SHAPE) then
                    setShaderParameter(child, "colorScale", r, g, b, 1, false)
                end
            end
        end)
    end

    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print(string.format("[NPCEntity] Seasonal color update: %s (month=%d) -> R=%.2f G=%.2f B=%.2f",
            season, month or 0, r, g, b))
    end
end
