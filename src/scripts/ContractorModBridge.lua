-- ============================================================
-- ContractorModBridge.lua
-- Integrates FS25_ContractorMod workers into the NPCFavor
-- relationship system. Each contractor worker appears as a
-- named NPC in the favor list so the player can build
-- relationships with their hired crew.
--
-- Detection:  ContractorMod.workers (class-level static table)
--             FS25 mods are sandboxed so g_contractormod (set via
--             getfenv(0) in ContractorMod's env) is not visible here.
--             ContractorMod.workers is on the Class() registered table
--             and accessible from the shared game environment.
-- Polling:    every 5 s — no event hooks exist in ContractorMod
-- 3D visuals: ContractorMod already renders workers; we only
--             add the favor/relationship layer, no entity spawn.
-- ============================================================

ContractorModBridge = {}
ContractorModBridge.__index = ContractorModBridge

local LOG_PREFIX = "[NPC Favor][ContractorBridge]"
local SYNC_INTERVAL = 5.0  -- seconds between worker list polls

function ContractorModBridge.new(npcSystem)
    local self = setmetatable({}, ContractorModBridge)
    self.npcSystem       = npcSystem
    self.isActive        = false
    -- Maps worker.index → npc.id for workers we've already registered
    self.contractorNPCMap = {}
    self.syncTimer       = 0
    return self
end

-- Returns a workers table if ContractorMod is active, else nil.
--
-- Both g_contractormod (instance) and ContractorMod (class) are set inside
-- ContractorMod's sandboxed mod environment and are NOT visible here.
-- We have filed an issue asking ContractorMod to expose workers via
-- g_currentMission so cross-mod access works properly.
--
-- For now we build a synthetic worker list from g_npcManager.nameToNPC:
-- ContractorMod registers "HELPER1"–"HELPER8" there (shared game object).
-- Names are "Worker N" until ContractorMod exposes the display names.
-- When g_currentMission.contractorWorkers is available (future), we use that.
function ContractorModBridge:getWorkers()
    -- Future: official bridge via g_currentMission (requested in issue)
    if g_currentMission ~= nil and g_currentMission.contractorWorkers ~= nil then
        return g_currentMission.contractorWorkers
    end
    -- Try direct class access (works if ContractorMod ever shares its env)
    if ContractorMod ~= nil and ContractorMod.workers ~= nil then
        return ContractorMod.workers
    end
    if g_contractormod ~= nil and g_contractormod.workers ~= nil then
        return g_contractormod.workers
    end
    -- Fallback: enumerate g_npcManager HELPER* entries (always shared)
    if g_npcManager == nil or g_npcManager.nameToNPC == nil then return nil end
    local workers = {}
    for i = 1, 8 do
        local helperName = "HELPER" .. i
        local npc = g_npcManager.nameToNPC[helperName]
        if npc ~= nil then
            -- Use current worker's real name for the active slot; generic for others
            local displayName
            if g_currentMission ~= nil and g_currentMission.nickname ~= nil
                and g_currentMission.nickname ~= "" then
                -- nickname is only the active worker; use it for slot matching later
                displayName = "Worker " .. i
            else
                displayName = "Worker " .. i
            end
            table.insert(workers, {
                name   = displayName,
                index  = i,
                id     = i,
                active = true,
                npc    = npc,   -- g_npcManager NPC object (has position via rootNode)
            })
        end
    end
    if #workers > 0 then return workers end
    return nil
end

-- Called after initializeNPCs(), before loadFromXMLFile().
-- This ordering lets loadFromXMLFile restore saved relationship data
-- by matching the stable contractor uniqueIds we assign below.
function ContractorModBridge:initialize()
    -- Check via modManager first (reliable — doesn't depend on env scoping)
    local modLoaded = g_modManager ~= nil and g_modManager:getModByName("FS25_ContractorMod") ~= nil
    if not modLoaded then return end

    local workers = self:getWorkers()
    if workers == nil then
        print(LOG_PREFIX .. " ContractorMod is loaded but workers table not accessible yet — will retry on update")
        -- Still mark active so update() keeps trying
        self.isActive = true
        return
    end

    self.isActive = true
    print(LOG_PREFIX .. " ContractorMod detected — workers will appear as NPCs")
    self:syncWorkers()
end

-- Poll worker list: add new workers, update positions, remove gone workers.
function ContractorModBridge:syncWorkers()
    local workers = self:getWorkers()
    if workers == nil then return end

    local seenIndices = {}

    for idx, worker in pairs(workers) do
        -- Skip inactive/empty slots
        if worker.active ~= false and worker.name and worker.name ~= "" then
            seenIndices[idx] = true

            if not self.contractorNPCMap[idx] then
                -- New worker — try to find an existing NPC by uniqueId first
                -- (handles the case where save data already persisted this worker)
                local uid = self:makeUniqueId(worker)
                local existing = self:findNPCByUniqueId(uid)
                if existing then
                    self.contractorNPCMap[idx] = existing.id
                    existing.isContractorWorker = true
                    existing.contractorWorkerId = idx
                else
                    local npc = self:createContractorNPC(worker, idx)
                    if npc then
                        self.contractorNPCMap[idx] = npc.id
                    end
                end
            else
                -- Known worker — keep position in sync with ContractorMod
                local npc = self.npcSystem:getNPCById(self.contractorNPCMap[idx])
                if npc then
                    if worker.x then
                        npc.position.x = worker.x
                        npc.position.y = worker.y or npc.position.y
                        npc.position.z = worker.z
                    elseif worker.npc ~= nil and worker.npc.rootNode ~= nil then
                        local ok, wx, wy, wz = pcall(getWorldTranslation, worker.npc.rootNode)
                        if ok and wx then
                            npc.position.x, npc.position.y, npc.position.z = wx, wy, wz
                        end
                    end
                    if worker.currentVehicle ~= nil then
                        npc.currentVehicle = worker.currentVehicle
                        npc.currentAction  = "working"
                    end
                end
            end
        end
    end

    -- Clean up NPCs for workers that no longer exist
    for idx, npcId in pairs(self.contractorNPCMap) do
        if not seenIndices[idx] then
            self:removeContractorNPC(idx)
        end
    end
end

function ContractorModBridge:makeUniqueId(worker)
    local safeName = string.lower(tostring(worker.name or "worker"):gsub("%s+", "_"))
    -- worker.index may be nil; fall back to worker.id or 0
    local idx = worker.index or worker.id or 0
    return string.format("contractor_%d_%s", idx, safeName)
end

function ContractorModBridge:findNPCByUniqueId(uid)
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc.uniqueId == uid then
            return npc
        end
    end
    return nil
end

function ContractorModBridge:createContractorNPC(worker, workerIdx)
    local sys = self.npcSystem
    -- Position: direct coords (ContractorMod native) or via g_npcManager NPC rootNode
    local x, y, z = worker.x or 0, worker.y or 0, worker.z or 0
    if worker.npc ~= nil and worker.npc.rootNode ~= nil then
        local ok, wx, wy, wz = pcall(getWorldTranslation, worker.npc.rootNode)
        if ok and wx then x, y, z = wx, wy, wz end
    end

    local npcIndex     = #sys.activeNPCs + 1
    local locHash      = math.floor(math.abs(x * 7 + z * 13)) % 1000
    local appearanceSeed = (npcIndex * 137 + locHash) % 1000 + 1

    local npc = {
        -- Identity — use the player-assigned worker name
        id           = npcIndex,
        name         = worker.name,
        isFemale     = false,
        age          = math.random(25, 45),
        personality  = "hardworking",

        -- Position
        position     = { x = x, y = y, z = z },
        rotation     = { x = 0, y = (worker.yaw or 0), z = 0 },

        -- State
        isActive          = true,
        currentAction     = (worker.currentVehicle ~= nil) and "working" or "idle",
        currentTask       = nil,
        currentVehicle    = worker.currentVehicle,
        targetPosition    = nil,
        canInteract       = false,
        interactionDistance = 999,

        -- Home
        homePosition      = { x = x, y = y, z = z },
        homeBuilding      = nil,
        homeBuildingName  = "Contractor Base",
        assignedField     = nil,
        assignedVehicles  = {},
        ownerFarmId       = (FarmManager and FarmManager.SPECTATOR_FARM_ID) or 15,

        -- Relationship — start as acquaintance (hired, not a stranger)
        relationship          = math.random(40, 50),
        favorCooldown         = 0,
        lastInteractionTime   = 0,
        totalFavorsCompleted  = 0,
        totalFavorsFailed     = 0,

        -- Visual
        model        = "farmer",
        clothing     = {"farmer"},
        appearanceSeed = appearanceSeed,
        heightScale  = 0.95 + math.random() * 0.1,

        -- AI — hardworking personality defaults
        aiState      = "idle",
        path         = nil,
        movementSpeed = 1.3,
        aiPersonalityModifiers = {
            workEthic    = 1.5,
            sociability  = 0.8,
            generosity   = 0.9,
            punctuality  = 1.3,
        },

        -- Misc
        lastUpdateTime    = 0,
        updatePriority    = 1,
        encounters        = {},
        lastGreetingTime  = 0,
        greetingText      = nil,
        greetingTimer     = 0,
        dodgeTimer        = 0,

        needs = {
            energy           = 20,
            social           = 30,
            hunger           = 10,
            workSatisfaction = 70,
        },
        mood = "neutral",

        birthdayMonth = math.random(1, 12),
        birthdayDay   = math.random(1, 28),

        role              = "farmhand",
        workplaceBuilding = nil,

        -- Contractor-specific markers
        isContractorWorker = true,
        contractorWorkerId = workerIdx,

        -- Stable uniqueId so save/load can restore relationship data
        uniqueId = self:makeUniqueId(worker),
        saveData = {},
        entityId = nil,  -- ContractorMod handles 3D visuals; no NPCEntity spawned
    }

    table.insert(sys.activeNPCs, npc)
    sys.npcCount = sys.npcCount + 1

    if sys.settings and sys.settings.debugMode then
        print(string.format("%s Worker '%s' (idx=%d) added as NPC #%d",
            LOG_PREFIX, npc.name, workerIdx, npc.id))
    else
        print(string.format("%s Worker '%s' added as NPC #%d", LOG_PREFIX, npc.name, npc.id))
    end

    return npc
end

function ContractorModBridge:removeContractorNPC(workerIdx)
    local npcId = self.contractorNPCMap[workerIdx]
    if not npcId then return end

    local sys = self.npcSystem
    for i, npc in ipairs(sys.activeNPCs) do
        if npc.id == npcId then
            -- Entity cleanup (nil-safe: no entity was spawned for contractors)
            if sys.entityManager and npc.entityId and sys.entityManager.removeNPCEntity then
                sys.entityManager:removeNPCEntity(npc)
            end
            table.remove(sys.activeNPCs, i)
            sys.npcCount = sys.npcCount - 1
            print(string.format("%s Worker removed (NPC #%d)", LOG_PREFIX, npcId))
            break
        end
    end

    self.contractorNPCMap[workerIdx] = nil
end

-- Called every frame from NPCSystem:update() (server only, dt in seconds)
function ContractorModBridge:update(dt)
    if not self.isActive then return end

    self.syncTimer = self.syncTimer + dt
    if self.syncTimer >= SYNC_INTERVAL then
        self.syncTimer = 0
        self:syncWorkers()
    end
end

function ContractorModBridge:delete()
    self.isActive         = false
    self.contractorNPCMap = {}
end
