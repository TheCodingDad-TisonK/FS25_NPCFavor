-- =========================================================
-- FS25 NPC Favor Mod - Main NPC System
-- =========================================================
-- Coordinates all NPC subsystems
-- =========================================================

NPCSystem = {}
NPCSystem_mt = Class(NPCSystem)

function NPCSystem.new(mission, modDirectory, modName)
    print("[NPCSystem] Creating new NPCSystem instance")
    
    local self = setmetatable({}, NPCSystem_mt)
    
    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName
    
    print("[NPCSystem] Initializing subsystems...")
    
    -- Initialize subsystems FIRST with safe defaults
    self.settings = NPCSettings.new()
    
    self.config = {
        getRandomNPCName = function()
            local names = {
                "Old MacDonald", "Farmer Joe", "Mrs. Henderson", 
                "Young Peter", "Anna Schmidt", "Hans Bauer"
            }
            return names[math.random(1, #names)]
        end,
        getRandomPersonality = function()
            local personalities = {"hardworking", "lazy", "social", "generous", "grumpy"}
            return personalities[math.random(1, #personalities)]
        end,
        getRandomNPCModel = function()
            return "farmer"
        end,
        getRandomClothing = function()
            return {"farmer"}
        end,
        getRandomVehicleType = function()
            return "tractor"
        end,
        getRandomVehicleColor = function()
            return {r = 1.0, g = 0.2, b = 0.2, name = "red"}
        end
    }
    
    -- Core systems with SAFE initialization
    self.entityManager = {
        createNPCEntity = function(npc) return true end,
        updateNPCEntity = function(npc, dt) end,
        removeNPCEntity = function(npc) end
    }
    
    self.aiSystem = {
        update = function(dt) end,
        updateNPCState = function(npc, dt) 
            -- Simple AI state
            if not npc.aiState then npc.aiState = "idle" end
            if not npc.currentAction then npc.currentAction = "idle" end
        end
    }
    
    self.scheduler = {
        start = function() print("Scheduler started") end,
        update = function(dt) end,
        getCurrentHour = function() 
            if g_currentMission and g_currentMission.environment then
                return g_currentMission.environment.currentHour or 12
            end
            return 12
        end,
        getCurrentMinute = function() return 0 end,
        getCurrentTimeString = function() return "12:00" end,
        updateNPCDailySchedule = function(npc, month) end
    }
    
    self.relationshipManager = {
        updateRelationship = function(npcId, amount, reason)
            print(string.format("Relationship update for NPC %d: %+d (%s)", npcId, amount, reason))
        end,
        getRelationshipColor = function(value)
            if value > 70 then return {r = 0, g = 1, b = 0} end
            if value > 40 then return {r = 1, g = 1, b = 0} end
            return {r = 1, g = 0, b = 0}
        end
    }
    
    self.favorSystem = {
        update = function(dt) end,
        createFavor = function(npc, favorType) return nil end,
        getActiveFavors = function() return {} end,
        getCompletedFavors = function() return {} end,
        getNPCFromFavor = function(favorId) return nil end,
        completeFavor = function(favorId) return false end,
        addPlayerFavor = function(favor) end
    }
    
    self.interactionUI = {
        update = function(dt) end,
        showInteractionHint = function(npc, distance) end,
        openDialog = function(npc) 
            print("Opening dialog with " .. (npc.name or "Unknown NPC"))
        end,
        delete = function() end
    }

    self.settingsIntegration = {
        initialize = function() end,
        update = function(dt) end,
        delete = function() end
    }

    self.gui = NPCFavorGUI.new(self)

    self.dailyEvents = {}
    self.scheduledNPCInteractions = {}
    self.lastScheduleUpdate = 0
    self.scheduleUpdateInterval = 1000
    self.eventIdCounter = 1
    
    -- State
    self.isInitialized = false
    self.initializing = false
    self.delayedInitAttempts = 0
    self.initTimer = nil
    self.activeNPCs = {}
    self.npcCount = 0
    self.lastUpdateTime = 0
    self.updateCounter = 0
    self.playerPosition = {x = 0, y = 0, z = 0}
    self.playerPositionValid = false
    self.nearbyNPCs = {}
    self.lastSaveTime = 0
    self.saveInterval = 30000
    self.savedNPCData = nil
    
    print("[NPCSystem] NPCSystem instance created successfully")
    return self
end

function NPCSystem:onMissionLoaded()
    -- Prevent multiple init attempts
    if self.isInitialized then
        return
    end
    
    if self.initializing then
        return
    end
    
    if self.settingsIntegration and self.settingsIntegration.initialize then
        self.settingsIntegration:initialize()
    end

    self.initializing = true
    
    print("[NPC Favor] Starting mission-loaded initialization...")
    
    -- Create a one-time init updater with proper return logic
    local initUpdater = {
        initDone = false,
        update = function(_, dt)
            -- If already done, return true to remove updater
            if self.initDone then
                return true
            end
            
            -- Check mission state
            if not g_currentMission or not g_currentMission.isMissionStarted then
                return false -- Keep trying
            end
            
            if not g_currentMission.terrainRootNode then
                return false -- Keep trying
            end
            
            -- All checks passed, initialize ONCE
            if not self.initDone then
                self.initDone = true
                
                print("[NPC Favor] All checks passed, initializing NPCs...")
                
                -- Initialize NPCs
                self:initializeNPCs()
                
                -- Show notification
                if self.settings.showNotifications then 
                    if g_currentMission and g_currentMission.hud then
                        g_currentMission.hud:showBlinkingWarning(
                            "[NPC Favor] Mod loaded - Type 'npcHelp' for commands",
                            8000
                        )
                    end
                end
                
                self.isInitialized = true
                self.initializing = false
                print("[NPC Favor] Initialization complete successfully!")
                
                return true -- Remove updater
            end
            
            return false
        end
    }
    
    -- Add the updater
    if self.mission and self.mission.addUpdateable then
        self.mission:addUpdateable(initUpdater)
    else
        print("[NPC Favor] ERROR: Cannot add updateable")
        self.initializing = false
    end
end

function NPCSystem:initializeGUI()
    -- Initialize GUI system
    if NPCFavorGUI then
        self.gui = NPCFavorGUI.new(self)
        print("[NPCSystem] GUI system initialized")
    else
        print("[NPCSystem] ERROR: NPCFavorGUI not found")
    end
end

function NPCSystem:initializeNPCs()
    -- Clear existing NPCs if any
    self:clearAllNPCs()
    
    -- Find suitable spawn locations
    local spawnLocations = self:findNPCSpawnLocations()
    
    -- Create NPCs
    for i = 1, math.min(#spawnLocations, self.settings.maxNPCs) do
        local location = spawnLocations[i]
        local npc = self:createNPCAtLocation(location)
        
        if npc then
            -- Initialize NPC with proper data
            self:initializeNPCData(npc, location, i)
            
            table.insert(self.activeNPCs, npc)
            self.npcCount = self.npcCount + 1
            
            -- Only print first few NPCs for debugging
            if i <= 3 then
                print(string.format("NPC %d created: %s", i, npc.name))
            end
        end
    end
    
    if self.npcCount > 3 then
        print(string.format("... and %d more NPCs created", self.npcCount - 3))
    end
    
    print(string.format("NPC Favor: Generated %d total NPCs", self.npcCount))
end

function NPCSystem:generateNewNPCs()
    -- Find suitable spawn locations
    local spawnLocations = self:findNPCSpawnLocations()
    
    -- Create NPCs
    for i = 1, math.min(#spawnLocations, self.settings.maxNPCs) do
        local location = spawnLocations[i]
        local npc = self:createNPCAtLocation(location)
        
        if npc then
            -- Initialize NPC with proper data
            self:initializeNPCData(npc, location, i)
            
            table.insert(self.activeNPCs, npc)
            self.npcCount = self.npcCount + 1
            
            print(string.format("NPC %d created: %s at (%.1f, %.1f, %.1f)", 
                i, npc.name, location.x, location.y, location.z))
        end
    end
end

function NPCSystem:initializeNPCData(npc, location, npcId)
    -- Assign properties with validation
    if location then
        npc.homePosition = {
            x = location.x or 0,
            y = location.y or 0,
            z = location.z or 0
        }
    else
        npc.homePosition = {x = 0, y = 0, z = 0}
    end
    
    npc.assignedField = self:findNearestField(location.x, location.z, npcId)
    npc.assignedVehicles = self:generateNPCVehicles(npcId)
    
    -- Initialize AI state
    npc.aiState = "idle"
    npc.currentAction = "idle"
    npc.path = nil
    
    -- Initialize relationship
    npc.relationship = 50
    
    -- Set unique NPC ID
    npc.uniqueId = string.format("npc_%d_%s_%d", 
        npcId, 
        string.lower((npc.name or "Unknown"):gsub("%s+", "_")),
        math.random(1000, 9999)
    )
    
    -- Add to entity manager
    self.entityManager:createNPCEntity(npc)
end

function NPCSystem:findNPCSpawnLocations()
    local locations = {}
    
    -- Default to center of map
    local centerX, centerZ = 0, 0
    if g_currentMission and g_currentMission.terrainSize then
        centerX = g_currentMission.terrainSize / 2
        centerZ = g_currentMission.terrainSize / 2
    end
    
    -- Create locations around center
    local neededLocations = self.settings.maxNPCs
    
    for i = 1, neededLocations do
        local angle = (i / neededLocations) * math.pi * 2
        local distance = 50 + math.random(0, 100)
        
        table.insert(locations, {
            x = centerX + math.cos(angle) * distance,
            y = 0,
            z = centerZ + math.sin(angle) * distance,
            building = nil,
            isPredefined = false,
            isResidential = false
        })
    end
    
    -- Validate locations on terrain
    local validLocations = {}
    
    if g_currentMission and g_currentMission.terrainRootNode then
        for _, loc in ipairs(locations) do
            -- Get terrain height safely
            local success, terrainHeight = pcall(getTerrainHeightAtWorldPos, 
                g_currentMission.terrainRootNode, loc.x, 0, loc.z)
            
            if success and terrainHeight then
                loc.y = terrainHeight + 0.5
            else
                loc.y = 0
            end
            
            table.insert(validLocations, loc)
        end
    else
        validLocations = locations
    end
    
    return validLocations
end

function NPCSystem:createNPCAtLocation(location)
    if not location then
        print("NPC Favor: ERROR - No location provided for NPC creation")
        return nil
    end
    
    local npc = {
        id = #self.activeNPCs + 1,
        name = self.config.getRandomNPCName(),
        age = math.random(25, 65),
        personality = self.config.getRandomPersonality(),
        
        -- Position with validation
        position = {
            x = location.x or 0,
            y = location.y or 0,
            z = location.z or 0
        },
        rotation = {x = 0, y = math.random() * math.pi * 2, z = 0},
        
        -- State
        isActive = true,
        currentAction = "idle",
        currentTask = nil,
        currentVehicle = nil,
        targetPosition = nil,
        canInteract = false,
        interactionDistance = 999,
        
        -- Properties
        homePosition = location,
        assignedField = nil,
        assignedVehicles = {},
        
        -- Stats
        relationship = 50,
        favorCooldown = 0,
        lastInteractionTime = 0,
        totalFavorsCompleted = 0,
        totalFavorsFailed = 0,
        
        -- Visual
        model = self.config.getRandomNPCModel(),
        clothing = self.config.getRandomClothing(),
        appearanceSeed = math.random(1, 1000),
        
        -- AI
        aiState = "idle",
        path = nil,
        movementSpeed = 1.0 + math.random() * 0.5,
        aiPersonalityModifiers = {
            workEthic = 1.0,
            sociability = 1.0,
            generosity = 1.0,
            punctuality = 1.0
        },
        
        -- Performance
        lastUpdateTime = 0,
        updatePriority = 1,
        
        -- Persistence
        uniqueId = nil,
        saveData = {},
        entityId = nil
    }
    
    -- Apply personality-based modifiers
    if npc.personality == "hardworking" then
        npc.aiPersonalityModifiers.workEthic = 1.5
        npc.aiPersonalityModifiers.punctuality = 1.3
    elseif npc.personality == "lazy" then
        npc.aiPersonalityModifiers.workEthic = 0.5
        npc.aiPersonalityModifiers.punctuality = 0.7
    elseif npc.personality == "social" then
        npc.aiPersonalityModifiers.sociability = 1.5
        npc.aiPersonalityModifiers.workEthic = 0.8
    elseif npc.personality == "generous" then
        npc.aiPersonalityModifiers.generosity = 1.5
    elseif npc.personality == "grumpy" then
        npc.aiPersonalityModifiers.sociability = 0.3
        npc.aiPersonalityModifiers.generosity = 0.5
    end
    
    -- Apply to movement speed
    npc.movementSpeed = npc.movementSpeed * (0.8 + (npc.aiPersonalityModifiers.workEthic * 0.2))
    
    return npc
end

function NPCSystem:findNearestField(x, z, npcId)
    -- Simplified field finding for now
    return nil
end

function NPCSystem:generateNPCVehicles(npcId)
    local vehicles = {}
    
    -- Each NPC gets 1 vehicle for now
    table.insert(vehicles, {
        type = "tractor",
        color = {r = 0.2, g = 0.6, b = 1.0},
        isAvailable = true,
        currentTask = nil,
        position = nil,
        fuelLevel = 100,
        condition = 100
    })
    
    return vehicles
end

function NPCSystem:update(dt)
    if not self.settings.enabled or not self.isInitialized then
        return
    end
    
    self.updateCounter = self.updateCounter + 1
    
    -- Update player position cache
    self:updatePlayerPosition()
    
    -- Update all NPCs
    self:updateNPCs(dt)
    
    -- Debug info occasionally
    if self.settings.debugMode and self.updateCounter % 300 == 0 then
        print(string.format("[NPC Favor] Update #%d - Active NPCs: %d", 
            self.updateCounter, self.npcCount))
    end
end

function NPCSystem:updatePlayerPosition()
    if not g_currentMission or not g_currentMission.player then
        self.playerPositionValid = false
        return
    end
    
    local success, x, y, z = pcall(getWorldTranslation, g_currentMission.player.rootNode)
    if success and x and y and z then
        self.playerPosition.x = x
        self.playerPosition.y = y
        self.playerPosition.z = z
        self.playerPositionValid = true
    else
        self.playerPositionValid = false
    end
end

function NPCSystem:updateNPCs(dt)
    -- Clear nearby NPCs cache
    self.nearbyNPCs = {}
    
    for _, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            -- Update AI state
            self.aiSystem:updateNPCState(npc, dt)
            
            -- Update entity position
            self.entityManager:updateNPCEntity(npc, dt)
            
            -- Check for player proximity
            self:checkPlayerProximity(npc)
            
            -- Update timers
            if npc.favorCooldown > 0 then
                npc.favorCooldown = npc.favorCooldown - dt
                if npc.favorCooldown < 0 then
                    npc.favorCooldown = 0
                end
            end
            
            -- Simple random movement
            if math.random() < 0.001 then
                npc.position.x = npc.position.x + (math.random() - 0.5) * 0.1
                npc.position.z = npc.position.z + (math.random() - 0.5) * 0.1
            end
            
            -- Add to nearby list if close enough
            if npc.canInteract then
                table.insert(self.nearbyNPCs, npc)
            end
            
            -- Update last update time
            npc.lastUpdateTime = self:getCurrentGameTime()
        end
    end
end

function NPCSystem:checkPlayerProximity(npc)
    if not self.playerPositionValid then
        npc.canInteract = false
        return
    end
    
    local dx = npc.position.x - self.playerPosition.x
    local dz = npc.position.z - self.playerPosition.z
    local distance = math.sqrt(dx * dx + dz * dz)
    
    -- Show interaction hint when player is close
    if distance < 10 then
        npc.canInteract = true
        npc.interactionDistance = distance
    else
        npc.canInteract = false
    end
end

function NPCSystem:getCurrentGameTime()
    -- SAFE time getter
    if g_currentMission and g_currentMission.time then
        return g_currentMission.time
    end
    return 0
end

function NPCSystem:showNotification(title, message)
    if not self.settings.showNotifications then
        return
    end
    
    -- Use game notification system if available
    if g_currentMission and g_currentMission.inGameMenu and g_currentMission.inGameMenu.messageCenter then
        g_currentMission.inGameMenu.messageCenter:addMissionMessage(message, title, nil, nil, nil)
    else
        -- Fallback to console
        print(string.format("[NPC] %s: %s", title, message))
    end
end

function NPCSystem:consoleCommandStatus()
    local status = "=== NPC Favor System Status ===\n"
    status = status .. string.format("Enabled: %s\n", tostring(self.settings.enabled))
    status = status .. string.format("Initialized: %s\n", tostring(self.isInitialized))
    status = status .. string.format("Active NPCs: %d/%d\n", self.npcCount, self.settings.maxNPCs)
    status = status .. string.format("Update Counter: %d\n", self.updateCounter)
    status = status .. string.format("Nearby NPCs: %d\n", #self.nearbyNPCs)
    
    for i, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            status = status .. string.format("\n%d. %s (%s)\n", i, npc.name, npc.personality)
            status = status .. string.format("   Position: (%.1f, %.1f, %.1f)\n", 
                npc.position.x, npc.position.y, npc.position.z)
            status = status .. string.format("   Action: %s\n", npc.currentAction)
            status = status .. string.format("   Relationship: %d/100\n", npc.relationship)
            status = status .. string.format("   Can Interact: %s\n", tostring(npc.canInteract))
        end
    end
    
    return status
end

function NPCSystem:consoleCommandSpawn(name)
    if not self.isInitialized then
        return "NPC System not initialized. Try 'npcReset' first."
    end
    
    if self.npcCount >= self.settings.maxNPCs then
        return string.format("Cannot spawn NPC: maximum NPC limit reached (%d/%d)", 
            self.npcCount, self.settings.maxNPCs)
    end
    
    if not name or name == "" then
        name = self.config.getRandomNPCName()
    end
    
    -- Find position near player
    local location = nil
    if self.playerPositionValid then
        local angle = math.random() * math.pi * 2
        local distance = 20 + math.random(0, 30)
        
        location = {
            x = self.playerPosition.x + math.cos(angle) * distance,
            y = self.playerPosition.y,
            z = self.playerPosition.z + math.sin(angle) * distance
        }
    else
        location = {x = 0, y = 0, z = 0}
    end
    
    local npc = self:createNPCAtLocation(location)
    if npc then
        npc.name = name
        
        -- Initialize NPC data
        self:initializeNPCData(npc, location, #self.activeNPCs + 1)
        
        table.insert(self.activeNPCs, npc)
        self.npcCount = self.npcCount + 1
        
        return string.format("NPC '%s' spawned at (%.1f, %.1f, %.1f)", 
            name, location.x, location.y, location.z)
    end
    
    return "Failed to spawn NPC"
end

function NPCSystem:consoleCommandList()
    if self.npcCount == 0 then
        return "No active NPCs"
    end
    
    local list = string.format("=== Active NPCs (%d total) ===\n", self.npcCount)
    
    for i, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            list = list .. string.format("%d. %s - %s (%s) - Rel: %d\n", 
                i, npc.name, npc.currentAction, npc.personality, npc.relationship)
        end
    end
    
    return list
end

function NPCSystem:consoleCommandReset()
    print("NPC Favor: Resetting NPC system...")
    
    -- Remove all NPCs
    self:clearAllNPCs()
    
    -- Reset state
    self.isInitialized = false
    self.initializing = false
    self.delayedInitAttempts = 0
    self.npcCount = 0
    
    -- Try to reinitialize
    self:onMissionLoaded()
    
    return "NPC system reset and reinitializing..."
end

function NPCSystem:clearAllNPCs()
    for _, npc in ipairs(self.activeNPCs) do
        self.entityManager:removeNPCEntity(npc)
    end
    
    self.activeNPCs = {}
    self.npcCount = 0
    self.nearbyNPCs = {}
end

function NPCSystem:delete()
    print("[NPC Favor] Shutting down")
    
    -- Clean up NPCs
    self:clearAllNPCs()
    
    -- Clean up subsystems
    if self.interactionUI and self.interactionUI.delete then
        self.interactionUI:delete()
    end
end