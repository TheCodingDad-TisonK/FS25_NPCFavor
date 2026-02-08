-- =========================================================
-- FS25 NPC Favor Mod - Relationship Manager
-- =========================================================
-- Manages relationships between player and NPCs
-- =========================================================

NPCRelationshipManager = {}
NPCRelationshipManager_mt = Class(NPCRelationshipManager)

function NPCRelationshipManager.new(npcSystem)
    local self = setmetatable({}, NPCRelationshipManager_mt)
    
    self.npcSystem = npcSystem
    
    -- Enhanced relationship levels with benefits
    self.RELATIONSHIP_LEVELS = {
        {
            min = 0,   max = 20,  
            name = "stranger",    
            color = {r = 1.0, g = 0.3, b = 0.3},
            benefits = {
                canAskFavor = false,
                favorFrequency = 0.1,
                giftEffectiveness = 0.5,
                discount = 0,
                helpChance = 0
            }
        },
        {
            min = 20,  max = 40,  
            name = "acquaintance",
            color = {r = 1.0, g = 0.6, b = 0.3},
            benefits = {
                canAskFavor = true,
                favorFrequency = 0.3,
                giftEffectiveness = 0.7,
                discount = 5,
                helpChance = 10
            }
        },
        {
            min = 40,  max = 60,  
            name = "friend",      
            color = {r = 0.8, g = 0.8, b = 0.3},
            benefits = {
                canAskFavor = true,
                favorFrequency = 0.6,
                giftEffectiveness = 0.9,
                discount = 10,
                helpChance = 25,
                canBorrowEquipment = true
            }
        },
        {
            min = 60,  max = 80,  
            name = "good_friend", 
            color = {r = 0.5, g = 0.8, b = 0.3},
            benefits = {
                canAskFavor = true,
                favorFrequency = 0.8,
                giftEffectiveness = 1.0,
                discount = 15,
                helpChance = 50,
                canBorrowEquipment = true,
                mayOfferHelp = true
            }
        },
        {
            min = 80,  max = 100, 
            name = "best_friend", 
            color = {r = 0.3, g = 1.0, b = 0.3},
            benefits = {
                canAskFavor = true,
                favorFrequency = 1.0,
                giftEffectiveness = 1.2,
                discount = 20,
                helpChance = 75,
                canBorrowEquipment = true,
                mayOfferHelp = true,
                mayGiveGifts = true,
                sharedResources = true
            }
        }
    }
    
    -- Relationship change reasons with detailed effects
    self.CHANGE_REASONS = {
        FAVOR_COMPLETED = {
            value = 15, 
            description = "Completed a favor",
            moodEffect = "positive",
            duration = "permanent"
        },
        FAVOR_FAILED = {
            value = -10, 
            description = "Failed a favor",
            moodEffect = "negative",
            duration = "temporary",
            decayTime = 24 * 60 * 60 * 1000 -- 24 hours
        },
        FAVOR_ABANDONED = {
            value = -5, 
            description = "Abandoned a favor",
            moodEffect = "negative",
            duration = "temporary",
            decayTime = 12 * 60 * 60 * 1000 -- 12 hours
        },
        GIFT_GIVEN = {
            value = 5, 
            description = "Gave a gift",
            moodEffect = "positive",
            duration = "permanent",
            maxPerDay = 3
        },
        HELPED_WORK = {
            value = 8, 
            description = "Helped with work",
            moodEffect = "positive",
            duration = "permanent"
        },
        IGNORED_REQUEST = {
            value = -5, 
            description = "Ignored request",
            moodEffect = "negative",
            duration = "temporary",
            decayTime = 6 * 60 * 60 * 1000 -- 6 hours
        },
        ARGUMENT = {
            value = -15, 
            description = "Had an argument",
            moodEffect = "negative",
            duration = "temporary",
            decayTime = 48 * 60 * 60 * 1000 -- 48 hours
        },
        DAILY_INTERACTION = {
            value = 1, 
            description = "Daily interaction",
            moodEffect = "neutral",
            duration = "daily",
            maxPerDay = 1
        },
        TRADE_COMPLETED = {
            value = 3, 
            description = "Completed a trade",
            moodEffect = "positive",
            duration = "permanent"
        },
        EMERGENCY_HELP = {
            value = 25, 
            description = "Helped in emergency",
            moodEffect = "very_positive",
            duration = "permanent"
        }
    }
    
    -- Relationship history storage with decay system
    self.relationshipHistory = {} -- npcId -> array of changes
    self.dailyInteractionTracker = {} -- Tracks daily interactions per NPC
    self.giftTracker = {} -- Tracks gifts given per NPC per day
    
    -- Mood system for temporary relationship modifiers
    self.npcMoods = {} -- npcId -> {mood, modifier, expiration}
    
    return self
end

function NPCRelationshipManager:updateRelationship(npcId, change, reason)
    local npc = self:getNPCById(npcId)
    if not npc then
        return false
    end
    
    -- Check daily limits
    if not self:canApplyRelationshipChange(npcId, reason, change) then
        if self.npcSystem.settings.debugMode then
            print(string.format("Relationship change blocked for %s: %s (daily limit reached)", 
                npc.name, reason))
        end
        return false
    end
    
    -- Store old value
    local oldValue = npc.relationship or 50
    local oldLevel = self:getRelationshipLevel(oldValue)
    
    -- Apply mood modifier if any
    local moodModifier = self:getMoodModifier(npcId)
    local effectiveChange = change
    if moodModifier ~= 0 then
        effectiveChange = math.floor(change * (1 + moodModifier))
        if self.npcSystem.settings.debugMode then
            print(string.format("Mood modifier applied: %+.0f%%", moodModifier * 100))
        end
    end
    
    -- Apply change with bounds
    local newValue = oldValue + effectiveChange
    newValue = math.max(0, math.min(100, newValue))
    
    npc.relationship = newValue
    
    -- Store in history with full details
    local historyEntry = {
        time = g_currentMission.time,
        oldValue = oldValue,
        newValue = newValue,
        change = effectiveChange,
        baseChange = change,
        reason = reason or "unknown",
        moodModifier = moodModifier,
        location = {
            x = npc.position.x,
            y = npc.position.y,
            z = npc.position.z
        }
    }
    
    self:addRelationshipHistory(npcId, historyEntry)
    
    -- Update daily trackers
    self:updateDailyTrackers(npcId, reason)
    
    -- Update mood based on change
    self:updateNPCMood(npcId, effectiveChange, reason)
    
    -- Check if level changed
    local newLevel = self:getRelationshipLevel(npc.relationship)
    if oldLevel.name ~= newLevel.name then
        self:onRelationshipLevelChange(npc, oldLevel, newLevel, historyEntry)
    end
    
    -- Debug output
    if self.npcSystem.settings.debugMode then
        print(string.format("Relationship update: %s %+d = %d (%s -> %s) [Reason: %s]", 
            npc.name, effectiveChange, npc.relationship, oldLevel.name, newLevel.name, reason))
    end
    
    -- Update NPC behavior based on new relationship
    self:updateNPCBehaviorForRelationship(npc, newLevel)
    
    return true
end

function NPCRelationshipManager:canApplyRelationshipChange(npcId, reason, change)
    local currentTime = g_currentMission.time
    local day = math.floor(currentTime / (24 * 60 * 60 * 1000))
    
    -- Initialize trackers for this NPC if needed
    if not self.dailyInteractionTracker[npcId] then
        self.dailyInteractionTracker[npcId] = {day = day, count = 0}
    end
    
    if not self.giftTracker[npcId] then
        self.giftTracker[npcId] = {day = day, count = 0}
    end
    
    -- Check if day has changed
    if self.dailyInteractionTracker[npcId].day ~= day then
        self.dailyInteractionTracker[npcId] = {day = day, count = 0}
    end
    
    if self.giftTracker[npcId].day ~= day then
        self.giftTracker[npcId] = {day = day, count = 0}
    end
    
    -- Check specific limits (reason strings are lowercase to match callers)
    if reason == "daily_interaction" then
        if self.dailyInteractionTracker[npcId].count >= 1 then
            return false
        end
        self.dailyInteractionTracker[npcId].count = self.dailyInteractionTracker[npcId].count + 1
        
    elseif reason == "gift_given" then
        local reasonData = self.CHANGE_REASONS.GIFT_GIVEN
        if self.giftTracker[npcId].count >= (reasonData.maxPerDay or 3) then
            return false
        end
        self.giftTracker[npcId].count = self.giftTracker[npcId].count + 1
    end
    
    return true
end

function NPCRelationshipManager:updateDailyTrackers(npcId, reason)
    -- This is called after the change is applied to update trackers
    -- Specific tracking is handled in canApplyRelationshipChange
end

function NPCRelationshipManager:getMoodModifier(npcId)
    if not self.npcMoods[npcId] then
        return 0
    end
    
    local mood = self.npcMoods[npcId]
    
    -- Check if mood has expired
    if mood.expiration and g_currentMission.time > mood.expiration then
        self.npcMoods[npcId] = nil
        return 0
    end
    
    return mood.modifier or 0
end

function NPCRelationshipManager:updateNPCMood(npcId, change, reason)
    local moodChange = 0
    
    -- Determine mood change based on relationship change
    if change > 0 then
        moodChange = 0.1 * (change / 10) -- Positive mood for positive changes
    elseif change < 0 then
        moodChange = -0.2 * (math.abs(change) / 10) -- Stronger negative mood for negative changes
    end
    
    -- Initialize mood if needed
    if not self.npcMoods[npcId] then
        self.npcMoods[npcId] = {
            value = 0,
            modifier = 0,
            expiration = nil
        }
    end
    
    -- Update mood value (-1 to 1 range)
    local mood = self.npcMoods[npcId]
    mood.value = math.max(-1, math.min(1, mood.value + moodChange))
    
    -- Calculate modifier from mood value
    mood.modifier = mood.value * 0.5 -- Mood affects relationship changes by +/- 50%
    
    -- Set expiration for temporary moods
    if moodChange ~= 0 then
        local decayTime = 2 * 60 * 60 * 1000 -- 2 hours decay time
        mood.expiration = g_currentMission.time + decayTime
    end
    
    -- Debug output
    if self.npcSystem.settings.debugMode and moodChange ~= 0 then
        local npc = self:getNPCById(npcId)
        if npc then
            print(string.format("NPC %s mood: %.2f -> %.2f (modifier: %+.0f%%)", 
                npc.name, mood.value - moodChange, mood.value, mood.modifier * 100))
        end
    end
end

function NPCRelationshipManager:getNPCById(npcId)
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc.id == npcId then
            return npc
        end
    end
    return nil
end

function NPCRelationshipManager:getRelationshipLevel(value)
    for _, level in ipairs(self.RELATIONSHIP_LEVELS) do
        if value >= level.min and value <= level.max then
            return level
        end
    end
    
    -- Fallback
    return self.RELATIONSHIP_LEVELS[1]
end

function NPCRelationshipManager:addRelationshipHistory(npcId, change)
    if not self.relationshipHistory[npcId] then
        self.relationshipHistory[npcId] = {}
    end
    
    table.insert(self.relationshipHistory[npcId], change)
    
    -- Keep only last 100 entries
    if #self.relationshipHistory[npcId] > 100 then
        table.remove(self.relationshipHistory[npcId], 1)
    end
end

function NPCRelationshipManager:onRelationshipLevelChange(npc, oldLevel, newLevel, historyEntry)
    -- Show notification
    if self.npcSystem.settings.showNotifications then
        local message = ""
        local title = "Relationship Changed"
        
        if newLevel.min > oldLevel.min then
            -- Relationship improved
            title = "Relationship Improved!"
            message = string.format("Your relationship with %s has improved to %s!", 
                npc.name, newLevel.name)
            
            -- List benefits of new level
            if newLevel.benefits then
                local benefits = ""
                if newLevel.benefits.canAskFavor and not oldLevel.benefits.canAskFavor then
                    benefits = benefits .. "\n- Can now ask for favors"
                end
                if newLevel.benefits.canBorrowEquipment and not oldLevel.benefits.canBorrowEquipment then
                    benefits = benefits .. "\n- Can now borrow equipment"
                end
                if newLevel.benefits.discount > (oldLevel.benefits.discount or 0) then
                    benefits = benefits .. string.format("\n- %d%% discount on trades", newLevel.benefits.discount)
                end
                
                if benefits ~= "" then
                    message = message .. "\n\nNew benefits:" .. benefits
                end
            end
        else
            -- Relationship worsened
            title = "Relationship Worsened"
            message = string.format("Your relationship with %s has worsened to %s.", 
                npc.name, newLevel.name)
            
            -- List lost benefits
            if oldLevel.benefits then
                local lostBenefits = ""
                if oldLevel.benefits.canAskFavor and not newLevel.benefits.canAskFavor then
                    lostBenefits = lostBenefits .. "\n- Can no longer ask for favors"
                end
                if oldLevel.benefits.canBorrowEquipment and not newLevel.benefits.canBorrowEquipment then
                    lostBenefits = lostBenefits .. "\n- Can no longer borrow equipment"
                end
                if (oldLevel.benefits.discount or 0) > newLevel.benefits.discount then
                    lostBenefits = lostBenefits .. string.format("\n- Lost %d%% discount", 
                        (oldLevel.benefits.discount or 0) - newLevel.benefits.discount)
                end
                
                if lostBenefits ~= "" then
                    message = message .. "\n\nLost benefits:" .. lostBenefits
                end
            end
        end
        
        self.npcSystem:showNotification(title, message)
    end
    
    -- Update NPC behavior based on new relationship level
    self:updateNPCBehaviorForRelationship(npc, newLevel)
    
    -- Log for debugging
    if self.npcSystem.settings.debugMode then
        print(string.format("Relationship level change: %s (%s -> %s)", 
            npc.name, oldLevel.name, newLevel.name))
    end
end

function NPCRelationshipManager:updateNPCBehaviorForRelationship(npc, level)
    -- Update NPC's behavior based on relationship level benefits
    if level.benefits then
        npc.favorFrequencyMultiplier = level.benefits.favorFrequency or 1.0
        npc.conversationInterest = level.benefits.favorFrequency or 0.5
        npc.willHelpPlayer = level.benefits.helpChance and (math.random(1, 100) <= level.benefits.helpChance)
        npc.mayOfferGifts = level.benefits.mayGiveGifts or false
        npc.canBorrowEquipment = level.benefits.canBorrowEquipment or false
        npc.tradeDiscount = level.benefits.discount or 0
        
        -- Update AI personality modifiers
        if npc.aiPersonalityModifiers then
            -- Higher relationship makes NPC more helpful
            npc.aiPersonalityModifiers.generosity = 0.5 + (level.min / 100) * 0.5
            npc.aiPersonalityModifiers.sociability = 0.3 + (level.min / 100) * 0.7
        end
    end
    
    -- Update mood based on relationship level
    if level.min >= 60 then
        -- Good friends have positive base mood
        if not self.npcMoods[npc.id] then
            self.npcMoods[npc.id] = {
                value = 0.2,
                modifier = 0.1,
                expiration = nil
            }
        end
    elseif level.min <= 20 then
        -- Strangers have neutral to slightly negative mood
        if not self.npcMoods[npc.id] then
            self.npcMoods[npc.id] = {
                value = -0.1,
                modifier = -0.05,
                expiration = nil
            }
        end
    end
end

function NPCRelationshipManager:getRelationshipInfo(npcId)
    local npc = self:getNPCById(npcId)
    if not npc then
        return nil
    end
    
    local level = self:getRelationshipLevel(npc.relationship)
    local history = self.relationshipHistory[npcId] or {}
    local mood = self.npcMoods[npcId]
    
    -- Calculate statistics
    local totalChanges = #history
    local positiveChanges = 0
    local negativeChanges = 0
    local totalPositive = 0
    local totalNegative = 0
    
    for _, change in ipairs(history) do
        if change.change > 0 then
            positiveChanges = positiveChanges + 1
            totalPositive = totalPositive + change.change
        elseif change.change < 0 then
            negativeChanges = negativeChanges + 1
            totalNegative = totalNegative + math.abs(change.change)
        end
    end
    
    -- Calculate trend (last 10 changes)
    local trend = 0
    local recentChanges = math.min(10, #history)
    for i = #history, #history - recentChanges + 1, -1 do
        if i >= 1 then
            trend = trend + (history[i].change or 0)
        end
    end
    
    -- Estimate next favor time
    local nextFavorEstimate = self:estimateNextFavorTime(npc)
    
    return {
        npc = npc,
        value = npc.relationship,
        level = level,
        benefits = level.benefits,
        history = history,
        lastChange = #history > 0 and history[#history] or nil,
        nextFavorEstimate = nextFavorEstimate,
        
        -- Statistics
        statistics = {
            totalChanges = totalChanges,
            positiveChanges = positiveChanges,
            negativeChanges = negativeChanges,
            totalPositive = totalPositive,
            totalNegative = totalNegative,
            netChange = totalPositive - totalNegative,
            trend = trend,
            mood = mood
        }
    }
end

function NPCRelationshipManager:estimateNextFavorTime(npc)
    if not npc or npc.favorCooldown <= 0 then
        return "now"
    end
    
    -- Calculate time until next favor can be asked
    local hours = npc.favorCooldown / (60 * 60 * 1000)
    
    if hours < 1 then
        local minutes = hours * 60
        return string.format("%.0f minutes", minutes)
    elseif hours < 24 then
        return string.format("%.1f hours", hours)
    else
        local days = hours / 24
        if days < 7 then
            return string.format("%.1f days", days)
        else
            local weeks = days / 7
            return string.format("%.1f weeks", weeks)
        end
    end
end

function NPCRelationshipManager:getAllRelationships()
    local relationships = {}
    
    for _, npc in ipairs(self.npcSystem.activeNPCs) do
        if npc.isActive then
            local info = self:getRelationshipInfo(npc.id)
            if info then
                table.insert(relationships, info)
            end
        end
    end
    
    -- Sort by relationship value (highest first)
    table.sort(relationships, function(a, b)
        return a.value > b.value
    end)
    
    return relationships
end

function NPCRelationshipManager:giveGiftToNPC(npcId, giftType, giftValue)
    local npc = self:getNPCById(npcId)
    if not npc then
        return false
    end
    
    -- Check daily gift limit
    local currentTime = g_currentMission.time
    local day = math.floor(currentTime / (24 * 60 * 60 * 1000))
    
    if not self.giftTracker[npcId] then
        self.giftTracker[npcId] = {day = day, count = 0}
    end
    
    if self.giftTracker[npcId].day ~= day then
        self.giftTracker[npcId] = {day = day, count = 0}
    end
    
    local reasonData = self.CHANGE_REASONS.GIFT_GIVEN
    if self.giftTracker[npcId].count >= (reasonData.maxPerDay or 3) then
        if self.npcSystem.settings.showNotifications then
            self.npcSystem:showNotification(
                "Gift Not Accepted",
                string.format("%s has received enough gifts for today.", npc.name)
            )
        end
        return false
    end
    
    -- Calculate relationship change based on gift
    local baseChange = 0
    
    if giftType == "money" then
        baseChange = math.min(10, math.floor(giftValue / 100))
    elseif giftType == "crops" then
        baseChange = 5
    elseif giftType == "vehicle" then
        baseChange = 15
    elseif giftType == "tool" then
        baseChange = 8
    elseif giftType == "food" then
        baseChange = 3
    elseif giftType == "drink" then
        baseChange = 2
    else
        baseChange = 3
    end
    
    -- Apply personality modifier
    local personalityMod = 1.0
    if npc.personality == "generous" then
        personalityMod = 1.2 -- Appreciates gifts more
    elseif npc.personality == "greedy" then
        personalityMod = 1.5 -- Really appreciates valuable gifts
    elseif npc.personality == "stingy" then
        personalityMod = 0.8 -- Less appreciative
    elseif npc.personality == "grumpy" then
        personalityMod = 0.7 -- Hard to please
    end
    
    -- Apply relationship level effectiveness
    local level = self:getRelationshipLevel(npc.relationship)
    local effectiveness = level.benefits.giftEffectiveness or 1.0
    
    local totalChange = math.floor(baseChange * personalityMod * effectiveness)
    
    -- Update relationship
    local success = self:updateRelationship(npcId, totalChange, "gift_given")
    
    if success then
        -- Update gift tracker
        self.giftTracker[npcId].count = self.giftTracker[npcId].count + 1
        
        -- Show notification
        if self.npcSystem.settings.showNotifications then
            local giftName = giftType
            if giftType == "money" then
                giftName = string.format("$%d", giftValue)
            end
            
            self.npcSystem:showNotification(
                "Gift Given",
                string.format("%s appreciated your %s! (+%d relationship)", 
                    npc.name, giftName, totalChange)
            )
        end
        
        return true
    end
    
    return false
end

function NPCRelationshipManager:canAskForFavor(npcId)
    local npc = self:getNPCById(npcId)
    if not npc then
        return false
    end
    
    -- Check cooldown
    if npc.favorCooldown > 0 then
        return false
    end
    
    -- Check relationship level benefits
    local level = self:getRelationshipLevel(npc.relationship)
    if not level.benefits.canAskFavor then
        return false
    end
    
    -- Check if NPC is in a good mood (mood affects willingness)
    local moodModifier = self:getMoodModifier(npcId)
    local baseChance = level.benefits.favorFrequency or 0.5
    
    -- Adjust chance based on mood
    local adjustedChance = baseChance * (1 + moodModifier)
    
    -- Personality modifiers
    if npc.personality == "generous" then
        adjustedChance = adjustedChance * 0.8 -- Less likely to ask (more giving)
    elseif npc.personality == "greedy" then
        adjustedChance = adjustedChance * 1.5 -- More likely to ask
    elseif npc.personality == "friendly" then
        adjustedChance = adjustedChance * 1.2
    elseif npc.personality == "grumpy" then
        adjustedChance = adjustedChance * 0.7
    end
    
    -- Time of day factor (more likely during working hours)
    local hour = self.npcSystem.scheduler:getCurrentHour()
    if hour >= 8 and hour <= 18 then
        adjustedChance = adjustedChance * 1.3
    else
        adjustedChance = adjustedChance * 0.5
    end
    
    return math.random() < adjustedChance
end

function NPCRelationshipManager:getRelationshipColor(value)
    local level = self:getRelationshipLevel(value)
    return level.color
end

function NPCRelationshipManager:getRelationshipTrend(npcId)
    local history = self.relationshipHistory[npcId] or {}
    if #history < 2 then
        return "stable"
    end
    
    -- Analyze last 5 changes
    local recentCount = math.min(5, #history)
    local sum = 0
    
    for i = #history, #history - recentCount + 1, -1 do
        if i >= 1 then
            sum = sum + (history[i].change or 0)
        end
    end
    
    if sum > 5 then
        return "improving"
    elseif sum < -5 then
        return "declining"
    else
        return "stable"
    end
end

function NPCRelationshipManager:getNPCBenefits(npcId)
    local npc = self:getNPCById(npcId)
    if not npc then
        return {}
    end
    
    local level = self:getRelationshipLevel(npc.relationship)
    return level.benefits or {}
end

function NPCRelationshipManager:update(dt)
    self.updateTimer = (self.updateTimer or 0) + dt
    -- Run relationship housekeeping every 60 seconds (not every frame)
    if self.updateTimer >= 60 then
        self.updateTimer = 0
        for _, npc in ipairs(self.npcSystem.activeNPCs) do
            if npc.isActive then
                self:updateNPCMood(npc.id)
                local level = self:getRelationshipLevel(npc.relationship)
                self:updateNPCBehaviorForRelationship(npc, level)
            end
        end
        -- Cleanup expired moods and old history
        self:cleanupExpiredData()
    end
end

function NPCRelationshipManager:cleanupExpiredData()
    local currentTime = g_currentMission.time
    
    -- Clean up expired moods
    for npcId, mood in pairs(self.npcMoods) do
        if mood.expiration and currentTime > mood.expiration then
            self.npcMoods[npcId] = nil
        end
    end
    
    -- Clean up old history entries (older than 30 days)
    local thirtyDays = 30 * 24 * 60 * 60 * 1000
    for npcId, history in pairs(self.relationshipHistory) do
        for i = #history, 1, -1 do
            if currentTime - history[i].time > thirtyDays then
                table.remove(history, i)
            end
        end
        
        -- Remove empty history
        if #history == 0 then
            self.relationshipHistory[npcId] = nil
        end
    end
end