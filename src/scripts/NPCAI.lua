-- =========================================================
-- FS25 NPC Favor Mod - NPC AI System
-- =========================================================
-- Handles NPC behavior, pathfinding, and decision making
-- =========================================================

NPCAI = {}
NPCAI_mt = Class(NPCAI)

function NPCAI.new(npcSystem)
    local self = setmetatable({}, NPCAI_mt)
    
    self.npcSystem = npcSystem
    self.pathfinder = NPCPathfinder.new()
    
    -- AI states
    self.STATES = {
        IDLE = "idle",
        WALKING = "walking",
        WORKING = "working",
        DRIVING = "driving",
        RESTING = "resting",
        SOCIALIZING = "socializing",
        TRAVELING = "traveling"
    }
    
    -- State transition probabilities
    self.transitionProbabilities = {
        idle_to_walk = 0.3,
        idle_to_work = 0.4,
        idle_to_rest = 0.2,
        walk_to_idle = 0.1,
        work_to_idle = 0.05,
        work_to_rest = 0.1
    }
    
    return self
end

function NPCAI:update(dt)
    -- Update pathfinder
    self.pathfinder:update(dt)
end

function NPCAI:updateNPCState(npc, dt)
    -- Only check stuck for movement states (idle/working/resting/socializing are MEANT to be stationary)
    local state = npc.aiState
    if state == self.STATES.WALKING or state == self.STATES.TRAVELING or state == self.STATES.DRIVING then
        if self:isNPCStuck(npc, dt) then
            self:handleStuckNPC(npc)
        end
    else
        -- Reset stuck timer for stationary states so it doesn't accumulate
        npc.stuckTimer = 0
    end

    -- Check current state and update accordingly
    if npc.aiState == self.STATES.IDLE then
        self:updateIdleState(npc, dt)
    elseif npc.aiState == self.STATES.WALKING then
        self:updateWalkingState(npc, dt)
    elseif npc.aiState == self.STATES.WORKING then
        self:updateWorkingState(npc, dt)
    elseif npc.aiState == self.STATES.DRIVING then
        self:updateDrivingState(npc, dt)
    elseif npc.aiState == self.STATES.RESTING then
        self:updateRestingState(npc, dt)
    elseif npc.aiState == self.STATES.SOCIALIZING then
        self:updateSocializingState(npc, dt)
    elseif npc.aiState == self.STATES.TRAVELING then
        self:updateTravelingState(npc, dt)
    end
    
    -- Update current action display
    npc.currentAction = npc.aiState
    
    -- Update state timer
    npc.stateTimer = (npc.stateTimer or 0) + dt
end

function NPCAI:isNPCStuck(npc, dt)
    if not npc.lastPosition then
        npc.lastPosition = {x = npc.position.x, y = npc.position.y, z = npc.position.z}
        npc.stuckTimer = 0
        return false
    end
    
    local distance = VectorHelper.distance3D(
        npc.position.x, npc.position.y, npc.position.z,
        npc.lastPosition.x, npc.lastPosition.y, npc.lastPosition.z
    )
    
    if distance < 0.1 then
        npc.stuckTimer = (npc.stuckTimer or 0) + dt
    else
        npc.stuckTimer = 0
        npc.lastPosition = {x = npc.position.x, y = npc.position.y, z = npc.position.z}
    end
    
    return npc.stuckTimer > 5.0 -- Stuck if not moving for 5 seconds
end

function NPCAI:handleStuckNPC(npc)
    if self.npcSystem.settings.debugMode then
        print(string.format("[NPC Favor] NPC %s stuck at (%.1f, %.1f, %.1f), resetting to idle",
            npc.name, npc.position.x, npc.position.y, npc.position.z))
    end

    -- Reset to idle
    self:setState(npc, self.STATES.IDLE)

    -- Clear path
    npc.path = nil
    npc.targetPosition = nil

    -- Reset stuck timer
    npc.stuckTimer = 0
end

function NPCAI:updateIdleState(npc, dt)
    -- NPC is idle, decide what to do next
    npc.idleTimer = (npc.idleTimer or 0) + dt
    
    -- Personality-based idle time
    local maxIdleTime = 10
    if npc.personality == "lazy" then
        maxIdleTime = 20
    elseif npc.personality == "hardworking" then
        maxIdleTime = 5
    end
    
    if npc.idleTimer > maxIdleTime then
        npc.idleTimer = 0
        
        -- Decide next action based on time of day, personality, and mood
        local hour = self.npcSystem.scheduler:getCurrentHour()
        local minute = self.npcSystem.scheduler:getCurrentMinute()
        local timeOfDay = TimeHelper.getTimeOfDay(hour)
        
        -- Personality-based decision making
        local decision = self:makeAIDecision(npc, hour, timeOfDay)
        
        if decision == "work" and npc.assignedField and hour >= 7 and hour <= 16 then
            -- Go to work
            self:startWorking(npc)
        elseif decision == "walk" then
            -- Take a walk
            self:startWalkingToRandomLocation(npc, 100)
        elseif decision == "socialize" then
            -- Try to find someone to socialize with
            local otherNPC = self:findSocialPartner(npc)
            if otherNPC then
                self:startSocializing(npc, otherNPC)
            else
                self:startWalkingToRandomLocation(npc, 50)
            end
        elseif decision == "go_home" then
            -- Go home
            self:goHome(npc)
        elseif decision == "rest" then
            -- Rest at current location
            self:setState(npc, self.STATES.RESTING)
        else
            -- Default: stay idle
            npc.idleTimer = maxIdleTime * 0.5 -- Wait half the time before next decision
        end
    end
end

function NPCAI:makeAIDecision(npc, hour, timeOfDay)
    local decisions = {}
    local weights = {}
    
    -- Base weights
    if hour >= 6 and hour < 18 then
        -- Daytime
        table.insert(decisions, "work")
        weights["work"] = 40
        
        table.insert(decisions, "walk")
        weights["walk"] = 30
        
        table.insert(decisions, "socialize")
        weights["socialize"] = 20
        
        table.insert(decisions, "rest")
        weights["rest"] = 10
    else
        -- Nighttime
        table.insert(decisions, "go_home")
        weights["go_home"] = 60
        
        table.insert(decisions, "rest")
        weights["rest"] = 30
        
        table.insert(decisions, "walk")
        weights["walk"] = 10
    end
    
    -- Personality modifiers
    if npc.personality == "hardworking" then
        weights["work"] = (weights["work"] or 0) * 2
        weights["rest"] = (weights["rest"] or 0) * 0.5
    elseif npc.personality == "lazy" then
        weights["work"] = (weights["work"] or 0) * 0.5
        weights["rest"] = (weights["rest"] or 0) * 2
    elseif npc.personality == "social" then
        weights["socialize"] = (weights["socialize"] or 0) * 2
    end
    
    -- Relationship with player affects behavior
    if npc.relationship > 70 then
        weights["walk"] = (weights["walk"] or 0) * 1.5 -- More likely to wander near player
    end
    
    -- Weighted random selection
    local totalWeight = 0
    for _, weight in pairs(weights) do
        totalWeight = totalWeight + weight
    end
    
    local randomValue = math.random() * totalWeight
    local currentWeight = 0
    
    for _, decision in ipairs(decisions) do
        currentWeight = currentWeight + (weights[decision] or 0)
        if randomValue <= currentWeight then
            return decision
        end
    end
    
    return "idle" -- Fallback
end

function NPCAI:findSocialPartner(npc)
    for _, otherNPC in ipairs(self.npcSystem.activeNPCs) do
        if otherNPC.id ~= npc.id and otherNPC.isActive then
            local distance = VectorHelper.distance3D(
                npc.position.x, npc.position.y, npc.position.z,
                otherNPC.position.x, otherNPC.position.y, otherNPC.position.z
            )
            
            -- Check if other NPC is social and close enough
            if distance < 50 and (otherNPC.personality == "social" or math.random() < 0.3) then
                -- Check if other NPC is available for socializing
                if otherNPC.aiState == self.STATES.IDLE or otherNPC.aiState == self.STATES.WALKING then
                    return otherNPC
                end
            end
        end
    end
    
    return nil
end

function NPCAI:updateWalkingState(npc, dt)
    if not npc.path or #npc.path == 0 then
        -- Reached destination
        self:setState(npc, self.STATES.IDLE)
        return
    end
    
    -- Move along path
    local target = npc.path[1]
    local dx = target.x - npc.position.x
    local dz = target.z - npc.position.z
    local distance = math.sqrt(dx * dx + dz * dz)
    
    if distance < 1 then
        -- Reached this waypoint
        table.remove(npc.path, 1)
    else
        -- Move toward waypoint
        local speed = npc.movementSpeed * dt
        
        -- Adjust speed based on terrain slope
        if g_currentMission and g_currentMission.terrainRootNode then
            local okSlope, terrainHeight = pcall(getTerrainHeightAtWorldPos,
                g_currentMission.terrainRootNode, npc.position.x, 0, npc.position.z)
            if okSlope and terrainHeight then
                local heightDiff = math.abs(terrainHeight - npc.position.y)
                if heightDiff > 1 then
                    speed = speed * 0.7 -- Slow down on steep terrain
                end
            end
        end

        local moveX = (dx / distance) * speed
        local moveZ = (dz / distance) * speed

        npc.position.x = npc.position.x + moveX
        npc.position.z = npc.position.z + moveZ

        -- Update Y position to terrain
        if g_currentMission and g_currentMission.terrainRootNode then
            local okY, newTerrainHeight = pcall(getTerrainHeightAtWorldPos,
                g_currentMission.terrainRootNode, npc.position.x, 0, npc.position.z)
            if okY and newTerrainHeight then
                npc.position.y = newTerrainHeight + 0.5 -- NPC height offset
            end
        end
        
        -- Update rotation to face movement direction
        if math.abs(dx) > 0.01 or math.abs(dz) > 0.01 then
            npc.rotation.y = math.atan2(moveZ, moveX)
        end
        
        -- Update path visual if debug mode
        if self.npcSystem.settings.debugMode and npc.path and #npc.path > 0 then
            npc.currentPathSegment = {start = {x = npc.position.x, y = npc.position.y, z = npc.position.z},
                                     target = target}
        end
    end
end

function NPCAI:updateWorkingState(npc, dt)
    -- Simulate working on field
    npc.workTimer = (npc.workTimer or 0) + dt
    
    -- Personality-based work duration
    local workDuration = 30
    if npc.personality == "hardworking" then
        workDuration = 45
    elseif npc.personality == "lazy" then
        workDuration = 15
    end
    
    if npc.workTimer > workDuration then
        npc.workTimer = 0
        
        -- Decide what to do next
        local nextAction = math.random()
        
        if nextAction < 0.3 then
            -- Take a break
            self:setState(npc, self.STATES.IDLE)
            
            -- Show notification
            if math.random() < 0.5 and self.npcSystem.settings.showNotifications then
                self.npcSystem:showNotification(
                    "NPC Working",
                    string.format("%s is taking a break from working", npc.name)
                )
            end
            
        elseif nextAction < 0.6 then
            -- Continue working (extended work period)
            npc.workTimer = workDuration * 0.5 -- Reset to half duration
            
        elseif nextAction < 0.8 then
            -- Move to a different part of the field
            if npc.assignedField then
                local fieldCenter = npc.assignedField.center
                local offsetX = math.random(-30, 30)
                local offsetZ = math.random(-30, 30)
                
                self:startWalkingTo(npc, fieldCenter.x + offsetX, fieldCenter.z + offsetZ)
                self:setState(npc, self.STATES.WALKING)
            end
            
        else
            -- Finish working for now
            self:setState(npc, self.STATES.IDLE)
            
            -- Show notification
            if math.random() < 0.3 then
                self.npcSystem:showNotification(
                    "NPC Working",
                    string.format("%s finished working for now", npc.name)
                )
            end
        end
    end
end

function NPCAI:updateDrivingState(npc, dt)
    -- NPC is driving a vehicle
    if not npc.currentVehicle then
        self:setState(npc, self.STATES.IDLE)
        return
    end
    
    -- Update vehicle position (simplified)
    npc.vehicleTimer = (npc.vehicleTimer or 0) + dt
    
    -- Personality-based driving duration
    local driveDuration = 20
    if npc.personality == "hardworking" then
        driveDuration = 30
    elseif npc.personality == "lazy" then
        driveDuration = 10
    end
    
    if npc.vehicleTimer > driveDuration then
        npc.vehicleTimer = 0
        self:stopDriving(npc)
    else
        -- Simulate vehicle movement
        local speed = 5.0 * dt -- 5 m/s
        local moveX = math.cos(npc.rotation.y) * speed
        local moveZ = math.sin(npc.rotation.y) * speed
        
        npc.position.x = npc.position.x + moveX
        npc.position.z = npc.position.z + moveZ
        
        -- Update vehicle position
        if npc.currentVehicle then
            npc.currentVehicle.position = {
                x = npc.position.x,
                y = npc.position.y,
                z = npc.position.z
            }
        end
    end
end

function NPCAI:updateRestingState(npc, dt)
    -- NPC is resting (at home during night or tired)
    npc.restTimer = (npc.restTimer or 0) + dt
    
    local restDuration = 60
    if npc.personality == "lazy" then
        restDuration = 90
    elseif npc.personality == "hardworking" then
        restDuration = 30
    end
    
    if npc.restTimer > restDuration then
        npc.restTimer = 0
        self:setState(npc, self.STATES.IDLE)
        
        -- Show notification if resting at unusual time
        local hour = self.npcSystem.scheduler:getCurrentHour()
        if hour >= 8 and hour <= 16 and math.random() < 0.3 then
            self.npcSystem:showNotification(
                "NPC Resting",
                string.format("%s is well-rested and ready to work", npc.name)
            )
        end
    end
end

function NPCAI:updateSocializingState(npc, dt)
    -- NPC is talking with another NPC
    npc.socialTimer = (npc.socialTimer or 0) + dt
    
    local socialDuration = 15
    if npc.personality == "social" then
        socialDuration = 25
    elseif npc.personality == "loner" then
        socialDuration = 5
    end
    
    if npc.socialTimer > socialDuration then
        npc.socialTimer = 0
        self:setState(npc, self.STATES.IDLE)
        
        -- Update relationship with social partner
        if npc.socialPartner then
            -- Small positive relationship change for socializing
            local partner = npc.socialPartner
            if partner and partner.isActive then
                -- Both NPCs get a small relationship boost with each other
                -- (In a full implementation, you'd track NPC-NPC relationships)
                self.npcSystem:showNotification(
                    "NPC Socializing",
                    string.format("%s and %s finished their conversation", 
                        npc.name, partner.name)
                )
            end
            npc.socialPartner = nil
        end
    end
end

function NPCAI:updateTravelingState(npc, dt)
    -- NPC is traveling to a distant location
    if not npc.path or #npc.path == 0 then
        self:setState(npc, self.STATES.IDLE)
        return
    end
    
    self:updateWalkingState(npc, dt)
    
    -- Check if reached destination
    if #npc.path == 0 then
        self:setState(npc, self.STATES.IDLE)
        
        -- Show arrival notification for long travels
        if npc.travelDistance and npc.travelDistance > 200 then
            self.npcSystem:showNotification(
                "NPC Travel",
                string.format("%s has arrived at the destination", npc.name)
            )
        end
    end
end

function NPCAI:setState(npc, state)
    local oldState = npc.aiState
    npc.aiState = state
    npc.currentAction = state
    npc.stateTimer = 0
    
    -- State transition effects
    if oldState ~= state then
        -- Flag sync dirty for immediate multiplayer broadcast
        if self.npcSystem.syncDirty ~= nil then
            self.npcSystem.syncDirty = true
        end

        if self.npcSystem.settings.debugMode then
            print(string.format("NPC %s: %s -> %s", npc.name, oldState, state))
        end
        
        -- Reset timers for new state
        if state == self.STATES.IDLE then
            npc.idleTimer = 0
        elseif state == self.STATES.WORKING then
            npc.workTimer = 0
        elseif state == self.STATES.DRIVING then
            npc.vehicleTimer = 0
        elseif state == self.STATES.RESTING then
            npc.restTimer = 0
        elseif state == self.STATES.SOCIALIZING then
            npc.socialTimer = 0
            npc.socialPartner = nil
        elseif state == self.STATES.TRAVELING then
            npc.travelTimer = 0
        end
    end
end

function NPCAI:startWorking(npc)
    if not npc.assignedField then
        self:setState(npc, self.STATES.IDLE)
        return
    end
    
    -- Go to field
    local targetX = npc.assignedField.center.x
    local targetZ = npc.assignedField.center.z
    
    if self:isAtPosition(npc, targetX, targetZ, 20) then
        -- Already at field, start working
        self:setState(npc, self.STATES.WORKING)
        
        -- Show notification
        if math.random() < 0.7 and self.npcSystem.settings.showNotifications then
            self.npcSystem:showNotification(
                "NPC Working",
                string.format("%s is now working on their field", npc.name)
            )
        end
    else
        -- Walk to field
        self:startWalkingTo(npc, targetX, targetZ)
        self:setState(npc, self.STATES.WALKING)
    end
end

function NPCAI:startWalkingTo(npc, targetX, targetZ)
    -- Generate path to target
    npc.path = self.pathfinder:findPath(
        npc.position.x, npc.position.z,
        targetX, targetZ
    )
    
    if not npc.path or #npc.path == 0 then
        -- Direct movement if pathfinding fails
        npc.path = {
            {x = targetX, y = 0, z = targetZ}
        }
    end
    
    npc.targetPosition = {x = targetX, y = 0, z = targetZ}
    
    -- Calculate travel distance
    if npc.path and #npc.path > 0 then
        local totalDistance = 0
        for i = 1, #npc.path - 1 do
            local p1 = npc.path[i]
            local p2 = npc.path[i + 1]
            totalDistance = totalDistance + VectorHelper.distance2D(p1.x, p1.z, p2.x, p2.z)
        end
        npc.travelDistance = totalDistance
        
        if totalDistance > 200 then
            self:setState(npc, self.STATES.TRAVELING)
        end
    end
end

function NPCAI:startWalkingToRandomLocation(npc, maxDistance)
    local angle = math.random() * math.pi * 2
    local distance = math.random(20, maxDistance)
    
    local targetX = npc.position.x + math.cos(angle) * distance
    local targetZ = npc.position.z + math.sin(angle) * distance
    
    -- Ensure target is on valid terrain
    local targetY = 0
    if g_currentMission and g_currentMission.terrainRootNode then
        local okH, h = pcall(getTerrainHeightAtWorldPos, g_currentMission.terrainRootNode, targetX, 0, targetZ)
        if okH and h then targetY = h end
    end
    
    self:startWalkingTo(npc, targetX, targetZ)
    
    -- Set appropriate state based on distance
    if distance > 100 then
        self:setState(npc, self.STATES.TRAVELING)
    else
        self:setState(npc, self.STATES.WALKING)
    end
end

function NPCAI:goHome(npc)
    if not npc.homePosition then
        self:setState(npc, self.STATES.IDLE)
        return
    end
    
    -- Calculate distance to home
    local distance = VectorHelper.distance3D(
        npc.position.x, npc.position.y, npc.position.z,
        npc.homePosition.x, npc.homePosition.y, npc.homePosition.z
    )
    
    if distance < 10 then
        -- Already close to home
        self:setState(npc, self.STATES.RESTING)
    else
        -- Walk home
        self:startWalkingTo(npc, npc.homePosition.x, npc.homePosition.z)
        
        if distance > 200 then
            self:setState(npc, self.STATES.TRAVELING)
        else
            self:setState(npc, self.STATES.WALKING)
        end
    end
end

function NPCAI:startDriving(npc, vehicle)
    if not vehicle or not vehicle.isAvailable then
        return false
    end
    
    npc.currentVehicle = vehicle
    vehicle.isAvailable = false
    vehicle.currentTask = "driving"
    vehicle.driver = npc
    
    self:setState(npc, self.STATES.DRIVING)
    
    -- Show notification
    if self.npcSystem.settings.showNotifications then
        self.npcSystem:showNotification(
            "NPC Driving",
            string.format("%s is now driving their %s", npc.name, vehicle.type)
        )
    end
    
    return true
end

function NPCAI:stopDriving(npc)
    if npc.currentVehicle then
        npc.currentVehicle.isAvailable = true
        npc.currentVehicle.currentTask = nil
        npc.currentVehicle.driver = nil
        npc.currentVehicle = nil
    end
    
    self:setState(npc, self.STATES.IDLE)
    
    -- Show notification
    if self.npcSystem.settings.showNotifications then
        self.npcSystem:showNotification(
            "NPC Driving",
            string.format("%s stopped driving", npc.name)
        )
    end
end

function NPCAI:startSocializing(npc, otherNPC)
    if not otherNPC or not otherNPC.isActive then
        self:setState(npc, self.STATES.IDLE)
        return
    end
    
    -- Face each other
    local dx = otherNPC.position.x - npc.position.x
    local dz = otherNPC.position.z - npc.position.z
    npc.rotation.y = math.atan2(dz, dx)
    
    otherNPC.rotation.y = math.atan2(-dz, -dx)
    
    -- Set both to socializing
    self:setState(npc, self.STATES.SOCIALIZING)
    npc.socialPartner = otherNPC
    
    -- Also set the other NPC to socializing
    local otherAI = self.npcSystem.aiSystem
    otherAI:setState(otherNPC, otherAI.STATES.SOCIALIZING)
    otherNPC.socialPartner = npc
    
    -- Show notification
    if self.npcSystem.settings.showNotifications then
        self.npcSystem:showNotification(
            "NPC Socializing",
            string.format("%s and %s are having a conversation", 
                npc.name, otherNPC.name)
        )
    end
end

function NPCAI:isAtHome(npc)
    if not npc.homePosition then
        return false
    end
    
    return self:isAtPosition(npc, npc.homePosition.x, npc.homePosition.z, 10)
end

function NPCAI:isAtPosition(npc, x, z, tolerance)
    local dx = x - npc.position.x
    local dz = z - npc.position.z
    local distance = math.sqrt(dx * dx + dz * dz)
    
    return distance <= (tolerance or 5)
end

-- Enhanced Pathfinder helper class
NPCPathfinder = {}
NPCPathfinder_mt = Class(NPCPathfinder)

function NPCPathfinder.new()
    local self = setmetatable({}, NPCPathfinder_mt)
    
    -- Pathfinding settings
    self.maxPathLength = 1000
    self.avoidWater = true
    self.avoidSteepSlopes = true
    self.maxSlope = 30 -- degrees
    
    -- Cache for frequently used paths
    self.pathCache = {}
    self.cacheSize = 50
    
    return self
end

function NPCPathfinder:findPath(startX, startZ, endX, endZ)
    -- Check cache first
    local cacheKey = string.format("%.1f_%.1f_%.1f_%.1f", startX, startZ, endX, endZ)
    if self.pathCache[cacheKey] then
        return self:clonePath(self.pathCache[cacheKey])
    end
    
    -- Calculate direct distance
    local directDistance = VectorHelper.distance2D(startX, startZ, endX, endZ)
    
    -- Simple pathfinding for now - direct line with obstacle avoidance
    local path = {}
    
    -- Add start point
    local startY = 0
    if g_currentMission and g_currentMission.terrainRootNode then
        local okS, hS = pcall(getTerrainHeightAtWorldPos, g_currentMission.terrainRootNode, startX, 0, startZ)
        if okS and hS then startY = hS end
    end
    table.insert(path, {x = startX, y = startY, z = startZ})
    
    -- For long distances, add intermediate points
    if directDistance > 50 then
        local segments = math.min(5, math.floor(directDistance / 50))
        for i = 1, segments do
            local t = i / (segments + 1)
            local x = startX + (endX - startX) * t
            local z = startZ + (endZ - startZ) * t
            
            -- Add random variation to avoid straight lines
            if segments > 1 and i < segments then
                local perpendicularX, perpendicularZ = VectorHelper.getPerpendicular(endX - startX, endZ - startZ)
                local variation = math.random(-10, 10)
                x = x + perpendicularX * variation / directDistance
                z = z + perpendicularZ * variation / directDistance
            end
            
            -- Adjust for terrain
            local y = self:getSafeTerrainHeight(x, z)
            
            table.insert(path, {x = x, y = y, z = z})
        end
    end
    
    -- Add end point
    local endY = self:getSafeTerrainHeight(endX, endZ)
    table.insert(path, {x = endX, y = endY, z = endZ})
    
    -- Optimize path (remove unnecessary points)
    path = self:optimizePath(path)
    
    -- Cache the path
    self:cachePath(cacheKey, path)
    
    return path
end

function NPCPathfinder:getSafeTerrainHeight(x, z)
    if not g_currentMission or not g_currentMission.terrainRootNode then
        return 0
    end

    local terrainRoot = g_currentMission.terrainRootNode
    local okH, height = pcall(getTerrainHeightAtWorldPos, terrainRoot, x, 0, z)
    if not okH then height = nil end

    if not height then
        -- Fallback: use nearby terrain height
        for offset = 1, 10 do
            for angle = 0, math.pi * 2, math.pi / 4 do
                local checkX = x + math.cos(angle) * offset
                local checkZ = z + math.sin(angle) * offset
                local okC, checkHeight = pcall(getTerrainHeightAtWorldPos, terrainRoot, checkX, 0, checkZ)
                if okC and checkHeight then
                    return checkHeight
                end
            end
        end
        return 0
    end

    -- Check if location is in water (getWaterTypeAtWorldPos may not exist)
    if self.avoidWater then
        local okW, waterType = pcall(function()
            return getWaterTypeAtWorldPos(terrainRoot, x, 0, z)
        end)
        if okW and waterType and waterType > 0 then
            -- Try to find nearby land
            for offset = 5, 50, 5 do
                for angle = 0, math.pi * 2, math.pi / 8 do
                    local checkX = x + math.cos(angle) * offset
                    local checkZ = z + math.sin(angle) * offset
                    local okCH, checkHeight = pcall(getTerrainHeightAtWorldPos, terrainRoot, checkX, 0, checkZ)
                    local okCW, checkWater = pcall(function()
                        return getWaterTypeAtWorldPos(terrainRoot, checkX, 0, checkZ)
                    end)
                    if okCH and checkHeight and (not okCW or not checkWater or checkWater == 0) then
                        return checkHeight
                    end
                end
            end
        end
    end

    return height
end

function NPCPathfinder:optimizePath(path)
    if #path <= 2 then
        return path
    end
    
    local optimized = {}
    table.insert(optimized, path[1])
    
    for i = 2, #path - 1 do
        local prev = optimized[#optimized]
        local current = path[i]
        local next = path[i + 1]
        
        -- Check if current point is necessary
        local angle1 = VectorHelper.angleBetween(prev.x, prev.z, current.x, current.z)
        local angle2 = VectorHelper.angleBetween(current.x, current.z, next.x, next.z)
        local angleDiff = math.abs(angle1 - angle2)
        
        -- Keep point if it causes significant direction change
        if angleDiff > math.pi / 6 then -- 30 degrees
            table.insert(optimized, current)
        end
    end
    
    table.insert(optimized, path[#path])
    
    return optimized
end

function NPCPathfinder:cachePath(key, path)
    -- Add to cache
    self.pathCache[key] = self:clonePath(path)
    
    -- Limit cache size
    local keys = {}
    for k in pairs(self.pathCache) do
        table.insert(keys, k)
    end
    
    if #keys > self.cacheSize then
        -- Remove oldest entries (simplified: remove random ones)
        while #keys > self.cacheSize do
            local removeKey = table.remove(keys, math.random(1, #keys))
            self.pathCache[removeKey] = nil
        end
    end
end

function NPCPathfinder:clonePath(path)
    local clone = {}
    for _, point in ipairs(path) do
        table.insert(clone, {
            x = point.x,
            y = point.y,
            z = point.z
        })
    end
    return clone
end

function NPCPathfinder:update(dt)
    -- Clean old cache entries periodically
    self.cacheCleanupTimer = (self.cacheCleanupTimer or 0) + dt
    if self.cacheCleanupTimer > 60 then -- Clean every minute
        self.cacheCleanupTimer = 0

        -- Count cache entries (# operator doesn't work on hash tables in Lua 5.1)
        local keys = {}
        for k in pairs(self.pathCache) do
            table.insert(keys, k)
        end

        -- Evict oldest half when cache exceeds 2x limit
        if #keys > self.cacheSize then
            local removeCount = #keys - self.cacheSize
            for i = 1, removeCount do
                self.pathCache[keys[i]] = nil
            end
        end
    end
end