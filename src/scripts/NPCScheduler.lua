-- =========================================================
-- FS25 NPC Favor Mod - NPC Scheduler
-- =========================================================
-- Handles NPC daily schedules, work hours, and task timing
-- =========================================================

NPCScheduler = {}
NPCScheduler_mt = Class(NPCScheduler)

function NPCScheduler.new(npcSystem)
    local self = setmetatable({}, NPCScheduler_mt)
    
    self.npcSystem = npcSystem
    
    -- Current time tracking
    self.currentTime = 0
    self.currentHour = 8
    self.currentMinute = 0
    self.currentDay = 1
    self.currentMonth = 1
    self.currentYear = 1
    self.lastUpdateTime = 0
    
    -- Add missing initialization variables
    self.dailyEvents = {}
    self.scheduledNPCInteractions = {}
    self.lastScheduleUpdate = 0
    self.scheduleUpdateInterval = 1000 -- 1 second
    self.eventIdCounter = 1
    
    -- Enhanced schedule templates with seasonal variations
    self.scheduleTemplates = {
        farmer = {
            spring = {
                { start = 6,  ["end"] = 7,  activity = "morning_routine", priority = 1 },
                { start = 7,  ["end"] = 12, activity = "field_preparation", priority = 2 },
                { start = 12, ["end"] = 13, activity = "lunch_break", priority = 3 },
                { start = 13, ["end"] = 17, activity = "planting", priority = 2 },
                { start = 17, ["end"] = 19, activity = "equipment_maintenance", priority = 1 },
                { start = 19, ["end"] = 22, activity = "personal_time", priority = 3 },
                { start = 22, ["end"] = 6,  activity = "sleeping", priority = 1 }
            },
            summer = {
                { start = 5,  ["end"] = 6,  activity = "morning_routine", priority = 1 },
                { start = 6,  ["end"] = 11, activity = "irrigation", priority = 2 },
                { start = 11, ["end"] = 15, activity = "break_heat", priority = 3 },
                { start = 15, ["end"] = 20, activity = "field_maintenance", priority = 2 },
                { start = 20, ["end"] = 22, activity = "evening_chores", priority = 1 },
                { start = 22, ["end"] = 5,  activity = "sleeping", priority = 1 }
            },
            autumn = {
                { start = 6,  ["end"] = 7,  activity = "morning_routine", priority = 1 },
                { start = 7,  ["end"] = 12, activity = "harvesting", priority = 2 },
                { start = 12, ["end"] = 13, activity = "lunch_break", priority = 3 },
                { start = 13, ["end"] = 18, activity = "harvesting", priority = 2 },
                { start = 18, ["end"] = 20, activity = "storage_work", priority = 1 },
                { start = 20, ["end"] = 22, activity = "personal_time", priority = 3 },
                { start = 22, ["end"] = 6,  activity = "sleeping", priority = 1 }
            },
            winter = {
                { start = 8,  ["end"] = 9,  activity = "morning_routine", priority = 1 },
                { start = 9,  ["end"] = 12, activity = "indoor_work", priority = 2 },
                { start = 12, ["end"] = 13, activity = "lunch_break", priority = 3 },
                { start = 13, ["end"] = 16, activity = "equipment_repair", priority = 2 },
                { start = 16, ["end"] = 18, activity = "planning", priority = 1 },
                { start = 18, ["end"] = 22, activity = "personal_time", priority = 3 },
                { start = 22, ["end"] = 8,  activity = "sleeping", priority = 1 }
            }
        },
        worker = {
            default = {
                { start = 7,  ["end"] = 8,  activity = "commute", priority = 1 },
                { start = 8,  ["end"] = 12, activity = "work_shift", priority = 2 },
                { start = 12, ["end"] = 13, activity = "lunch", priority = 3 },
                { start = 13, ["end"] = 16, activity = "work_shift", priority = 2 },
                { start = 16, ["end"] = 17, activity = "commute_home", priority = 1 },
                { start = 17, ["end"] = 22, activity = "free_time", priority = 3 },
                { start = 22, ["end"] = 7,  activity = "sleep", priority = 1 }
            }
        },
        casual = {
            default = {
                { start = 9,  ["end"] = 10, activity = "breakfast", priority = 1 },
                { start = 10, ["end"] = 12, activity = "chores", priority = 2 },
                { start = 12, ["end"] = 14, activity = "lunch_social", priority = 3 },
                { start = 14, ["end"] = 17, activity = "leisure", priority = 3 },
                { start = 17, ["end"] = 19, activity = "evening_activities", priority = 2 },
                { start = 19, ["end"] = 23, activity = "dinner_relax", priority = 1 },
                { start = 23, ["end"] = 9,  activity = "sleep", priority = 1 }
            }
        }
    }
    
    return self
end

function NPCScheduler:start()
    -- Initialize with current game time
    self:updateGameTime()
    
    -- Schedule initial daily events
    self:scheduleDailyEvents()
    
    -- Initialize NPC schedules
    self:initializeNPCSchedules()
    
    print("[NPC Scheduler] Started")
end

function NPCScheduler:update(dt)
    self.currentTime = self.currentTime + dt
    
    -- Update game time tracking
    self:updateGameTime()
    
    -- Update schedules at intervals for performance
    self.lastScheduleUpdate = self.lastScheduleUpdate + dt
    if self.lastScheduleUpdate >= self.scheduleUpdateInterval then
        self:updateAllNPCSchedules()
        self.lastScheduleUpdate = 0
    end
    
    -- Check for scheduled events
    self:checkScheduledEvents(dt)
    
    -- Update weather effects
    self:updateWeatherEffects(dt)
end

function NPCScheduler:updateGameTime()
    if not g_currentMission or not g_currentMission.environment then
        return
    end
    
    -- Get time from game environment
    local gameTime = g_currentMission.environment.dayTime or 0
    local hour = g_currentMission.environment.currentHour or 0
    local minute = g_currentMission.environment.currentMinute or 0
    local day = g_currentMission.environment.currentDay or 1
    local month = g_currentMission.environment.currentMonth or 1
    local year = g_currentMission.environment.currentYear or 1
    
    -- Check if day changed
    if day ~= self.currentDay then
        self:onNewDay(day, month, year)
    end
    
    -- Check if month changed
    if month ~= self.currentMonth then
        self:onNewMonth(month, year)
    end
    
    self.currentHour = hour
    self.currentMinute = minute
    self.currentDay = day
    self.currentMonth = month
    self.currentYear = year
end

function NPCScheduler:onNewDay(newDay, month, year)
    -- Clear old events
    self.dailyEvents = {}
    
    -- Schedule new daily events
    self:scheduleDailyEvents()
    
    -- Update NPC daily schedules - SAFELY
    if self.npcSystem and self.npcSystem.activeNPCs then
        for _, npc in ipairs(self.npcSystem.activeNPCs) do
            if npc and npc.isActive then
                self:updateNPCDailySchedule(npc, month)
            end
        end
    end
    
    -- Clean up old scheduled interactions
    self:cleanupOldInteractions()
    
    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print(string.format("NPC Scheduler: New day %d started (Month: %d, Year: %d)", 
            newDay, month, year))
    end
end

function NPCScheduler:onNewMonth(newMonth, year)
    -- Update seasonal schedules - SAFELY
    if self.npcSystem and self.npcSystem.activeNPCs then
        for _, npc in ipairs(self.npcSystem.activeNPCs) do
            if npc and npc.isActive then
                self:updateSeasonalSchedule(npc, newMonth)
            end
        end
    end
    
    if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
        print(string.format("NPC Scheduler: Month changed to %d", newMonth))
    end
end

function NPCScheduler:scheduleDailyEvents()
    -- Clear existing events
    self.dailyEvents = {}
    self.eventIdCounter = 1
    
    -- Schedule favor request opportunities throughout the day
    -- More opportunities during working hours
    for hour = 8, 20, 2 do  -- Every 2 hours from 8 AM to 8 PM
        local eventTime = hour * 60 * 60 * 1000  -- Convert to milliseconds
        
        -- Vary the exact minute for more natural timing
        local minute = math.random(0, 59)
        eventTime = eventTime + (minute * 60 * 1000)
        
        local event = {
            id = self.eventIdCounter,
            type = "favor_opportunity",
            time = eventTime,
            executed = false,
            priority = 2,
            data = {
                hour = hour,
                minute = minute,
                maxFavors = math.random(1, 3),
                weatherFactor = self:getWeatherFactor()
            }
        }
        self.eventIdCounter = self.eventIdCounter + 1
        table.insert(self.dailyEvents, event)
    end
    
    -- Schedule work start/end times for NPCs
    local scheduleCheckHours = {6, 9, 12, 15, 18, 21}
    for _, hour in ipairs(scheduleCheckHours) do
        local eventTime = hour * 60 * 60 * 1000
        local event = {
            id = self.eventIdCounter,
            type = "schedule_check",
            time = eventTime,
            executed = false,
            priority = 1,
            data = {
                hour = hour,
                checkType = "activity_transition",
                forceUpdate = (hour == 6 or hour == 21) -- Force update at start/end of day
            }
        }
        self.eventIdCounter = self.eventIdCounter + 1
        table.insert(self.dailyEvents, event)
    end
    
    -- Schedule random social interactions
    for i = 1, 3 do  -- 3 random social opportunities per day
        local hour = math.random(10, 19)
        local minute = math.random(0, 59)
        local eventTime = hour * 60 * 60 * 1000 + minute * 60 * 1000
        
        local event = {
            id = self.eventIdCounter,
            type = "social_opportunity",
            time = eventTime,
            executed = false,
            priority = 3,
            data = {
                hour = hour,
                minute = minute,
                maxInteractions = math.random(1, 2)
            }
        }
        self.eventIdCounter = self.eventIdCounter + 1
        table.insert(self.dailyEvents, event)
    end
    
    -- Sort events by time and priority
    table.sort(self.dailyEvents, function(a, b)
        if a.time == b.time then
            return a.priority > b.priority
        end
        return a.time < b.time
    end)
end

function NPCScheduler:getWeatherFactor()
    if not g_currentMission or not g_currentMission.environment or not g_currentMission.environment.weather then
        return 1.0
    end
    
    local weather = g_currentMission.environment.weather
    local weatherType = weather.currentWeather or "clear"
    
    -- Different weather affects favor likelihood
    local factors = {
        clear = 1.0,
        sunny = 1.0,
        cloudy = 0.9,
        rain = 0.7,
        storm = 0.3,
        snow = 0.5,
        fog = 0.8
    }
    
    return factors[weatherType] or 1.0
end

function NPCScheduler:checkScheduledEvents(dt)
    local currentGameTime = g_currentMission.environment.dayTime or 0
    
    for _, event in ipairs(self.dailyEvents) do
        if not event.executed and currentGameTime >= event.time then
            self:executeEvent(event)
            event.executed = true
            
            -- Log execution for debugging
            if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                print(string.format("Scheduler: Executed event %d (%s) at %02d:%02d", 
                    event.id, event.type, 
                    math.floor(event.time / (60 * 60 * 1000)),
                    math.floor((event.time % (60 * 60 * 1000)) / (60 * 1000))))
            end
        end
    end
end

function NPCScheduler:executeEvent(event)
    if event.type == "favor_opportunity" then
        self:handleFavorOpportunity(event.data)
        
    elseif event.type == "schedule_check" then
        self:handleScheduleCheck(event.data)
        
    elseif event.type == "social_opportunity" then
        self:handleSocialOpportunity(event.data)
        
    elseif event.type == "npc_interaction" then
        self:handleNPCInteractionEvent(event.data)
    end
end

function NPCScheduler:handleFavorOpportunity(data)
    if not self.npcSystem or not self.npcSystem.settings or not self.npcSystem.settings.enableFavors then
        return
    end
    
    -- Apply weather factor
    local weatherFactor = data.weatherFactor or 1.0
    local chance = 0.3 * weatherFactor  -- Base 30% chance, modified by weather
    
    -- Time of day factor (higher chance during mid-day)
    local hourFactor = 1.0
    if data.hour >= 10 and data.hour <= 16 then
        hourFactor = 1.3  -- 30% higher chance during peak hours
    end
    
    chance = chance * hourFactor
    
    if math.random() < chance then
        local npc = self:getRandomAvailableNPC()
        if npc and npc.favorCooldown <= 0 then
            -- NPC can ask for favor
            npc.canAskForFavor = true
            npc.nextFavorOpportunity = g_currentMission.time + math.random(5, 15) * 60 * 1000  -- 5-15 minutes
            
            if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                print(string.format("NPC %s can ask for favor at %02d:%02d (weather: %.1f)", 
                    npc.name, data.hour, data.minute, weatherFactor))
            end
        end
    end
end

function NPCScheduler:handleScheduleCheck(data)
    -- Update NPC activities based on time of day - SAFELY
    if not self.npcSystem or not self.npcSystem.activeNPCs then
        return
    end
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc and npc.isActive then
            self:updateNPCBasedOnTime(npc, data.forceUpdate)
        end
    end
end

function NPCScheduler:handleSocialOpportunity(data)
    if not self.npcSystem or not self.npcSystem.settings or not self.npcSystem.settings.enableFavors then
        return
    end
    
    -- Find NPCs who might want to socialize
    local socialNPCs = {}
    
    if not self.npcSystem or not self.npcSystem.activeNPCs then
        return
    end
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc and npc.isActive and npc.aiState == "idle" then
            -- Check personality for sociability
            local sociability = 0.5  -- Base chance
            if npc.personality == "social" then
                sociability = 0.8
            elseif npc.personality == "loner" then
                sociability = 0.2
            elseif npc.personality == "friendly" then
                sociability = 0.7
            elseif npc.personality == "grumpy" then
                sociability = 0.3
            end
            
            -- Check time of day (more social during breaks)
            local hour = self.currentHour
            local timeFactor = 1.0
            if (hour >= 12 and hour <= 14) or (hour >= 17 and hour <= 19) then
                timeFactor = 1.5  -- More social during lunch and evening
            end
            
            local chance = sociability * timeFactor * 0.5  -- Overall chance modifier
            
            if math.random() < chance then
                table.insert(socialNPCs, npc)
            end
        end
    end
    
    -- Try to pair up NPCs for socializing
    if #socialNPCs >= 2 then
        -- Shuffle to get random pairs
        for i = 1, #socialNPCs - 1, 2 do
            local npc1 = socialNPCs[i]
            local npc2 = socialNPCs[i + 1]
            
            -- Check if they're close enough
            local distance = VectorHelper.distance3D(
                npc1.position.x, npc1.position.y, npc1.position.z,
                npc2.position.x, npc2.position.y, npc2.position.z
            )
            
            if distance < 100 then  -- Within 100 meters
                -- Schedule social interaction
                local interactionTime = g_currentMission.time + math.random(1, 5) * 60 * 1000
                self:scheduleNPCInteraction(npc1, npc2, interactionTime, "socialize")
                
                if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
                    print(string.format("Scheduled social interaction between %s and %s at %02d:%02d",
                        npc1.name, npc2.name, data.hour, data.minute))
                end
            end
        end
    end
end

function NPCScheduler:updateAllNPCSchedules()
    -- Update all NPC schedules - SAFELY
    if not self.npcSystem or not self.npcSystem.activeNPCs then
        return
    end
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc and npc.isActive then
            self:updateNPCSchedule(npc, self.scheduleUpdateInterval)
        end
    end
    
    -- Check for scheduled interactions
    self:checkScheduledInteractions()
end

function NPCScheduler:updateNPCSchedule(npc, dt)
    if not npc then
        return
    end
    
    -- Check if NPC should transition to new activity
    local currentActivity = npc.currentActivity or "idle"
    local targetActivity = self:getActivityForCurrentTime(npc)
    
    if currentActivity ~= targetActivity then
        npc.currentActivity = targetActivity
        npc.activityStartTime = g_currentMission.time
        
        -- Update AI state based on activity
        self:updateAIStateForActivity(npc, targetActivity)
        
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print(string.format("NPC %s: %s -> %s", npc.name, currentActivity, targetActivity))
        end
    end
    
    -- Check for favor asking opportunity
    if npc.canAskForFavor and npc.nextFavorOpportunity and g_currentMission.time >= npc.nextFavorOpportunity then
        self:triggerFavorRequest(npc)
        npc.canAskForFavor = false
        npc.nextFavorOpportunity = nil
    end
    
    -- Update activity timer
    npc.activityTimer = (npc.activityTimer or 0) + dt
    
    -- Check if activity should end based on duration
    local maxActivityDuration = self:getMaxActivityDuration(npc, npc.currentActivity)
    if maxActivityDuration and npc.activityTimer > maxActivityDuration then
        -- Activity completed, return to idle
        npc.currentActivity = "idle"
        npc.activityTimer = 0
        if self.npcSystem and self.npcSystem.aiSystem then
            self.npcSystem.aiSystem:setState(npc, self.npcSystem.aiSystem.STATES.IDLE)
        end
    end
end

function NPCScheduler:getMaxActivityDuration(npc, activity)
    if not npc or not activity then
        return 7200 -- Default 2 hours
    end
    
    local durations = {
        morning_routine = 3600, -- 1 hour
        lunch_break = 3600, -- 1 hour
        personal_time = 10800, -- 3 hours
        sleeping = 28800, -- 8 hours
        work_shift = 14400, -- 4 hours
        leisure = 10800, -- 3 hours
        field_work = 18000 -- 5 hours
    }
    
    local baseDuration = durations[activity] or 7200 -- Default 2 hours
    
    -- Personality modifiers
    if npc.personality == "hardworking" and activity:find("work") then
        baseDuration = baseDuration * 1.3 -- Work longer
    elseif npc.personality == "lazy" and activity:find("work") then
        baseDuration = baseDuration * 0.7 -- Work shorter
    end
    
    return baseDuration
end

function NPCScheduler:getActivityForCurrentTime(npc)
    if not npc then
        return "idle"
    end
    
    local hour = self.currentHour
    local schedule = self:getScheduleForNPC(npc)
    
    if not schedule then
        return "idle"
    end
    
    for _, slot in ipairs(schedule) do
        local slotEnd = slot["end"]

        -- Handle overnight ranges (e.g. 22 → 6)
        if slot.start < slotEnd then
            if hour >= slot.start and hour < slotEnd then
                return slot.activity
            end
        else
            if hour >= slot.start or hour < slotEnd then
                return slot.activity
            end
        end
    end
    
    return "idle"
end


function NPCScheduler:getScheduleForNPC(npc)
    if not npc then
        return self.scheduleTemplates.farmer.spring
    end
    
    local npcType = "farmer"  -- Default
    
    if npc.personality == "worker" or npc.personality == "perfectionist" then
        npcType = "worker"
    elseif npc.personality == "casual" or npc.personality == "lazy" then
        npcType = "casual"
    end
    
    -- Get seasonal schedule for farmers
    if npcType == "farmer" then
        local season = self:getCurrentSeason()
        return self.scheduleTemplates.farmer[season] or self.scheduleTemplates.farmer.spring
    else
        return self.scheduleTemplates[npcType].default
    end
end

function NPCScheduler:getCurrentSeason()
    local month = self.currentMonth
    
    if month >= 3 and month <= 5 then
        return "spring"
    elseif month >= 6 and month <= 8 then
        return "summer"
    elseif month >= 9 and month <= 11 then
        return "autumn"
    else
        return "winter"
    end
end

function NPCScheduler:updateAIStateForActivity(npc, activity)
    if not npc or not activity or not self.npcSystem or not self.npcSystem.aiSystem then
        return
    end
    
    local aiSystem = self.npcSystem.aiSystem
    
    -- Map activities to AI states
    local activityToState = {
        -- Work activities
        field_preparation = "working",
        planting = "working",
        irrigation = "working",
        field_maintenance = "working",
        harvesting = "working",
        storage_work = "working",
        indoor_work = "working",
        equipment_repair = "working",
        planning = "working",
        work_shift = "working",
        chores = "working",
        
        -- Movement activities
        commute = "walking",
        commute_home = "walking",
        
        -- Rest activities
        sleeping = "resting",
        sleep = "resting",
        break_heat = "resting",
        
        -- Social activities
        lunch_social = "socializing",
        evening_activities = "socializing",
        personal_time = "idle",
        dinner_relax = "idle",
        leisure = "idle",
        lunch_break = "idle",
        breakfast = "idle",
        morning_routine = "idle"
    }
    
    local targetState = activityToState[activity] or "idle"
    
    -- Only change state if different
    if npc.aiState ~= targetState then
        aiSystem:setState(npc, targetState)
        
        -- Additional setup for specific activities
        if activity == "commute" or activity == "commute_home" then
            -- Set destination for commute
            if activity == "commute" then
                -- Go to work location
                if npc.assignedField then
                    aiSystem:startWalkingTo(npc, npc.assignedField.center.x, npc.assignedField.center.z)
                end
            else
                -- Go home
                aiSystem:goHome(npc)
            end
        end
    end
end

function NPCScheduler:updateNPCBasedOnTime(npc, forceUpdate)
    if not npc then
        return
    end
    
    local hour = self.currentHour
    
    -- Check if it's work time
    local workStart = self.npcSystem.settings.npcWorkStart
    local workEnd = self.npcSystem.settings.npcWorkEnd
    
    if hour >= workStart and hour < workEnd then
        -- NPC should be working if they have a field and aren't already working
        if npc.assignedField and npc.aiState ~= "working" and npc.aiState ~= "walking" then
            if self.npcSystem and self.npcSystem.aiSystem then
                self.npcSystem.aiSystem:startWorking(npc)
            end
        end
    else
        -- Non-work hours, NPC should go home if not already there
        if not self.npcSystem.aiSystem:isAtHome(npc) and npc.aiState ~= "walking" then
            if self.npcSystem and self.npcSystem.aiSystem then
                self.npcSystem.aiSystem:goHome(npc)
            end
        end
    end
    
    -- Force state update if requested
    if forceUpdate then
        local targetActivity = self:getActivityForCurrentTime(npc)
        self:updateAIStateForActivity(npc, targetActivity)
    end
end

function NPCScheduler:triggerFavorRequest(npc)
    if not npc or not self.npcSystem or not self.npcSystem.relationshipManager then
        return
    end
    
    if not self.npcSystem.relationshipManager:canAskForFavor(npc.id) then
        return
    end
    
    -- Use the favor system to generate a request
    if self.npcSystem.favorSystem then
        self.npcSystem.favorSystem:tryGenerateFavorRequest()
    end
end

function NPCScheduler:getRandomAvailableNPC()
    local availableNPCs = {}
    
    if not self.npcSystem or not self.npcSystem.activeNPCs then
        return nil
    end
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc and npc.isActive and npc.favorCooldown <= 0 then
            table.insert(availableNPCs, npc)
        end
    end
    
    if #availableNPCs > 0 then
        return availableNPCs[math.random(1, #availableNPCs)]
    end
    
    return nil
end

function NPCScheduler:scheduleNPCInteraction(npc1, npc2, time, interactionType)
    if not npc1 or not npc2 then
        return nil
    end
    
    local interactionId = #self.scheduledNPCInteractions + 1
    
    local interaction = {
        id = interactionId,
        npc1Id = npc1.id,
        npc2Id = npc2.id,
        time = time,
        type = interactionType,
        executed = false,
        data = {
            location = {
                x = (npc1.position.x + npc2.position.x) / 2,
                y = (npc1.position.y + npc2.position.y) / 2,
                z = (npc1.position.z + npc2.position.z) / 2
            }
        }
    }
    
    table.insert(self.scheduledNPCInteractions, interaction)
    return interactionId
end

function NPCScheduler:checkScheduledInteractions()
    local currentTime = g_currentMission.time
    
    for i = #self.scheduledNPCInteractions, 1, -1 do
        local interaction = self.scheduledNPCInteractions[i]
        
        if not interaction.executed and currentTime >= interaction.time then
            self:executeNPCInteraction(interaction)
            interaction.executed = true
            
            -- Remove executed interactions
            table.remove(self.scheduledNPCInteractions, i)
        end
    end
end

function NPCScheduler:executeNPCInteraction(interaction)
    -- Find the NPCs
    local npc1, npc2 = nil, nil
    
    if not self.npcSystem or not self.npcSystem.activeNPCs then
        return
    end
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc.id == interaction.npc1Id then
            npc1 = npc
        elseif npc.id == interaction.npc2Id then
            npc2 = npc
        end
    end
    
    if not npc1 or not npc2 then
        return
    end
    
    if interaction.type == "socialize" then
        -- Start socializing if both NPCs are available
        if npc1.aiState == "idle" and npc2.aiState == "idle" then
            if self.npcSystem and self.npcSystem.aiSystem then
                self.npcSystem.aiSystem:startSocializing(npc1, npc2)
                
                if self.npcSystem.settings and self.npcSystem.settings.debugMode then
                    print(string.format("Executed social interaction between %s and %s",
                        npc1.name, npc2.name))
                end
            end
        end
    end
end

function NPCScheduler:cleanupOldInteractions()
    local currentTime = g_currentMission.time
    local oneDay = 24 * 60 * 60 * 1000
    
    for i = #self.scheduledNPCInteractions, 1, -1 do
        local interaction = self.scheduledNPCInteractions[i]
        
        -- Remove interactions older than 1 day
        if currentTime - interaction.time > oneDay then
            table.remove(self.scheduledNPCInteractions, i)
        end
    end
end

function NPCScheduler:updateWeatherEffects(dt)
    -- This would integrate with the game's weather system
    -- For now, it's a placeholder for future implementation
end

function NPCScheduler:updateSeasonalSchedule(npc, month)
    if not npc then
        return
    end
    
    -- Update NPC's schedule based on season
    if npc.personality == "farmer" or npc.personality == "hardworking" then
        local season = self:getSeasonForMonth(month)
        npc.currentSeason = season
        
        if self.npcSystem and self.npcSystem.settings and self.npcSystem.settings.debugMode then
            print(string.format("NPC %s schedule updated for %s season", npc.name, season))
        end
    end
end

function NPCScheduler:getSeasonForMonth(month)
    if month >= 3 and month <= 5 then
        return "spring"
    elseif month >= 6 and month <= 8 then
        return "summer"
    elseif month >= 9 and month <= 11 then
        return "autumn"
    else
        return "winter"
    end
end

function NPCScheduler:initializeNPCSchedules()
    if not self.npcSystem or not self.npcSystem.activeNPCs then
        return
    end
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc and npc.isActive then
            self:updateNPCDailySchedule(npc, self.currentMonth)
        end
    end
end

function NPCScheduler:updateNPCDailySchedule(npc, month)
    if not npc then
        return
    end
    
    -- Reset daily schedule for NPC
    npc.currentActivity = nil
    npc.activityStartTime = nil
    npc.activityTimer = 0
    npc.canAskForFavor = false
    npc.nextFavorOpportunity = nil
    
    -- Set initial activity based on current time
    local initialActivity = self:getActivityForCurrentTime(npc)
    npc.currentActivity = initialActivity
    self:updateAIStateForActivity(npc, initialActivity)
end

function NPCScheduler:getCurrentTimeString()
    return string.format("Year %d, Month %d, Day %d - %02d:%02d", 
        self.currentYear, 
        self.currentMonth, 
        self.currentDay,
        math.floor(self.currentHour), 
        math.floor(self.currentMinute))
end

function NPCScheduler:getCurrentHour()
    return self.currentHour
end

function NPCScheduler:getCurrentMinute()
    return self.currentMinute
end

function NPCScheduler:getCurrentDay()
    return self.currentDay
end

function NPCScheduler:getCurrentMonth()
    return self.currentMonth
end

function NPCScheduler:getCurrentYear()
    return self.currentYear
end

function NPCScheduler:scheduleEvent(eventType, delayMinutes, data, priority)
    -- Schedule a one-time event
    local eventTime = g_currentMission.time + (delayMinutes * 60 * 1000)
    
    local event = {
        id = self.eventIdCounter,
        type = eventType,
        time = eventTime,
        executed = false,
        priority = priority or 2,
        data = data or {}
    }
    
    self.eventIdCounter = self.eventIdCounter + 1
    table.insert(self.dailyEvents, event)
    
    -- Keep events sorted by time and priority
    table.sort(self.dailyEvents, function(a, b)
        if a.time == b.time then
            return a.priority > b.priority
        end
        return a.time < b.time
    end)
    
    return event.id
end

function NPCScheduler:cancelEvent(eventId)
    for i, event in ipairs(self.dailyEvents) do
        if event.id == eventId then
            table.remove(self.dailyEvents, i)
            return true
        end
    end
    return false
end

function NPCScheduler:cancelNPCInteraction(interactionId)
    for i, interaction in ipairs(self.scheduledNPCInteractions) do
        if interaction.id == interactionId then
            table.remove(self.scheduledNPCInteractions, i)
            return true
        end
    end
    return false
end