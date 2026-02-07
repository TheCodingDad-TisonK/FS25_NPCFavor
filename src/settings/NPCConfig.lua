-- =========================================================
-- FS25 NPC Favor Mod - Configuration Data
-- =========================================================
-- Contains NPC definitions, names, and configuration data
-- =========================================================

NPCConfig = {}
local NPCConfig_mt = Class(NPCConfig)

function NPCConfig.new()
    local self = setmetatable({}, NPCConfig_mt)
    
    -- NPC Names (using localization keys)
    self.npcNames = {
        "npc_name_1", "npc_name_2", "npc_name_3", 
        "npc_name_4", "npc_name_5", "npc_name_6"
    }
    
    -- Personalities
    self.personalities = {
        "hardworking",  -- Works long hours, rarely takes breaks
        "lazy",         -- Takes many breaks, short work days
        "social",       -- Likes to talk with other NPCs
        "loner",        -- Prefers to work alone
        "generous",     -- More likely to give gifts/help
        "greedy",       -- Less likely to help, wants payment
        "friendly",     -- Quick to build relationships
        "grumpy",       -- Slow to build relationships
        "early_riser",  -- Starts work early
        "night_owl",    -- Works late, starts late
        "perfectionist",-- Takes time to do things right
        "hasty"         -- Works quickly, may make mistakes
    }
    
    -- Vehicle types NPCs can own
    self.vehicleTypes = {
        "tractor",
        "harvester",
        "truck",
        "trailer",
        "plow",
        "seeder",
        "sprayer",
        "loader"
    }
    
    -- Vehicle colors
    self.vehicleColors = {
        {r = 1.0, g = 0.2, b = 0.2, name = "red"},
        {r = 0.2, g = 0.6, b = 1.0, name = "blue"},
        {r = 0.2, g = 0.8, b = 0.2, name = "green"},
        {r = 1.0, g = 1.0, b = 0.2, name = "yellow"},
        {r = 0.8, g = 0.5, b = 0.2, name = "orange"},
        {r = 0.6, g = 0.2, b = 0.8, name = "purple"},
        {r = 0.9, g = 0.9, b = 0.9, name = "white"},
        {r = 0.2, g = 0.2, b = 0.2, name = "black"}
    }
    
    -- Clothing sets
    self.clothingSets = {
        farmer = {"overalls", "boots", "hat"},
        worker = {"jeans", "t-shirt", "vest"},
        casual = {"shirt", "pants", "jacket"},
        formal = {"suit", "tie", "dress_shoes"}
    }
    
    -- Age ranges by personality type
    self.ageRanges = {
        young = {min = 25, max = 35},
        middle = {min = 36, max = 50},
        senior = {min = 51, max = 65}
    }
    
    return self
end

function NPCConfig:getRandomNPCName()
    local nameKey = self.npcNames[math.random(1, #self.npcNames)]
    local name = g_i18n:getText(nameKey)
    
    if not name or name == "" then
        -- Fallback names
        local fallbackNames = {
            "Old MacDonald", "Farmer Joe", "Mrs. Henderson", 
            "Young Peter", "Anna Schmidt", "Hans Bauer"
        }
        name = fallbackNames[math.random(1, #fallbackNames)]
    end
    
    return name
end

function NPCConfig:getRandomPersonality()
    return self.personalities[math.random(1, #self.personalities)]
end

function NPCConfig:getRandomVehicleType()
    return self.vehicleTypes[math.random(1, #self.vehicleTypes)]
end

function NPCConfig:getRandomVehicleColor()
    return self.vehicleColors[math.random(1, #self.vehicleColors)]
end

function NPCConfig:getRandomClothing()
    local sets = {"farmer", "worker", "casual", "formal"}
    local set = sets[math.random(1, #sets)]
    return self.clothingSets[set]
end

function NPCConfig:getRandomNPCModel()
    -- In actual implementation, return path to 3D model
    -- For now, return a placeholder
    return "farmer"
end

function NPCConfig:getAgeForPersonality(personality)
    local ageRange = self.ageRanges.middle -- Default
    
    if personality == "young" or personality == "hasty" then
        ageRange = self.ageRanges.young
    elseif personality == "senior" or personality == "grumpy" then
        ageRange = self.ageRanges.senior
    end
    
    return math.random(ageRange.min, ageRange.max)
end

function NPCConfig:getWorkHoursForPersonality(personality)
    local workStart, workEnd
    
    if personality == "early_riser" then
        workStart = 6
        workEnd = 16
    elseif personality == "night_owl" then
        workStart = 10
        workEnd = 20
    elseif personality == "lazy" then
        workStart = 9
        workEnd = 15
    elseif personality == "hardworking" then
        workStart = 7
        workEnd = 19
    else
        workStart = 8
        workEnd = 17
    end
    
    return workStart, workEnd
end

function NPCConfig:getFavorFrequencyForPersonality(personality)
    if personality == "generous" then
        return 2 -- Asks for favors less often
    elseif personality == "greedy" then
        return 5 -- Asks for favors more often
    elseif personality == "friendly" then
        return 3
    elseif personality == "grumpy" then
        return 7
    else
        return 4 -- Default
    end
end

function NPCConfig:getGiftPreferenceForPersonality(personality)
    if personality == "greedy" then
        return {"money", "vehicle", "expensive"}
    elseif personality == "generous" then
        return {"crops", "homemade", "useful"}
    elseif personality == "farmer" then
        return {"tools", "seeds", "equipment"}
    else
        return {"general", "food", "drink"}
    end
end

function NPCConfig:getDefaultVehiclesForPersonality(personality)
    local vehicles = {}
    
    -- Everyone gets at least a tractor
    table.insert(vehicles, {
        type = "tractor",
        color = self:getRandomVehicleColor()
    })
    
    -- Additional vehicles based on personality
    if personality == "hardworking" or personality == "perfectionist" then
        -- More equipment for serious farmers
        table.insert(vehicles, {type = "harvester", color = self:getRandomVehicleColor()})
        table.insert(vehicles, {type = "trailer", color = self:getRandomVehicleColor()})
    elseif personality == "lazy" then
        -- Minimal equipment
        table.insert(vehicles, {type = "truck", color = self:getRandomVehicleColor()})
    elseif personality == "generous" then
        -- Well-equipped to help others
        table.insert(vehicles, {type = "loader", color = self:getRandomVehicleColor()})
        table.insert(vehicles, {type = "trailer", color = self:getRandomVehicleColor()})
    else
        -- Standard farmer
        table.insert(vehicles, {type = "plow", color = self:getRandomVehicleColor()})
        table.insert(vehicles, {type = "seeder", color = self:getRandomVehicleColor()})
    end
    
    return vehicles
end