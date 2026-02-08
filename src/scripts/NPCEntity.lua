-- =========================================================
-- TODO / FUTURE VISION - NPC Visual & Entity System
-- =========================================================
-- [x] 3D model loading via g_i3DManager (shared i3d, clone, delete)
-- [x] Per-NPC color tinting via colorScale shader parameter
-- [x] Debug node fallback when models are unavailable (text above head)
-- [x] Minimap icons via MapIcon API with AI-state-based colors
-- [x] LOD-based batch updates (closer NPCs update more frequently)
-- [x] Visibility culling based on player distance (maxVisibleDistance)
-- [x] Deterministic appearance generation (scale, color) via appearanceSeed
-- [x] Animation state tracking (idle, walk, work, drive, talk, rest)
-- [x] Animation speed modulation based on movement/AI state
-- [ ] Actual character animations (walk cycle, work gesture, talk, rest)
--     - Currently tracks currentAnimation and animationSpeed but doesn't play animations
--     - Need AnimatedObject integration or custom animation controller
-- [ ] Multiple NPC models (currently only "npc_figure.i3d")
--     - Need male/female/elderly/child variants
--     - Model selection based on npc.gender, npc.age, npc.profession
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
-- [ ] Height variation reflected in model scale
--     - entity.height calculated but not used (only uniform entity.scale)
--     - Apply non-uniform scale (1, heightScale, 1) for taller/shorter NPCs
-- [ ] Seasonal clothing variation
--     - Winter coat when environment.currentSeason == "winter"
--     - Sunhat in summer, raincoat in rain
-- [ ] NPC name tag rendering (3D text above head)
--     - Currently only shown in debug mode via debugText
--     - Need optional name tags for multiplayer identification
-- [ ] Interaction highlight (outline/glow when canInteract == true)
--     - Visual feedback that NPC is interactable (within range)
-- [ ] Walking on terrain (Y position adjustment)
--     - Currently uses npc.position.y directly (may float/sink)
--     - Need terrain raycast to plant feet on ground
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
--   - Minimap icons via MapIcon API
--   - LOD-based batch updates (closer NPCs update more frequently)
--   - Visibility culling based on player distance
--
-- Lifecycle: initialize() → createNPCEntity() per NPC → updateNPCEntity() per frame
--            → removeNPCEntity() on despawn → cleanupStaleEntities() periodically
-- =========================================================

NPCEntity = {}
NPCEntity_mt = Class(NPCEntity)

--- Create a new NPCEntity manager.
-- @param npcSystem  NPCSystem reference (provides settings, activeNPCs)
-- @return NPCEntity instance
function NPCEntity.new(npcSystem)
    local self = setmetatable({}, NPCEntity_mt)

    self.npcSystem = npcSystem       -- Back-reference to parent system
    self.npcEntities = {}            -- Map of NPC ID → entity data table
    self.nextEntityId = 1            -- Auto-incrementing entity ID counter

    -- 3D Model loading (configured by initialize())
    self.modelPath = nil             -- Full path to npc_figure.i3d (set via initialize)
    self.modelAvailable = false      -- True once modelPath is validated

    -- Performance: batch updates to avoid processing all NPCs every frame
    self.maxVisibleDistance = 200     -- NPCs beyond this are hidden
    self.updateBatchSize = 5         -- Max entities updated per batchUpdate() call
    self.lastBatchIndex = 0          -- Rolling index for round-robin batching

    return self
end

--- Initialize model path for 3D NPC figures
-- @param modDirectory The mod's directory path (with trailing slash)
function NPCEntity:initialize(modDirectory)
    if not modDirectory then return end

    -- Use Utils.getFilename() for proper path resolution inside ZIP files
    if Utils and Utils.getFilename then
        self.modelPath = Utils.getFilename("models/npc_figure.i3d", modDirectory)
    else
        self.modelPath = modDirectory .. "models/npc_figure.i3d"
    end
    self.modelAvailable = true
    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print("[NPCEntity] NPC model path: " .. tostring(self.modelPath))
    end
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
        currentAnimation = "idle",
        animationSpeed = 1.0,
        animationState = "playing",
        isVisible = true,
        needsUpdate = true,
        lastUpdateTime = currentTime,
        updatePriority = 1,
        debugNode = nil,
        debugText = nil,
        mapIcon = nil
    }

    -- Try to load 3D model
    local modelLoaded = false
    if self.modelAvailable and self.modelPath and g_i3DManager then
        modelLoaded = self:loadNPCModel(entity)
    end

    -- Fallback to debug representation if model failed or unavailable
    if not modelLoaded then
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            self:createDebugRepresentation(entity)
        end
    end

    self.npcEntities[npc.id] = entity
    npc.entityId = entityId

    self:createMapIcon(entity, npc)

    -- Restore RNG to non-deterministic state (prevents other systems from
    -- getting the same sequence of random numbers for every NPC)
    math.randomseed((g_currentMission and g_currentMission.time) or 12345)

    return true
end

--- Load a 3D model for the NPC entity using shared i3d loading
-- @param entity The entity data table
-- @return true if model loaded successfully
function NPCEntity:loadNPCModel(entity)
    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print("[NPCEntity] loadNPCModel: Loading: " .. tostring(self.modelPath))
    end

    local i3dNode = g_i3DManager:loadSharedI3DFile(self.modelPath, false, false)
    if i3dNode == nil or i3dNode == 0 then
        print("[NPCEntity] FAILED - i3d returned nil/0 for: " .. tostring(self.modelPath))
        return false
    end

    local numChildren = getNumOfChildren(i3dNode)
    if numChildren == 0 then
        print("[NPCEntity] FAILED - No children in i3d root")
        delete(i3dNode)
        return false
    end

    local modelNode = getChildAt(i3dNode, 0)
    entity.node = clone(modelNode, true)

    -- Validate clone result before using it
    if entity.node == nil or entity.node == 0 then
        print("[NPCEntity] FAILED - clone() returned nil/0")
        delete(i3dNode)
        return false
    end

    link(getRootNode(), entity.node)

    setTranslation(entity.node, entity.position.x, entity.position.y, entity.position.z)
    setRotation(entity.node, 0, entity.rotation.y, 0)
    setScale(entity.node, entity.scale, entity.scale, entity.scale)

    -- Disable physics (NPCs are visual only)
    if RigidBodyType ~= nil then
        pcall(function()
            setRigidBodyType(entity.node, RigidBodyType.NONE)
        end)
    end

    self:applyColorTint(entity)
    setVisibility(entity.node, true)
    delete(i3dNode)  -- Release source i3d after cloning

    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print(string.format("[NPCEntity] Model loaded OK for entity #%d", entity.id))
    end
    return true
end

--- Apply a per-NPC color tint to the model for visual variety
-- @param entity The entity data table with node and primaryColor
function NPCEntity:applyColorTint(entity)
    if not entity.node then return end
    -- ClassIds.SHAPE may not exist in all FS25 versions
    if not ClassIds or not ClassIds.SHAPE then return end

    local c = entity.primaryColor
    pcall(function()
        local numChildren = getNumOfChildren(entity.node)
        for i = 0, numChildren - 1 do
            local child = getChildAt(entity.node, i)
            if getHasClassId(child, ClassIds.SHAPE) then
                setShaderParameter(child, "colorScale", c.r, c.g, c.b, 1, false)
            end
        end
    end)
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
-- @param npc  NPC data table
-- @param dt   Delta time in seconds
function NPCEntity:updateNPCEntity(npc, dt)
    local entity = self.npcEntities[npc.id]
    if not entity then return end

    entity.position.x = npc.position.x
    entity.position.y = npc.position.y
    entity.position.z = npc.position.z
    entity.rotation.y = npc.rotation.y or 0

    self:updateAnimation(entity, npc)
    self:updateVisibility(entity)

    -- Update map icon position and color
    self:updateMapIcon(entity, npc)

    -- Update 3D model node position/rotation
    if entity.node then
        pcall(function()
            setTranslation(entity.node, entity.position.x, entity.position.y, entity.position.z)
            setRotation(entity.node, 0, entity.rotation.y, 0)
        end)
    end

    -- Update debug node (fallback representation)
    if entity.debugNode then
        local debugOk = pcall(function()
            setTranslation(entity.debugNode, entity.position.x, entity.position.y, entity.position.z)
            setRotation(entity.debugNode, 0, entity.rotation.y, 0)

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

    -- Update 3D model visibility
    if entity.node then
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
    
    if entity.debugNode then pcall(function() delete(entity.debugNode) end) end
    if entity.node then pcall(function() delete(entity.node) end) end
    self:removeMapIcon(entity)
    
    self.npcEntities[npc.id] = nil
    self.lastBatchIndex = 0
end

function NPCEntity:getEntityPosition(npcId)
    local entity = self.npcEntities[npcId]
    return entity and entity.position or nil
end

function NPCEntity:setEntityPosition(npcId, x, y, z)
    local entity = self.npcEntities[npcId]
    if entity then
        entity.position = {x=x, y=y, z=z}
        entity.needsUpdate = true
        if entity.node then pcall(function() setTranslation(entity.node, x, y, z) end) end
        if entity.debugNode then pcall(function() setTranslation(entity.debugNode, x, y, z) end) end
        if entity.mapIcon then pcall(function() entity.mapIcon:setWorldPosition(x, y, z) end) end
    end
end

function NPCEntity:setEntityRotation(npcId, yaw)
    local entity = self.npcEntities[npcId]
    if entity then
        entity.rotation.y = yaw
        entity.needsUpdate = true
        if entity.node then pcall(function() setRotation(entity.node, 0, yaw, 0) end) end
        if entity.debugNode then pcall(function() setRotation(entity.debugNode, 0, yaw, 0) end) end
    end
end

function NPCEntity:getAllEntities()
    local entities = {}
    for _, entity in pairs(self.npcEntities) do table.insert(entities, entity) end
    return entities
end

function NPCEntity:getEntityCount()
    local count = 0
    for _ in pairs(self.npcEntities) do count = count + 1 end
    return count
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
-- Map Icon Functions
-- =========================================================

function NPCEntity:createMapIcon(entity, npc)
    if not entity or entity.mapIcon then return end

    -- MapIcon may not exist in all FS25 versions; fail silently
    local ok = pcall(function()
        local parentNode = entity.node or getRootNode()
        local iconFilename = "data/shared/vehicle/hud/vehicleMapIcon.dds"
        local iconSize = 0.02

        entity.mapIcon = MapIcon.new(iconFilename, parentNode, nil, iconSize, false, false)

        if npc and npc.name then
            entity.mapIcon:setName(npc.name)
        end

        if g_currentMission then
            g_currentMission:addMapIcon(entity.mapIcon)
        end
    end)

    if not ok then
        entity.mapIcon = nil
    end
end

function NPCEntity:removeMapIcon(entity)
    if entity and entity.mapIcon then
        pcall(function()
            if g_currentMission then g_currentMission:removeMapIcon(entity.mapIcon) end
            entity.mapIcon:delete()
        end)
        entity.mapIcon = nil
    end
end

function NPCEntity:updateMapIcon(entity, npc)
    if not entity or not entity.mapIcon then return end
    
    local pos = entity.position
    pcall(function()
        entity.mapIcon:setWorldPosition(pos.x, pos.y, pos.z)
    end)
    
    if npc then
        local color = self:getColorForAIState(npc)
        pcall(function() entity.mapIcon:setColor(color.r, color.g, color.b, 1) end)
    end
    
    if not g_currentMission or not g_currentMission.player then return end
    local playerX, playerY, playerZ = 0,0,0
    pcall(function() playerX, playerY, playerZ = getWorldTranslation(g_currentMission.player.rootNode) end)

    local dx = playerX - pos.x
    local dy = playerY - pos.y
    local dz = playerZ - pos.z
    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)

    entity.mapIcon:setVisible(distance <= self.maxVisibleDistance)
end
