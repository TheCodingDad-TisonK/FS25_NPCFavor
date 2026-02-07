-- =========================================================
-- FS25 NPC Favor Mod (version 1.0.0.0)
-- =========================================================
-- Living NPC Neighborhood System
-- =========================================================
-- Author: TisonK & Lion2009
-- =========================================================
-- COPYRIGHT NOTICE:
-- All rights reserved. Unauthorized redistribution, copying,
-- or claiming this code as your own is strictly prohibited.
-- Original idea: Lion2009
-- Implementation: TisonK
-- =========================================================

-- Add version tracking
local MOD_VERSION = "1.0.0.0"
local MOD_NAME = "FS25_NPCFavor"

local modDirectory = g_currentModDirectory
local modName = g_currentModName

print("[NPC Favor] Starting mod initialization...")

--  Define base classes and utilities
if modDirectory then
    print("[NPC Favor] Loading utility files...")
    source(modDirectory .. "src/utils/VectorHelper.lua")
    source(modDirectory .. "src/utils/TimeHelper.lua")
    
    -- Define configuration
    source(modDirectory .. "src/settings/NPCConfig.lua")
    source(modDirectory .. "src/settings/NPCSettings.lua")
    source(modDirectory .. "src/settings/NPCFavorSettingsManager.lua")

    -- Now define core systems in order
    print("[NPC Favor] Loading core systems...")
    source(modDirectory .. "src/scripts/NPCRelationshipManager.lua")
    source(modDirectory .. "src/scripts/NPCFavorSystem.lua")
    source(modDirectory .. "src/scripts/NPCEntity.lua")
    source(modDirectory .. "src/scripts/NPCAI.lua")
    source(modDirectory .. "src/scripts/NPCScheduler.lua")
    source(modDirectory .. "src/scripts/NPCInteractionUI.lua")
    
    -- gui
    source(modDirectory .. "src/settings/NPCFavorGUI.lua")

    -- Main system that uses all others
    source(modDirectory .. "src/NPCSystem.lua")
    
    print("[NPC Favor] All files loaded successfully")
else
    print("[NPC Favor] ERROR - Could not find mod directory!")
    return
end

local npcSystem = nil

-- Performance optimization: cache common checks
local function isMissionValid(mission)
    return mission and not mission.cancelLoading
end

local function isEnabled()
    return npcSystem ~= nil and npcSystem.settings and npcSystem.settings.enabled
end

local function loadedMission(mission, node)
    print("[NPC Favor] Mission load finished callback")
    
    if not isMissionValid(mission) then
        print("[NPC Favor] Mission not valid, skipping initialization")
        return
    end
    
    if npcSystem then
        print("[NPC Favor] Calling onMissionLoaded...")
        npcSystem:onMissionLoaded()
    else
        print("[NPC Favor] ERROR - npcSystem is nil in loadedMission!")
        
        -- Try to initialize now
        print("[NPC Favor] Attempting late initialization...")
        npcSystem = NPCSystem.new(mission, modDirectory, modName)
        if npcSystem then
            getfenv(0)["g_NPCSystem"] = npcSystem
            g_NPCFavorMod = {
                version = MOD_VERSION,
                name = MOD_NAME,
                system = npcSystem
            }
            print("[NPC Favor] Late initialization successful")
            npcSystem:onMissionLoaded()
        end
    end
end

local function load(mission)
    print("[NPC Favor] Load function called")
    
    if not isMissionValid(mission) then
        print("[NPC Favor] Mission not valid, skipping load")
        return
    end
    
    if npcSystem == nil then
        print("[NPC Favor] Initializing version " .. MOD_VERSION .. "...")
        
        -- Don't check for placeables here - they might not be loaded yet
        -- Wait for loadedMission callback instead
        
        print("[NPC Favor] Creating NPCSystem instance...")
        npcSystem = NPCSystem.new(mission, modDirectory, modName)
        
        if npcSystem then
            getfenv(0)["g_NPCSystem"] = npcSystem
            
            -- Add mod info for other mods to detect
            g_NPCFavorMod = {
                version = MOD_VERSION,
                name = MOD_NAME,
                system = npcSystem
            }
            
            print("[NPC Favor] NPCSystem instance created successfully")
            
            -- Initialize GUI and console commands
            if npcSystem.gui then
                npcSystem.gui:registerConsoleCommands()
            end
        else
            print("[NPC Favor] ERROR - Failed to create NPCSystem instance")
        end
    else
        print("[NPC Favor] Already initialized")
    end
end

local function unload()
    print("[NPC Favor] Unload function called")
    
    if npcSystem ~= nil then
        npcSystem:delete()
        npcSystem = nil
        getfenv(0)["g_NPCSystem"] = nil
        g_NPCFavorMod = nil
        print("[NPC Favor] Unloaded successfully")
    end
end

-- FS25 Hooks with error handling
print("[NPC Favor] Setting up game hooks...")

-- Hook the load function
if Mission00 and Mission00.load then
    print("[NPC Favor] Hooking Mission00.load")
    Mission00.load = Utils.prependedFunction(Mission00.load, load)
elseif g_currentMission and g_currentMission.load then
    print("[NPC Favor] Hooking g_currentMission.load")
    g_currentMission.load = Utils.prependedFunction(g_currentMission.load, load)
else
    print("[NPC Favor] WARNING - No load function found to hook!")
end

-- Hook the mission finished loading
if Mission00 and Mission00.loadMission00Finished then
    print("[NPC Favor] Hooking Mission00.loadMission00Finished")
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
else
    print("[NPC Favor] WARNING - Mission00.loadMission00Finished not found")
    
    -- Try alternative hook
    if g_currentMission and g_currentMission.onMissionLoaded then
        print("[NPC Favor] Hooking g_currentMission.onMissionLoaded")
        g_currentMission.onMissionLoaded = Utils.appendedFunction(g_currentMission.onMissionLoaded, function(mission)
            loadedMission(mission, nil)
        end)
    end
end

-- Hook delete for cleanup
if FSBaseMission and FSBaseMission.delete then
    print("[NPC Favor] Hooking FSBaseMission.delete")
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
end

-- Hook update for game loop
if FSBaseMission and FSBaseMission.update then
    print("[NPC Favor] Hooking FSBaseMission.update")
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
        if npcSystem and mission.isClient and mission.isRunning then
            npcSystem:update(dt)
        end
    end)
end

print("[NPC Favor] Setting up console command fallbacks...")

-- Global console command functions - these are called directly by the game
getfenv(0)["npcStatus"] = function()
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandStatus()
    else
        return "NPC System not initialized. Try reloading the save or type 'NPCReset'."
    end
end

getfenv(0)["npcSpawn"] = function(name)
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandSpawn(name or "")
    else
        return "NPC System not initialized"
    end
end

getfenv(0)["npcList"] = function()
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandList()
    else
        return "NPC System not initialized"
    end
end

getfenv(0)["npcReset"] = function()
    if g_NPCSystem then
        return g_NPCSystem:consoleCommandReset()
    else
        return "NPC System not initialized"
    end
end

getfenv(0)["npcHelp"] = function()
    return [[
=== NPC Favor Mod Commands ===
npcStatus           - Show NPC system status
npcSpawn [name]     - Spawn an NPC with optional name
npcList             - List all active NPCs
npcReset            - Reset/Initialize NPC system
npcHelp             - Show this help message
npcDebug [on|off]   - Toggle debug mode
npcReload           - Reload NPC settings
npcTest             - Test function

=== Interaction ===
Press E near an NPC to interact
Favors will appear in your task list

=== Troubleshooting ===
If commands don't work, try:
1. Type 'NPCReset' to force initialization
2. Save and reload the game
3. Check game console for NPC Favor messages
]]
end

getfenv(0)["npcDebug"] = function(state)
    if not g_NPCSystem then
        return "NPC System not initialized. Type 'NPCReset' first."
    end
    
    if state == "on" then
        g_NPCSystem.settings.debugMode = true
        g_NPCSystem.settings:save()
        return "Debug mode enabled"
    elseif state == "off" then
        g_NPCSystem.settings.debugMode = false
        g_NPCSystem.settings:save()
        return "Debug mode disabled"
    else
        return "Usage: npcDebug [on|off]"
    end
end

getfenv(0)["npcReload"] = function()
    if g_NPCSystem then
        g_NPCSystem.settings:load()
        return "NPC settings reloaded"
    else
        return "NPC System not initialized"
    end
end

getfenv(0)["npcTest"] = function()
    print("[NPC Favor] Test function called - console commands are working!")
    return "NPC Favor test successful. Type 'npcHelp' for commands."
end

print("[NPC Favor] Global console commands registered")

-- Add multiplayer compatibility check
if g_currentMission and g_currentMission.missionInfo then
    if g_currentMission.missionInfo.isMultiplayer then
        print("[NPC Favor] Multiplayer mode detected")
    end
end

print("========================================")
print("     FS25 NPC Favor v" .. MOD_VERSION .. " LOADED     ")
print("     Living Neighborhood System         ")
print("     Type 'npcHelp' in console          ")
print("     for available commands             ")
print("========================================")

-- Also try to initialize if we're already in a mission
if g_currentMission and not npcSystem then
    print("[NPC Favor] Already in mission, attempting immediate initialization...")
    load(g_currentMission)
    
    -- If mission is already loaded, try to initialize NPCs
    if g_currentMission.placeables and npcSystem then
        print("[NPC Favor] Mission already loaded, calling onMissionLoaded...")
        npcSystem:onMissionLoaded()
    end
end

-- Add global event listener for mod compatibility
addModEventListener({
    -- Called when mod is loaded
    onLoad = function()
        print("[NPC Favor] Mod event listener registered")
    end,
    
    -- Called when mod is unloaded
    onUnload = function()
        unload()
    end,
    
    -- Called when savegame is loaded
    onSavegameLoaded = function()
        print("[NPC Favor] Savegame loaded event received")
        if npcSystem then
            npcSystem:onMissionLoaded()
        else
            print("[NPC Favor] npcSystem is nil in onSavegameLoaded")
        end
    end
})

print("[NPC Favor] Mod initialization complete")