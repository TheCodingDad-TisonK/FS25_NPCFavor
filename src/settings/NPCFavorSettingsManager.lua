-- =========================================================
-- FS25 NPC Favor Mod - Settings Manager
-- =========================================================
-- Manages loading and saving of NPC Favor settings
-- =========================================================

NPCFavorSettingsManager = {}
NPCFavorSettingsManager_mt = Class(NPCFavorSettingsManager)

NPCFavorSettingsManager.MOD_NAME = "FS25_NPCFavor"
NPCFavorSettingsManager.XMLTAG = "NPCFavorSettings"

NPCFavorSettingsManager.defaultConfig = {
    enabled = true,
    maxNPCs = 8,
    npcWorkStart = 8,
    npcWorkEnd = 17,
    favorFrequency = 3,
    npcSpawnDistance = 150,
    showNames = true,
    showNotifications = true,
    showFavorList = true,
    showRelationshipBars = true,
    showNPCPaths = false,
    nameDisplayDistance = 50,
    notificationDuration = 4000,
    enableFavors = true,
    enableGifts = true,
    enableRelationshipSystem = true,
    npcHelpPlayer = true,
    npcSocialize = true,
    npcDriveVehicles = true,
    allowMultipleFavors = true,
    maxActiveFavors = 5,
    favorTimeLimit = true,
    relationshipDecay = false,
    decayRate = 1,
    favorDifficulty = "normal",
    relationshipGainMultiplier = 1.0,
    relationshipLossMultiplier = 1.0,
    favorRewardMultiplier = 1.0,
    favorPenaltyMultiplier = 1.0,
    npcActivityLevel = "normal",
    npcMovementSpeed = 1.0,
    npcWorkDuration = 1.0,
    npcBreakFrequency = 1.0,
    npcSocialFrequency = 1.0,
    debugMode = false,
    showPaths = false,
    showSpawnPoints = false,
    showAIDecisions = false,
    showRelationshipChanges = false,
    logToFile = false,
    soundEffects = true,
    voiceLines = true,
    uiSounds = true,
    notificationSound = true,
    updateFrequency = "normal",
    npcRenderDistance = 200,
    npcUpdateDistance = 300,
    batchUpdates = true,
    maxUpdatesPerFrame = 5,
    syncNPCs = true,
    syncRelationships = true,
    syncFavors = true
}

function NPCFavorSettingsManager.new()
    local self = setmetatable({}, NPCFavorSettingsManager_mt)
    return self
end

function NPCFavorSettingsManager:getSavegameXmlFilePath()
    if g_currentMission and g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory then
        return ("%s/npc_favor_settings.xml"):format(g_currentMission.missionInfo.savegameDirectory)
    end
    return nil
end

function NPCFavorSettingsManager:loadSettings(settingsObject)
    local xmlPath = self:getSavegameXmlFilePath()
    
    if xmlPath and fileExists(xmlPath) then
        print("[NPC Settings] Loading settings from: " .. xmlPath)
        local xml = XMLFile.load("npc_config", xmlPath)
        if xml then
            -- Core settings
            settingsObject.enabled = xml:getBool(self.XMLTAG .. ".enabled", self.defaultConfig.enabled)
            settingsObject.maxNPCs = xml:getInt(self.XMLTAG .. ".maxNPCs", self.defaultConfig.maxNPCs)
            settingsObject.npcWorkStart = xml:getInt(self.XMLTAG .. ".npcWorkStart", self.defaultConfig.npcWorkStart)
            settingsObject.npcWorkEnd = xml:getInt(self.XMLTAG .. ".npcWorkEnd", self.defaultConfig.npcWorkEnd)
            settingsObject.favorFrequency = xml:getInt(self.XMLTAG .. ".favorFrequency", self.defaultConfig.favorFrequency)
            
            -- Display settings
            settingsObject.showNames = xml:getBool(self.XMLTAG .. ".showNames", self.defaultConfig.showNames)
            settingsObject.showNotifications = xml:getBool(self.XMLTAG .. ".showNotifications", self.defaultConfig.showNotifications)
            settingsObject.showFavorList = xml:getBool(self.XMLTAG .. ".showFavorList", self.defaultConfig.showFavorList)
            settingsObject.debugMode = xml:getBool(self.XMLTAG .. ".debugMode", self.defaultConfig.debugMode)
            settingsObject.enableFavors = xml:getBool(self.XMLTAG .. ".enableFavors", self.defaultConfig.enableFavors)
            
            xml:delete()
            print("[NPC Settings] Settings loaded successfully")
            return
        end
    end
    
    -- Use defaults if no settings file exists
    print("[NPC Settings] Using default settings")
    for key, value in pairs(self.defaultConfig) do
        settingsObject[key] = value
    end
end

function NPCFavorSettingsManager:saveSettings(settingsObject)
    local xmlPath = self:getSavegameXmlFilePath()
    if not xmlPath then 
        print("[NPC Settings] Could not get savegame path")
        return 
    end
    
    print("[NPC Settings] Saving settings to: " .. xmlPath)
    
    local xml = XMLFile.create("npc_config", xmlPath, self.XMLTAG)
    if xml then
        -- Core settings
        xml:setBool(self.XMLTAG .. ".enabled", settingsObject.enabled)
        xml:setInt(self.XMLTAG .. ".maxNPCs", settingsObject.maxNPCs)
        xml:setInt(self.XMLTAG .. ".npcWorkStart", settingsObject.npcWorkStart)
        xml:setInt(self.XMLTAG .. ".npcWorkEnd", settingsObject.npcWorkEnd)
        xml:setInt(self.XMLTAG .. ".favorFrequency", settingsObject.favorFrequency)
        
        -- Display settings
        xml:setBool(self.XMLTAG .. ".showNames", settingsObject.showNames)
        xml:setBool(self.XMLTAG .. ".showNotifications", settingsObject.showNotifications)
        xml:setBool(self.XMLTAG .. ".showFavorList", settingsObject.showFavorList)
        xml:setBool(self.XMLTAG .. ".debugMode", settingsObject.debugMode)
        xml:setBool(self.XMLTAG .. ".enableFavors", settingsObject.enableFavors)
        
        xml:save()
        xml:delete()
        print("[NPC Settings] Settings saved successfully")
    else
        print("[NPC Settings] Failed to create XML file")
    end
end