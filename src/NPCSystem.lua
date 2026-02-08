-- =========================================================
-- TODO / FUTURE VISION
-- =========================================================
-- IMPLEMENTED FEATURES (v0.1):
-- [x] Building-based NPC spawning (non-player placeables)
-- [x] Multiplayer sync via NPCStateSyncEvent (5-second intervals)
-- [x] Console commands (npcStatus, npcList, npcSpawn, npcReset)
-- [x] Field assignment via g_fieldManager (nearest field detection)
-- [x] Player position detection (4 fallback methods: g_localPlayer, mission.player, controlledVehicle, camera)
-- [x] Subsystem architecture (Entity, AI, Scheduler, Relationship, Favor, InteractionUI, Settings, GUI)
-- [x] NPC data structure (personality, age, home position, assigned field, vehicles, relationship)
-- [x] Basic AI state machine (idle, traveling, working)
-- [x] Proximity detection and interaction flags
-- [x] Relationship tracking (0-100 scale)
-- [x] Favor cooldown system
-- [x] Sequential name/personality assignment (prevents duplicates)
-- [x] Delayed initialization (waits for mission start + terrain)
-- [x] Settings integration (enabled, maxNPCs, debugMode, showNotifications, showNames, enableFavors)
--
-- PERSISTENCE & SAVE SYSTEM:
-- [x] NPC persistence across save/load (saveToXMLFile/loadFromXMLFile)
-- [x] Save NPC state to savegame XML (positions, relationships, active favors, personality modifiers)
-- [x] Load NPC state from savegame XML (restore NPCs at saved positions via uniqueId/name matching)
-- [x] Preserve favor progress across sessions (via NPCFavorSystem:restoreFavor)
-- [x] Preserve relationship levels across sessions
-- [ ] Auto-save NPC data every 30 seconds (currently only saves on manual save)
-- [ ] Migration system for savegame format changes
--
-- SPAWNING & POPULATION DYNAMICS:
-- [ ] NPC spawning at specific building types (shops, gas stations, production points)
-- [ ] Role-based spawning (shopkeeper at shop, mechanic at garage, farmer at farm)
-- [ ] Dynamic NPC population (new NPCs arrive over time, some leave/move away)
-- [ ] NPC lifecycle (birth/arrival, aging, retirement, death/departure)
-- [ ] Population density settings (rural vs urban areas)
-- [ ] Random events (new family moves to town, NPC relocates)
-- [ ] NPC migration between farms/towns
--
-- ECONOMY & OWNERSHIP:
-- [ ] NPC economy (NPCs buy/sell at shops, own property, earn/spend money)
-- [ ] NPC-owned vehicles (visible in world, can be borrowed/rented)
-- [ ] NPC-owned fields (compete with player for harvest/sales)
-- [ ] NPC bank accounts (track wealth, debt, credit)
-- [ ] NPC shopping behavior (buy equipment, upgrades, consumables)
-- [ ] NPC loans (borrow from player or bank)
-- [ ] NPC property ownership (houses, barns, land)
--
-- EMPLOYMENT & HIRING:
-- [ ] Player can hire NPCs as farmhands (permanent workers)
-- [ ] NPC wage system (hourly/daily pay, bonuses)
-- [ ] NPC skill levels (improve over time with experience)
-- [ ] NPC work schedules (shifts, breaks, overtime)
-- [ ] NPC task assignment (plow field, harvest, delivery)
-- [ ] NPC performance tracking (efficiency, quality, reliability)
-- [ ] NPC can quit if mistreated (low pay, overwork, bad relationship)
-- [ ] NPC can be fired (severance pay, reputation impact)
--
-- QUESTS & STORY:
-- [ ] NPC quest chains (multi-step favor sequences with story)
-- [ ] Quest prerequisites (relationship level, completed favors, items)
-- [ ] Quest rewards (money, items, relationship boost, unlocks)
-- [ ] Quest branching (player choices affect outcomes)
-- [ ] Quest failures (time limits, wrong choices, consequences)
-- [ ] Story arcs (seasonal events, character development, community goals)
-- [ ] Reputation system (town-wide opinion affects all NPCs)
--
-- CONFIGURATION & MODDING:
-- [ ] Settings UI integration (in-game settings page for NPC mod)
-- [ ] XML-based NPC definitions (load names, personalities, models from config)
-- [ ] Custom NPC templates (modders can add new NPC types)
-- [ ] Localization support (translate NPC names, dialog, quests)
-- [ ] NPC model customization (clothing, appearance, accessories)
-- [ ] Building type definitions (categorize placeables for role assignment)
-- [ ] Economy config (price multipliers, wage rates, loan terms)
--
-- ADVANCED AI & BEHAVIOR:
-- [ ] NPC daily schedules (wake, work, lunch, socialize, sleep)
-- [ ] NPC social interactions (talk to each other, form friendships/rivalries)
-- [ ] NPC vehicle usage (drive tractors, trucks, cars)
-- [ ] NPC pathfinding improvements (avoid obstacles, use roads)
-- [ ] NPC animations (wave, work, talk, eat, sleep)
-- [ ] NPC needs (hunger, fatigue, happiness)
-- [ ] NPC hobbies (fishing, sports, gardening)
-- [ ] Weather response (seek shelter in rain, wear coat in winter)
--
-- VISUAL & UI ENHANCEMENTS:
-- [ ] NPC 3D models (actual characters, not placeholders)
-- [ ] Map icons for NPC locations (color-coded by relationship)
-- [ ] NPC info panel (click NPC to see stats, history, active quests)
-- [ ] Relationship progression UI (visual meter, milestones)
-- [ ] Favor board UI (see all available favors in town)
-- [ ] NPC speech bubbles (thoughts, greetings, status updates)
-- [ ] Photo mode (take pictures with NPCs, share on social wall)
--
-- MULTIPLAYER ENHANCEMENTS:
-- [ ] Per-player NPC relationships (each player has own relationship values)
-- [ ] Co-op favor completion (multiple players work together on favor)
-- [ ] Competitive favors (race to complete, best reward to winner)
-- [ ] NPC chat messages (NPCs comment in multiplayer chat)
-- [ ] Admin controls (host can spawn/remove/configure NPCs)
--
-- PERFORMANCE & OPTIMIZATION:
-- [ ] NPC LOD system (reduce updates for distant NPCs)
-- [ ] Spatial partitioning (only update NPCs in active cells)
-- [ ] Async pathfinding (don't block main thread)
-- [ ] Entity pooling (reuse NPC objects instead of destroy/create)
-- [ ] Network optimization (delta sync, compression)
-- [ ] Profiling tools (measure NPC system performance impact)
--
-- INTEGRATION WITH OTHER MODS:
-- [ ] Courseplay integration (NPCs can use Courseplay for fieldwork)
-- [ ] AutoDrive integration (NPCs use AutoDrive routes)
-- [ ] Seasons integration (NPC behavior changes with seasons)
-- [ ] Economy mods integration (sync prices, market data)
-- [ ] Placeable mods integration (recognize custom building types)
--
-- DEBUGGING & DEVELOPER TOOLS:
-- [ ] NPC debug overlay (show AI state, path, target in 3D)
-- [ ] NPC spawn editor (place NPCs in editor, save to config)
-- [ ] AI behavior debugger (visualize state machine transitions)
-- [ ] Performance profiler (track update times, memory usage)
-- [ ] Network debugger (monitor sync events, bandwidth)
-- [ ] Savegame inspector (view/edit NPC data in savegame)
--
-- =========================================================
-- FS25 NPC Favor Mod - Main NPC System (Coordinator)
-- =========================================================
-- Central hub that owns and coordinates all NPC subsystems:
--   - NPCEntity          (3D models, map icons, visibility)
--   - NPCAI              (state machine, pathfinding, decisions)
--   - NPCScheduler       (daily routines, timed events, seasons)
--   - NPCRelationshipManager (friendship levels, gifts, decay)
--   - NPCFavorSystem     (favor generation, tracking, completion)
--   - NPCInteractionUI   (world-space HUD, dialog helpers)
--   - NPCSettingsIntegration (user settings bridge)
--   - NPCFavorGUI        (dialog XML loader)
--
-- Lifecycle: new() → onMissionLoaded() → [delayed init] → initializeNPCs()
--            → update() each frame → delete() on shutdown
--
-- Multiplayer: Server runs full simulation + periodic sync via
--   NPCStateSyncEvent. Clients receive state and render only.
--
-- Time convention: FS25 passes dt in milliseconds. NPCSystem:update()
--   converts to seconds (dt = dt / 1000) before passing to subsystems.
-- =========================================================

NPCSystem = {}
NPCSystem_mt = Class(NPCSystem)

--- Create a new NPCSystem coordinator.
-- @param mission       g_currentMission reference
-- @param modDirectory  Mod directory path (with trailing slash)
-- @param modName       Mod name string
-- @return NPCSystem instance
function NPCSystem.new(mission, modDirectory, modName)
    print("[NPCSystem] Creating new NPCSystem instance")
    local self = setmetatable({}, NPCSystem_mt)

    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName

    -- Initialize subsystems FIRST with safe defaults
    print("[NPCSystem] Initializing subsystems...")
    self.settings = NPCSettings.new()
    
    -- NPC name/personality lists with index counter for unique assignment
    self.npcNameIndex = 0
    self.npcPersonalityIndex = 0

    self.config = {
        getNPCName = function()
            local names = {
                "Old MacDonald", "Farmer Joe", "Mrs. Henderson",
                "Young Peter", "Anna Schmidt", "Hans Bauer",
                "Wilhelm Braun", "Maria Stein"
            }
            self.npcNameIndex = self.npcNameIndex + 1
            return names[((self.npcNameIndex - 1) % #names) + 1]
        end,
        getRandomNPCName = function()
            -- Alias for backward compat - uses sequential assignment
            return self.config.getNPCName()
        end,
        getRandomPersonality = function()
            local personalities = {"hardworking", "lazy", "social", "generous", "grumpy"}
            self.npcPersonalityIndex = self.npcPersonalityIndex + 1
            return personalities[((self.npcPersonalityIndex - 1) % #personalities) + 1]
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
    
    -- Core subsystems - instantiate the REAL classes
    self.entityManager = NPCEntity.new(self)
    self.aiSystem = NPCAI.new(self)
    self.scheduler = NPCScheduler.new(self)
    self.relationshipManager = NPCRelationshipManager.new(self)
    self.favorSystem = NPCFavorSystem.new(self)
    self.interactionUI = NPCInteractionUI.new(self)
    self.settingsIntegration = NPCSettingsIntegration.new(self)

    self.gui = NPCFavorGUI.new(self)

    self.dailyEvents = {}
    self.scheduledNPCInteractions = {}
    self.lastScheduleUpdate = 0
    self.scheduleUpdateInterval = 1000
    self.eventIdCounter = 1
    
    -- Multiplayer
    self.isServer = (g_server ~= nil)
    self.syncTimer = 0
    self.SYNC_INTERVAL = 5  -- seconds (dt is converted to seconds)
    self.syncDirty = false

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

    -- Load saved settings from disk
    pcall(function() self.settings:load() end)

    self.initializing = true
    
    if self.settings.debugMode then
        print("[NPC Favor] Starting mission-loaded initialization...")
    end
    
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
                
                if self.settings.debugMode then
                    print("[NPC Favor] All checks passed, initializing NPCs...")
                end
                
                -- Initialize NPCs (fresh spawn)
                self:initializeNPCs()

                -- Restore saved state (relationships, positions, favor history)
                local missionInfo = nil
                if g_currentMission and g_currentMission.missionInfo then
                    missionInfo = g_currentMission.missionInfo
                elseif g_currentMission and g_currentMission.savegameDirectory then
                    missionInfo = { savegameDirectory = g_currentMission.savegameDirectory }
                end
                if missionInfo then
                    self:loadFromXMLFile(missionInfo)
                end

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
                print("[NPC Favor] Initialized with " .. tostring(self.npcCount) .. " NPCs")
                
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
    if NPCFavorGUI then
        self.gui = NPCFavorGUI.new(self)
        print("[NPCSystem] GUI system initialized")
    else
        print("[NPC Favor] ERROR: NPCFavorGUI class not found")
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
            
            if self.settings.debugMode then
                print(string.format("[NPC Favor] NPC %d: %s at (%.0f, %.0f, %.0f)",
                    i, npc.name, location.x, location.y, location.z))
            end
        end
    end
end

--- Set up an NPC's home position, field assignment, vehicles, AI state, and entity.
-- @param npc       NPC data table (from createNPCAtLocation)
-- @param location  Spawn location table {x, y, z, building, buildingName}
-- @param npcId     Sequential NPC index
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

    -- Store home building reference from spawn location
    npc.homeBuilding = (location and location.building) or nil
    npc.homeBuildingName = (location and location.buildingName) or "Unknown"

    -- Guard against nil location for field lookup
    local locX = (location and location.x) or 0
    local locZ = (location and location.z) or 0
    npc.assignedField = self:findNearestField(locX, locZ, npcId)
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

--- Find spawn locations by enumerating non-player-owned placeables.
-- Filters out fences, deleted objects, and player-owned buildings.
-- NPCs are distributed round-robin across buildings with 3-8m offsets.
-- Falls back to terrain center if no buildings are found.
-- @return table  Array of location tables {x, y, z, building, buildingName, ...}
function NPCSystem:findNPCSpawnLocations()
    local locations = {}
    local playerFarmId = 1 -- Default player farm

    if g_currentMission and g_currentMission.getFarmId then
        playerFarmId = g_currentMission:getFarmId()
    end

    -- Collect non-player buildings as candidate spawn points
    local buildings = {}
    if g_currentMission and g_currentMission.placeableSystem then
        local placeables = g_currentMission.placeableSystem.placeables
        if not placeables and g_currentMission.placeableSystem.getPlaceables then
            placeables = g_currentMission.placeableSystem:getPlaceables()
        end

        for _, placeable in pairs(placeables or {}) do
            -- Skip deleted/invalid
            if not placeable.markedForDeletion and not placeable.isDeleted then
                -- Skip fences and trivial objects
                local typeName = placeable.typeName or ""
                if typeName ~= "newFence" and typeName ~= "fence" then
                    -- Skip player-owned buildings
                    local isPlayerOwned = (placeable.ownerFarmId == playerFarmId)
                    if not isPlayerOwned and placeable.rootNode then
                        local ok, x, y, z = pcall(getWorldTranslation, placeable.rootNode)
                        if ok and x then
                            table.insert(buildings, {
                                x = x, y = y, z = z,
                                placeable = placeable,
                                name = (placeable.getName and placeable:getName()) or "Building"
                            })
                        end
                    end
                end
            end
        end
    end

    if self.settings.debugMode then
        print(string.format("[NPC Favor] Found %d non-player buildings for NPC spawning", #buildings))
    end

    -- Fallback: if no buildings found, use terrain center
    if #buildings == 0 then
        local cx = (g_currentMission and g_currentMission.terrainSize or 2048) / 2
        table.insert(buildings, { x = cx, y = 0, z = cx, placeable = nil, name = "MapCenter" })
    end

    -- Assign NPCs to buildings (round-robin if more NPCs than buildings)
    local neededLocations = self.settings.maxNPCs
    for i = 1, neededLocations do
        local building = buildings[((i - 1) % #buildings) + 1]
        -- Offset each NPC slightly from the building center (3-8m)
        local angle = (i / neededLocations) * math.pi * 2
        local offset = 3 + math.random() * 5
        local spawnX = building.x + math.cos(angle) * offset
        local spawnZ = building.z + math.sin(angle) * offset

        table.insert(locations, {
            x = spawnX,
            y = 0,
            z = spawnZ,
            building = building,
            buildingName = building.name,
            isPredefined = true,
            isResidential = false
        })
    end

    -- Validate terrain heights
    if g_currentMission and g_currentMission.terrainRootNode then
        for _, loc in ipairs(locations) do
            local success, terrainHeight = pcall(getTerrainHeightAtWorldPos,
                g_currentMission.terrainRootNode, loc.x, 0, loc.z)
            if success and terrainHeight then
                loc.y = terrainHeight + 0.5
            end
        end
    end

    return locations
end

--- Create an NPC data table at a given location with randomized properties.
-- Personality modifiers affect movementSpeed and AI behavior weights.
-- @param location  Location table {x, y, z}
-- @return table    NPC data table, or nil on error
function NPCSystem:createNPCAtLocation(location)
    if not location then
        print("[NPC Favor] ERROR: No location provided for NPC creation")
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

--- Find the nearest field to a world position using g_fieldManager.
-- Tries 3 field-center patterns: fieldArea.fieldCenterX, posX/posZ, rootNode.
-- @param x      World X position
-- @param z      World Z position
-- @param npcId  NPC ID (for debug logging)
-- @return table  {id, center={x,y,z}, size} or nil if no fields found
function NPCSystem:findNearestField(x, z, npcId)
    if not g_fieldManager or not g_fieldManager.fields then
        return nil
    end

    local nearest = nil
    local nearestDist = math.huge

    for _, field in pairs(g_fieldManager.fields) do
        -- Try multiple field center location patterns used by FS25
        local cx, cz = nil, nil

        if field.fieldArea and field.fieldArea.fieldCenterX then
            cx = field.fieldArea.fieldCenterX
            cz = field.fieldArea.fieldCenterZ
        elseif field.posX and field.posZ then
            cx = field.posX
            cz = field.posZ
        elseif field.rootNode then
            local ok, fx, _, fz = pcall(getWorldTranslation, field.rootNode)
            if ok and fx then
                cx = fx
                cz = fz
            end
        end

        if cx and cz then
            local dx = cx - x
            local dz = cz - z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < nearestDist then
                nearestDist = dist
                nearest = {
                    id = field.fieldId or 0,
                    center = { x = cx, y = 0, z = cz },
                    size = (field.fieldArea and field.fieldArea.fieldArea) or 1
                }
            end
        end
    end

    if nearest and self.settings.debugMode then
        print(string.format("[NPC Favor] Field #%d found for NPC %d at dist %.0fm",
            nearest.id, npcId or 0, nearestDist))
    end

    return nearest
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

--- Main update loop, called every frame by the mission.
-- Converts dt from milliseconds to seconds, then dispatches to subsystems.
-- Server: runs full simulation + periodic multiplayer sync.
-- Client: UI rendering + proximity checks using synced positions.
-- @param dt  Delta time in milliseconds (from FS25 engine)
function NPCSystem:update(dt)
    if not self.settings.enabled or not self.isInitialized then
        return
    end

    -- FS25 passes dt in milliseconds - convert to seconds for all timers/movement
    dt = dt / 1000

    self.updateCounter = self.updateCounter + 1

    -- Both server and client need player position for proximity checks / UI
    self:updatePlayerPosition()

    if self.isServer then
        -- SERVER: Full simulation
        self:updateNPCs(dt)                    -- AI states + entity positions
        self.scheduler:update(dt)              -- Time tracking + daily events
        self.favorSystem:update(dt)            -- Favor timers + generation
        self.relationshipManager:update(dt)    -- Mood decay + behavior updates
        self.interactionUI:update(dt)          -- Hint display + dialog (server-host only)

        -- Periodic sync to clients
        self.syncTimer = self.syncTimer + dt
        if self.syncTimer >= self.SYNC_INTERVAL or self.syncDirty then
            self.syncTimer = 0
            self.syncDirty = false
            if NPCStateSyncEvent then
                NPCStateSyncEvent.broadcastState()
            end
        end

        -- Debug info occasionally
        if self.updateCounter % 300 == 0 then
            print(string.format("[NPC Favor] Update #%d - Active NPCs: %d (server)",
                self.updateCounter, self.npcCount))
        end
    else
        -- CLIENT: Display only, state comes from server sync events
        self.interactionUI:update(dt)          -- UI rendering for this client

        -- NPC proximity checks use synced positions
        for _, npc in ipairs(self.activeNPCs) do
            self:checkPlayerProximity(npc)
        end
    end
end

function NPCSystem:updatePlayerPosition()
    if not g_currentMission then
        self.playerPositionValid = false
        return
    end

    -- Periodic diagnostic (only when debugMode is on)
    self._playerDiagCounter = (self._playerDiagCounter or 0) + 1
    local shouldLog = self.settings.debugMode and
        ((self._playerDiagCounter <= 3) or (self._playerDiagCounter % 600 == 0))

    -- Method 1: g_localPlayer:getPosition() — proven pattern from FieldServiceKit (UsedPlus)
    if g_localPlayer then
        local x, y, z

        if g_localPlayer.getPosition then
            x, y, z = g_localPlayer:getPosition()
        elseif g_localPlayer.rootNode and g_localPlayer.rootNode ~= 0 then
            local ok
            ok, x, y, z = pcall(getWorldTranslation, g_localPlayer.rootNode)
            if not ok then x = nil end
        end

        if x then
            self.playerPosition.x = x
            self.playerPosition.y = y
            self.playerPosition.z = z
            self.playerPositionValid = true
            if shouldLog then
                print(string.format("[NPC Favor] PlayerPos via g_localPlayer: (%.0f, %.0f, %.0f)", x, y, z))
            end
            return
        end

        -- Player is in vehicle — get vehicle position
        if g_localPlayer.getIsInVehicle and g_localPlayer:getIsInVehicle() then
            local vehicle = g_localPlayer:getCurrentVehicle()
            if vehicle and vehicle.rootNode and vehicle.rootNode ~= 0 then
                local ok
                ok, x, y, z = pcall(getWorldTranslation, vehicle.rootNode)
                if ok and x then
                    self.playerPosition.x = x
                    self.playerPosition.y = y
                    self.playerPosition.z = z
                    self.playerPositionValid = true
                    if shouldLog then
                        print(string.format("[NPC Favor] PlayerPos via g_localPlayer.vehicle: (%.0f, %.0f, %.0f)", x, y, z))
                    end
                    return
                end
            end
        end
    end

    -- Method 2: g_currentMission.player.rootNode
    local player = g_currentMission.player
    if player and player.rootNode and player.rootNode ~= 0 then
        local ok, x, y, z = pcall(getWorldTranslation, player.rootNode)
        if ok and x then
            self.playerPosition.x = x
            self.playerPosition.y = y
            self.playerPosition.z = z
            self.playerPositionValid = true
            if shouldLog then
                print(string.format("[NPC Favor] PlayerPos via mission.player: (%.0f, %.0f, %.0f)", x, y, z))
            end
            return
        end
    end

    -- Method 3: Controlled vehicle
    local vehicle = g_currentMission.controlledVehicle
    if vehicle and vehicle.rootNode and vehicle.rootNode ~= 0 then
        local ok, x, y, z = pcall(getWorldTranslation, vehicle.rootNode)
        if ok and x then
            self.playerPosition.x = x
            self.playerPosition.y = y
            self.playerPosition.z = z
            self.playerPositionValid = true
            if shouldLog then
                print(string.format("[NPC Favor] PlayerPos via controlledVehicle: (%.0f, %.0f, %.0f)", x, y, z))
            end
            return
        end
    end

    -- Method 4: Camera position (last resort)
    if getCamera then
        local ok, cameraNode = pcall(getCamera)
        if ok and cameraNode and cameraNode ~= 0 then
            local ok2, x, y, z = pcall(getWorldTranslation, cameraNode)
            if ok2 and x then
                self.playerPosition.x = x
                self.playerPosition.y = y
                self.playerPosition.z = z
                self.playerPositionValid = true
                if shouldLog then
                    print(string.format("[NPC Favor] PlayerPos via camera: (%.0f, %.0f, %.0f)", x, y, z))
                end
                return
            end
        end
    end

    self.playerPositionValid = false
    if shouldLog then
        print(string.format("[NPC Favor] PlayerPos FAILED! g_localPlayer=%s hasGetPosition=%s rootNode=%s | mission.player=%s | controlledVehicle=%s",
            tostring(g_localPlayer ~= nil),
            tostring(g_localPlayer and g_localPlayer.getPosition ~= nil),
            tostring(g_localPlayer and g_localPlayer.rootNode),
            tostring(player ~= nil),
            tostring(vehicle ~= nil)))
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
    if distance < 5 then
        npc.canInteract = true
        npc.interactionDistance = distance

        -- Show world-space "Press [E] to talk" hint above NPC head
        if self.interactionUI then
            self.interactionUI:showInteractionHint(npc, distance)
        end
    else
        npc.canInteract = false

        -- Hide hint if this NPC was the one being shown
        if self.interactionUI and self.interactionUI.interactionHintNPC == npc then
            self.interactionUI:hideInteractionHint()
        end
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
    elseif self.settings.debugMode then
        print(string.format("[NPC Favor] %s: %s", title, message))
    end
end

function NPCSystem:consoleCommandStatus()
    local gameTime = self:getCurrentGameTime()
    local status = "=== NPC Favor System Status ===\n"
    status = status .. string.format("Enabled: %s | Initialized: %s | Debug: %s\n",
        tostring(self.settings.enabled), tostring(self.isInitialized), tostring(self.settings.debugMode))
    status = status .. string.format("Active NPCs: %d/%d | Nearby: %d | Updates: %d\n",
        self.npcCount, self.settings.maxNPCs, #self.nearbyNPCs, self.updateCounter)

    -- Player position
    if self.playerPositionValid then
        status = status .. string.format("Player: (%.0f, %.0f, %.0f)\n",
            self.playerPosition.x, self.playerPosition.y, self.playerPosition.z)
    else
        status = status .. "Player: position unknown\n"
    end

    -- Game time info
    if g_currentMission and g_currentMission.environment then
        local env = g_currentMission.environment
        local dayTime = env.dayTime or 0
        local hours = math.floor(dayTime / 3600000)
        local minutes = math.floor((dayTime % 3600000) / 60000)
        status = status .. string.format("Game Time: %02d:%02d | Day: %s\n",
            hours, minutes, tostring(env.currentDay or "?"))
    end

    -- Subsystem health
    status = status .. string.format("Subsystems: Entity=%s AI=%s Sched=%s Rel=%s Favor=%s UI=%s\n",
        tostring(self.entityManager ~= nil), tostring(self.aiSystem ~= nil),
        tostring(self.scheduler ~= nil), tostring(self.relationshipManager ~= nil),
        tostring(self.favorSystem ~= nil), tostring(self.interactionUI ~= nil))

    -- Settings snapshot
    status = status .. string.format("Settings: names=%s notif=%s favors=%s\n",
        tostring(self.settings.showNames), tostring(self.settings.showNotifications),
        tostring(self.settings.enableFavors))

    -- Per-NPC detail
    status = status .. "\n--- NPCs ---\n"
    for i, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            -- Distance from player
            local dist = "?"
            if self.playerPositionValid then
                local dx = npc.position.x - self.playerPosition.x
                local dz = npc.position.z - self.playerPosition.z
                dist = string.format("%.0f", math.sqrt(dx * dx + dz * dz))
            end

            -- Time since last update
            local age = "never"
            if npc.lastUpdateTime and npc.lastUpdateTime > 0 and gameTime > 0 then
                local ms = gameTime - npc.lastUpdateTime
                if ms < 2000 then
                    age = "LIVE"
                else
                    age = string.format("%.1fs ago", ms / 1000)
                end
            end

            status = status .. string.format(
                "%d. %s [%s] | pos=(%.0f,%.0f,%.0f) | dist=%sm | action=%s | ai=%s | rel=%d | upd=%s\n",
                i, npc.name, npc.personality,
                npc.position.x, npc.position.y, npc.position.z,
                dist, npc.currentAction or "?", npc.aiState or "?",
                npc.relationship or 0, age)

            -- Show favor stats if any activity
            if (npc.totalFavorsCompleted or 0) > 0 or (npc.totalFavorsFailed or 0) > 0 then
                status = status .. string.format("   Favors: %d done / %d failed | cooldown=%.0f\n",
                    npc.totalFavorsCompleted or 0, npc.totalFavorsFailed or 0, npc.favorCooldown or 0)
            end
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
        return "No active NPCs. System initialized: " .. tostring(self.isInitialized)
    end

    local gameTime = self:getCurrentGameTime()
    local list = string.format("=== Active NPCs (%d/%d) | Updates: %d ===\n",
        self.npcCount, self.settings.maxNPCs, self.updateCounter)
    list = list .. string.format("%-4s %-18s %-11s %-8s %-8s %5s %3s %s\n",
        "#", "Name", "Personality", "Action", "AI", "Dist", "Rel", "Updated")
    list = list .. string.rep("-", 82) .. "\n"

    for i, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            -- Distance from player
            local dist = "  -"
            if self.playerPositionValid then
                local dx = npc.position.x - self.playerPosition.x
                local dz = npc.position.z - self.playerPosition.z
                dist = string.format("%4.0f", math.sqrt(dx * dx + dz * dz))
            end

            -- Time since last update
            local upd = "never"
            if npc.lastUpdateTime and npc.lastUpdateTime > 0 and gameTime > 0 then
                local ms = gameTime - npc.lastUpdateTime
                if ms < 2000 then
                    upd = "LIVE"
                else
                    upd = string.format("%.0fs", ms / 1000)
                end
            end

            list = list .. string.format("%-4d %-18s %-11s %-8s %-8s %4sm %3d %s\n",
                i,
                (npc.name or "?"):sub(1, 18),
                (npc.personality or "?"):sub(1, 11),
                (npc.currentAction or "?"):sub(1, 8),
                (npc.aiState or "?"):sub(1, 8),
                dist,
                npc.relationship or 0,
                upd)
        end
    end

    -- Footer with positions for findability
    list = list .. "\nPositions:\n"
    for i, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            list = list .. string.format("  %d. %s @ (%.0f, %.0f, %.0f)",
                i, npc.name, npc.position.x, npc.position.y, npc.position.z)
            if npc.homePosition then
                list = list .. string.format("  home=(%.0f, %.0f, %.0f)",
                    npc.homePosition.x, npc.homePosition.y, npc.homePosition.z)
            end
            if npc.homeBuildingName then
                list = list .. string.format("  bldg=%s", npc.homeBuildingName)
            end
            list = list .. "\n"
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
    self.initDone = false
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

-- =========================================================
-- Multiplayer: Sync Data Collection + Application
-- =========================================================

--[[
    Collect current NPC state for network sync (server only).
    @return array of NPC data tables
]]
function NPCSystem:collectSyncData()
    local data = {}
    for _, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            table.insert(data, {
                id = npc.id,
                name = npc.name or "",
                personality = npc.personality or "",
                x = npc.position.x or 0,
                y = npc.position.y or 0,
                z = npc.position.z or 0,
                aiState = npc.aiState or "idle",
                relationship = npc.relationship or 50,
                isActive = npc.isActive,
                currentAction = npc.currentAction or "idle"
            })
        end
    end
    return data
end

--[[
    Apply NPC state received from server (client only).
    Updates existing NPCs or creates placeholders for new ones.
    Removes NPCs not present in sync data.
    @param npcDataArray - Array of NPC data from NPCStateSyncEvent
]]
function NPCSystem:applyNetworkState(npcDataArray)
    if not npcDataArray then return end

    -- Build lookup of received NPC IDs
    local receivedIds = {}
    for _, entry in ipairs(npcDataArray) do
        receivedIds[entry.id] = true

        -- Find existing NPC or create placeholder
        local npc = self:getNPCById(entry.id)
        if npc then
            -- Update existing NPC
            npc.position.x = entry.x
            npc.position.y = entry.y
            npc.position.z = entry.z
            npc.aiState = entry.aiState
            npc.currentAction = entry.currentAction
            npc.relationship = entry.relationship
            npc.isActive = entry.isActive
        else
            -- Create placeholder NPC (client doesn't run full init)
            local newNPC = {
                id = entry.id,
                name = entry.name,
                personality = entry.personality,
                position = { x = entry.x, y = entry.y, z = entry.z },
                rotation = { x = 0, y = 0, z = 0 },
                isActive = entry.isActive,
                currentAction = entry.currentAction,
                aiState = entry.aiState,
                relationship = entry.relationship,
                favorCooldown = 0,
                canInteract = false,
                interactionDistance = 999,
                homePosition = { x = entry.x, y = entry.y, z = entry.z },
                movementSpeed = 1.0,
                totalFavorsCompleted = 0,
                totalFavorsFailed = 0,
                lastUpdateTime = 0,
                entityId = nil
            }
            table.insert(self.activeNPCs, newNPC)
            self.npcCount = self.npcCount + 1
        end
    end

    -- Remove NPCs not in sync data (they were removed on server)
    local i = 1
    while i <= #self.activeNPCs do
        local npc = self.activeNPCs[i]
        if not receivedIds[npc.id] then
            self.entityManager:removeNPCEntity(npc)
            table.remove(self.activeNPCs, i)
            self.npcCount = self.npcCount - 1
        else
            i = i + 1
        end
    end
end

--[[
    Find an NPC by their integer ID.
    @param id - NPC ID
    @return NPC table or nil
]]
function NPCSystem:getNPCById(id)
    for _, npc in ipairs(self.activeNPCs) do
        if npc.id == id then
            return npc
        end
    end
    return nil
end

-- =========================================================
-- Multiplayer: Server-Side Interaction Handlers
-- Called from NPCInteractionEvent.execute() after validation
-- =========================================================

function NPCSystem:serverAcceptFavor(npc, farmId)
    -- Rate limiting: check cooldown
    if npc.favorCooldown > 0 then
        if self.settings.debugMode then
            print(string.format("[NPC Favor] Favor accept blocked: %s has cooldown %.0f", npc.name, npc.favorCooldown))
        end
        return false
    end

    -- Delegate to favor system
    if self.favorSystem and self.favorSystem.acceptFavor then
        local success = self.favorSystem:acceptFavor(npc.id, farmId)
        if success then
            self.syncDirty = true
        end
        return success
    end
    return false
end

function NPCSystem:serverCompleteFavor(npc, farmId)
    if self.favorSystem and self.favorSystem.completeFavor then
        local success = self.favorSystem:completeFavor(npc.id, farmId)
        if success then
            -- Update relationship on favor completion
            self.relationshipManager:updateRelationship(npc.id, 15, "FAVOR_COMPLETED")
            self.syncDirty = true
        end
        return success
    end
    return false
end

function NPCSystem:serverAbandonFavor(npc, farmId)
    if self.favorSystem and self.favorSystem.abandonFavor then
        local success = self.favorSystem:abandonFavor(npc.id, farmId)
        if success then
            -- Negative relationship impact
            self.relationshipManager:updateRelationship(npc.id, -5, "FAVOR_ABANDONED")
            self.syncDirty = true
        end
        return success
    end
    return false
end

function NPCSystem:serverGiveGift(npc, farmId, giftValue, giftType)
    if self.relationshipManager and self.relationshipManager.giveGiftToNPC then
        local success = self.relationshipManager:giveGiftToNPC(npc.id, giftType or "money", giftValue)
        if success then
            self.syncDirty = true
        end
        return success
    end
    return false
end

function NPCSystem:serverUpdateRelationship(npc, farmId, change, reason)
    if self.relationshipManager then
        local success = self.relationshipManager:updateRelationship(npc.id, change, reason or "DAILY_INTERACTION")
        if success then
            self.syncDirty = true
        end
        return success
    end
    return false
end

-- =========================================================
-- Save/Load Persistence
-- =========================================================
-- File: savegameX/npc_favor.xml
-- Saves: NPC positions, relationships, favor stats, unique IDs
-- Follows UsedPlus pattern: XMLFile.create/loadIfExists

local NPC_SAVE_FILE = "npc_favor.xml"
local NPC_SAVE_ROOT = "npcFavor"

--- Save all NPC state to XML file in savegame directory.
-- Called from FSCareerMissionInfo.saveToXMLFile hook in main.lua.
-- @param missionInfo  FS25 missionInfo table (has savegameDirectory)
function NPCSystem:saveToXMLFile(missionInfo)
    local savegameDirectory = missionInfo and missionInfo.savegameDirectory
    if not savegameDirectory then
        return
    end

    if not self.isInitialized or self.npcCount == 0 then
        return
    end

    local filePath = savegameDirectory .. "/" .. NPC_SAVE_FILE

    -- XMLFile.create overwrites existing file
    local xmlFile = XMLFile.create("npcFavorXML", filePath, NPC_SAVE_ROOT)
    if xmlFile == nil then
        print("[NPC Favor] ERROR: Failed to create save file: " .. filePath)
        return
    end

    -- Save mod version for future migration
    xmlFile:setString(NPC_SAVE_ROOT .. "#version", "1.0.0.0")
    xmlFile:setInt(NPC_SAVE_ROOT .. "#npcCount", self.npcCount)

    -- Save each NPC
    local npcIndex = 0
    for _, npc in ipairs(self.activeNPCs) do
        if npc.isActive then
            local npcKey = string.format(NPC_SAVE_ROOT .. ".npcs.npc(%d)", npcIndex)

            -- Identity
            xmlFile:setString(npcKey .. "#uniqueId", npc.uniqueId or "")
            xmlFile:setString(npcKey .. "#name", npc.name or "")
            xmlFile:setString(npcKey .. "#personality", npc.personality or "")
            xmlFile:setInt(npcKey .. "#age", npc.age or 30)

            -- Position
            xmlFile:setFloat(npcKey .. ".position#x", npc.position.x or 0)
            xmlFile:setFloat(npcKey .. ".position#y", npc.position.y or 0)
            xmlFile:setFloat(npcKey .. ".position#z", npc.position.z or 0)
            xmlFile:setFloat(npcKey .. ".rotation#y", npc.rotation.y or 0)

            -- Home position
            if npc.homePosition then
                xmlFile:setFloat(npcKey .. ".home#x", npc.homePosition.x or 0)
                xmlFile:setFloat(npcKey .. ".home#y", npc.homePosition.y or 0)
                xmlFile:setFloat(npcKey .. ".home#z", npc.homePosition.z or 0)
            end
            xmlFile:setString(npcKey .. ".home#buildingName", npc.homeBuildingName or "")

            -- Relationship & stats
            xmlFile:setInt(npcKey .. ".stats#relationship", npc.relationship or 50)
            xmlFile:setInt(npcKey .. ".stats#favorsCompleted", npc.totalFavorsCompleted or 0)
            xmlFile:setInt(npcKey .. ".stats#favorsFailed", npc.totalFavorsFailed or 0)
            xmlFile:setFloat(npcKey .. ".stats#favorCooldown", npc.favorCooldown or 0)

            -- AI state
            xmlFile:setString(npcKey .. ".ai#state", npc.aiState or "idle")
            xmlFile:setString(npcKey .. ".ai#action", npc.currentAction or "idle")

            -- Personality modifiers
            if npc.aiPersonalityModifiers then
                xmlFile:setFloat(npcKey .. ".personality#workEthic", npc.aiPersonalityModifiers.workEthic or 1.0)
                xmlFile:setFloat(npcKey .. ".personality#sociability", npc.aiPersonalityModifiers.sociability or 1.0)
                xmlFile:setFloat(npcKey .. ".personality#generosity", npc.aiPersonalityModifiers.generosity or 1.0)
                xmlFile:setFloat(npcKey .. ".personality#punctuality", npc.aiPersonalityModifiers.punctuality or 1.0)
            end

            -- Visual
            xmlFile:setInt(npcKey .. ".visual#appearanceSeed", npc.appearanceSeed or 1)
            xmlFile:setFloat(npcKey .. ".visual#movementSpeed", npc.movementSpeed or 1.0)

            npcIndex = npcIndex + 1
        end
    end

    -- Save active favors from the favor system
    if self.favorSystem then
        local activeFavors = self.favorSystem:getActiveFavors()
        if activeFavors then
            local favorIndex = 0
            for _, favor in ipairs(activeFavors) do
                local favorKey = string.format(NPC_SAVE_ROOT .. ".favors.favor(%d)", favorIndex)
                xmlFile:setInt(favorKey .. "#npcId", favor.npcId or 0)
                xmlFile:setString(favorKey .. "#npcName", favor.npcName or "")
                xmlFile:setString(favorKey .. "#type", favor.type or "")
                xmlFile:setString(favorKey .. "#description", favor.description or "")
                xmlFile:setFloat(favorKey .. "#timeRemaining", favor.timeRemaining or 0)
                xmlFile:setInt(favorKey .. "#progress", favor.progress or 0)
                xmlFile:setFloat(favorKey .. "#reward", favor.reward or 0)
                favorIndex = favorIndex + 1
            end
        end
    end

    xmlFile:save()
    xmlFile:delete()

    if self.settings.debugMode then
        print(string.format("[NPC Favor] Saved %d NPCs to %s", npcIndex, filePath))
    end
end

--- Load saved NPC state from XML file, restoring relationships and positions.
-- Called after initializeNPCs() in the delayed init updater.
-- Matches saved NPCs to spawned NPCs by uniqueId or name.
-- @param missionInfo  FS25 missionInfo table (has savegameDirectory)
function NPCSystem:loadFromXMLFile(missionInfo)
    local savegameDirectory = missionInfo and missionInfo.savegameDirectory
    if not savegameDirectory then
        return
    end

    local filePath = savegameDirectory .. "/" .. NPC_SAVE_FILE

    -- loadIfExists returns nil for new games (no save file yet)
    local xmlFile = XMLFile.loadIfExists("npcFavorXML", filePath, NPC_SAVE_ROOT)
    if xmlFile == nil then
        if self.settings.debugMode then
            print("[NPC Favor] No save file found (new game)")
        end
        return
    end

    local savedVersion = xmlFile:getString(NPC_SAVE_ROOT .. "#version", "0.0.0.0")
    local savedNpcCount = xmlFile:getInt(NPC_SAVE_ROOT .. "#npcCount", 0)

    if self.settings.debugMode then
        print(string.format("[NPC Favor] Loading save file v%s with %d NPCs", savedVersion, savedNpcCount))
    end

    -- Build lookup tables for matching saved NPCs to spawned ones
    local npcByUniqueId = {}
    local npcByName = {}
    for _, npc in ipairs(self.activeNPCs) do
        if npc.uniqueId then
            npcByUniqueId[npc.uniqueId] = npc
        end
        if npc.name then
            npcByName[npc.name] = npc
        end
    end

    local restoredCount = 0

    -- Iterate saved NPCs and restore state
    xmlFile:iterate(NPC_SAVE_ROOT .. ".npcs.npc", function(_, npcKey)
        local uniqueId = xmlFile:getString(npcKey .. "#uniqueId", "")
        local name = xmlFile:getString(npcKey .. "#name", "")

        -- Match to existing NPC: prefer uniqueId, fall back to name
        local npc = npcByUniqueId[uniqueId] or npcByName[name]

        if npc then
            -- Restore position
            npc.position.x = xmlFile:getFloat(npcKey .. ".position#x", npc.position.x)
            npc.position.y = xmlFile:getFloat(npcKey .. ".position#y", npc.position.y)
            npc.position.z = xmlFile:getFloat(npcKey .. ".position#z", npc.position.z)
            npc.rotation.y = xmlFile:getFloat(npcKey .. ".rotation#y", npc.rotation.y)

            -- Restore home position
            if xmlFile:hasProperty(npcKey .. ".home#x") then
                npc.homePosition = npc.homePosition or {}
                npc.homePosition.x = xmlFile:getFloat(npcKey .. ".home#x", 0)
                npc.homePosition.y = xmlFile:getFloat(npcKey .. ".home#y", 0)
                npc.homePosition.z = xmlFile:getFloat(npcKey .. ".home#z", 0)
            end
            npc.homeBuildingName = xmlFile:getString(npcKey .. ".home#buildingName", npc.homeBuildingName or "")

            -- Restore relationship & stats (most important!)
            npc.relationship = xmlFile:getInt(npcKey .. ".stats#relationship", npc.relationship)
            npc.totalFavorsCompleted = xmlFile:getInt(npcKey .. ".stats#favorsCompleted", 0)
            npc.totalFavorsFailed = xmlFile:getInt(npcKey .. ".stats#favorsFailed", 0)
            npc.favorCooldown = xmlFile:getFloat(npcKey .. ".stats#favorCooldown", 0)

            -- Restore AI state
            npc.aiState = xmlFile:getString(npcKey .. ".ai#state", "idle")
            npc.currentAction = xmlFile:getString(npcKey .. ".ai#action", "idle")

            -- Restore personality modifiers
            if npc.aiPersonalityModifiers then
                npc.aiPersonalityModifiers.workEthic = xmlFile:getFloat(npcKey .. ".personality#workEthic", npc.aiPersonalityModifiers.workEthic)
                npc.aiPersonalityModifiers.sociability = xmlFile:getFloat(npcKey .. ".personality#sociability", npc.aiPersonalityModifiers.sociability)
                npc.aiPersonalityModifiers.generosity = xmlFile:getFloat(npcKey .. ".personality#generosity", npc.aiPersonalityModifiers.generosity)
                npc.aiPersonalityModifiers.punctuality = xmlFile:getFloat(npcKey .. ".personality#punctuality", npc.aiPersonalityModifiers.punctuality)
            end

            -- Restore visual properties
            npc.appearanceSeed = xmlFile:getInt(npcKey .. ".visual#appearanceSeed", npc.appearanceSeed)
            npc.movementSpeed = xmlFile:getFloat(npcKey .. ".visual#movementSpeed", npc.movementSpeed)

            -- Update entity position to match restored data
            self.entityManager:updateNPCEntity(npc, 0)

            restoredCount = restoredCount + 1
        end
    end)

    -- Restore active favors
    if self.favorSystem and self.favorSystem.restoreFavor then
        xmlFile:iterate(NPC_SAVE_ROOT .. ".favors.favor", function(_, favorKey)
            local favor = {
                npcId = xmlFile:getInt(favorKey .. "#npcId", 0),
                npcName = xmlFile:getString(favorKey .. "#npcName", ""),
                type = xmlFile:getString(favorKey .. "#type", ""),
                description = xmlFile:getString(favorKey .. "#description", ""),
                timeRemaining = xmlFile:getFloat(favorKey .. "#timeRemaining", 0),
                progress = xmlFile:getInt(favorKey .. "#progress", 0),
                reward = xmlFile:getFloat(favorKey .. "#reward", 0)
            }
            self.favorSystem:restoreFavor(favor)
        end)
    end

    xmlFile:delete()

    if self.settings.debugMode then
        print(string.format("[NPC Favor] Restored %d/%d NPCs from save", restoredCount, savedNpcCount))
    end
end

-- =========================================================
-- Cleanup
-- =========================================================

function NPCSystem:delete()
    print("[NPC Favor] Shutting down")

    -- Clean up NPCs
    self:clearAllNPCs()

    -- Clean up subsystems
    if self.interactionUI and self.interactionUI.delete then
        self.interactionUI:delete()
    end
end