-- =========================================================
-- FS25 NPC Favor Mod - NPC Entity Management
-- =========================================================

NPCEntity = {}
NPCEntity_mt = Class(NPCEntity)

function NPCEntity.new(npcSystem)
    local self = setmetatable({}, NPCEntity_mt)
    
    self.npcSystem = npcSystem
    self.npcEntities = {} -- Map of NPC ID to entity data
    self.nextEntityId = 1
    
    -- Performance optimization
    self.maxVisibleDistance = 200
    self.updateBatchSize = 5
    self.lastBatchIndex = 0
    
    return self
end

function NPCEntity:createNPCEntity(npc)
    if not npc or not npc.position then
        print("NPCEntity: ERROR - Invalid NPC data")
        return false
    end
    
    local entityId = self.nextEntityId
    self.nextEntityId = self.nextEntityId + 1
    
    local appearanceSeed = npc.appearanceSeed or math.random(1, 1000)
    math.randomseed(appearanceSeed)
    
    local currentTime = os.clock() * 1000
    
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
            r = math.random(),
            g = math.random(),
            b = math.random()
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
    
    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        self:createDebugRepresentation(entity)
    end
    
    self.npcEntities[npc.id] = entity
    npc.entityId = entityId
    
    self:createMapIcon(entity, npc)
    
    math.randomseed(os.time())
    
    return true
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
        print("NPCEntity: Could not create debug representation")
        entity.debugNode = nil
        entity.debugText = nil
    end
end

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
    
    if entity.debugNode then
        local success = pcall(function()
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
        
        if not success then
            print("NPCEntity: Failed to update debug node")
        end
    end
    
    entity.lastUpdateTime = os.clock() * 1000
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
    
    if entity.debugNode then
        pcall(function()
            setVisibility(entity.debugNode, entity.isVisible)
        end)
    end
end

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
        if entity.debugNode then pcall(function() setTranslation(entity.debugNode, x, y, z) end) end
        if entity.mapIcon then pcall(function() entity.mapIcon:setWorldPosition(x, y, z) end) end
    end
end

function NPCEntity:setEntityRotation(npcId, yaw)
    local entity = self.npcEntities[npcId]
    if entity then
        entity.rotation.y = yaw
        entity.needsUpdate = true
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

function NPCEntity:cleanupStaleEntities()
    local currentTime = os.clock() * 1000
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
end

function NPCEntity:removeMapIcon(entity)
    if entity and entity.mapIcon then
        if g_currentMission then g_currentMission:removeMapIcon(entity.mapIcon) end
        entity.mapIcon:delete()
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
