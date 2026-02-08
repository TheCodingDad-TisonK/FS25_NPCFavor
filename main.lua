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
    source(modDirectory .. "src/settings/NPCSettingsIntegration.lua")

    -- Multiplayer events (must load before NPCSystem which references them)
    print("[NPC Favor] Loading multiplayer events...")
    source(modDirectory .. "src/events/NPCStateSyncEvent.lua")
    source(modDirectory .. "src/events/NPCInteractionEvent.lua")
    source(modDirectory .. "src/events/NPCSettingsSyncEvent.lua")

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
        if npcSystem then
            npcSystem:update(dt)
        end
    end)
end

-- =========================================================
-- E Key Input Binding (RVB Pattern from UsedPlus)
-- =========================================================
-- Hook PlayerInputComponent.registerActionEvents to add NPC_INTERACT
-- Game renders [E] automatically, we provide dynamic text

local npcInteractActionEventId = nil
local npcDialogCloseActionEventId = nil
local npcInteractOriginalFunc = nil

local function npcInteractActionCallback(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue <= 0 then
        return
    end

    if not npcSystem or not npcSystem.interactionUI then
        return
    end

    -- If dialog is already open, E cycles through options
    if npcSystem.interactionUI.isDialogOpen then
        npcSystem.interactionUI:selectAndExecuteNextOption()
        return
    end

    -- Dialog not open: find nearest interactable NPC and open dialog
    if npcSystem.nearbyNPCs then
        local nearest = nil
        local nearestDist = 999

        for _, npc in ipairs(npcSystem.nearbyNPCs) do
            if npc.canInteract and npc.interactionDistance < nearestDist then
                nearest = npc
                nearestDist = npc.interactionDistance
            end
        end

        if nearest then
            print(string.format("[NPC Favor] Interacting with %s", nearest.name))
            npcSystem.interactionUI:openDialog(nearest)
        end
    end
end

local function npcDialogCloseCallback(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue <= 0 then
        return
    end

    if npcSystem and npcSystem.interactionUI and npcSystem.interactionUI.isDialogOpen then
        npcSystem.interactionUI:closeDialog()
    end
end

local function hookNPCInteractInput()
    if npcInteractOriginalFunc ~= nil then
        return -- Already hooked
    end

    if PlayerInputComponent == nil or PlayerInputComponent.registerActionEvents == nil then
        print("[NPC Favor] PlayerInputComponent.registerActionEvents not available")
        return
    end

    npcInteractOriginalFunc = PlayerInputComponent.registerActionEvents

    PlayerInputComponent.registerActionEvents = function(inputComponent, ...)
        npcInteractOriginalFunc(inputComponent, ...)

        if inputComponent.player ~= nil and inputComponent.player.isOwner then
            local actionId = InputAction.NPC_INTERACT
            if actionId == nil then
                print("[NPC Favor] InputAction.NPC_INTERACT not found")
                return
            end

            g_inputBinding:beginActionEventsModification(PlayerInputComponent.INPUT_CONTEXT_NAME)

            local success, eventId = g_inputBinding:registerActionEvent(
                actionId,
                NPCSystem,                   -- Target object (static reference)
                npcInteractActionCallback,    -- Callback function
                false,                        -- triggerUp
                true,                         -- triggerDown
                false,                        -- triggerAlways
                false,                        -- startActive (MUST be false)
                nil,                          -- callbackState
                true                          -- disableConflictingBindings
            )

            g_inputBinding:endActionEventsModification()

            if success and eventId ~= nil then
                npcInteractActionEventId = eventId
                print("[NPC Favor] E key action event registered, eventId=" .. tostring(eventId))
            else
                print("[NPC Favor] Failed to register E key action event")
            end

            -- Register Q key for dialog close
            local closeActionId = InputAction.NPC_DIALOG_CLOSE
            if closeActionId ~= nil then
                local closeSuccess, closeEventId = g_inputBinding:registerActionEvent(
                    closeActionId,
                    NPCSystem,
                    npcDialogCloseCallback,
                    false,                        -- triggerUp
                    true,                         -- triggerDown
                    false,                        -- triggerAlways
                    false,                        -- startActive
                    nil,                          -- callbackState
                    true                          -- disableConflictingBindings
                )

                if closeSuccess and closeEventId ~= nil then
                    npcDialogCloseActionEventId = closeEventId
                    print("[NPC Favor] Q key close action registered, eventId=" .. tostring(closeEventId))
                end
            end
        end
    end

    print("[NPC Favor] PlayerInputComponent hooked for E key interaction")
end

hookNPCInteractInput()

-- Update hook: control E/Q key prompt visibility based on NPC proximity and dialog state
if FSBaseMission and FSBaseMission.update then
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
        if g_inputBinding == nil or not npcSystem then
            return
        end

        local dialogOpen = npcSystem.interactionUI and npcSystem.interactionUI.isDialogOpen

        -- E key: show "Talk to NPC" when near, or "Next option" when dialog open
        if npcInteractActionEventId ~= nil then
            local shouldShow = false
            local promptText = "Talk to NPC"

            if dialogOpen then
                shouldShow = true
                local optionName = npcSystem.interactionUI:getCurrentOptionName()
                promptText = optionName or "Next option"
            elseif npcSystem.nearbyNPCs then
                local nearest = nil
                local nearestDist = 999

                for _, npc in ipairs(npcSystem.nearbyNPCs) do
                    if npc.canInteract and npc.interactionDistance < nearestDist then
                        nearest = npc
                        nearestDist = npc.interactionDistance
                    end
                end

                if nearest then
                    shouldShow = true
                    promptText = string.format("Talk to %s", nearest.name or "NPC")
                end
            end

            g_inputBinding:setActionEventTextPriority(npcInteractActionEventId, GS_PRIO_VERY_HIGH)
            g_inputBinding:setActionEventTextVisibility(npcInteractActionEventId, shouldShow)
            g_inputBinding:setActionEventActive(npcInteractActionEventId, shouldShow)
            if shouldShow then
                g_inputBinding:setActionEventText(npcInteractActionEventId, promptText)
            end
        end

        -- Q key: only show/active when dialog is open
        if npcDialogCloseActionEventId ~= nil then
            g_inputBinding:setActionEventTextPriority(npcDialogCloseActionEventId, GS_PRIO_VERY_HIGH)
            g_inputBinding:setActionEventTextVisibility(npcDialogCloseActionEventId, dialogOpen)
            g_inputBinding:setActionEventActive(npcDialogCloseActionEventId, dialogOpen)
            if dialogOpen then
                g_inputBinding:setActionEventText(npcDialogCloseActionEventId, "Close dialog")
            end
        end
    end)
end

-- =========================================================
-- Multiplayer: Player Join Sync Hook
-- =========================================================
-- When a new player joins, send them full NPC state + settings

if FSBaseMission and FSBaseMission.sendInitialClientState then
    FSBaseMission.sendInitialClientState = Utils.appendedFunction(
        FSBaseMission.sendInitialClientState,
        function(mission, connection, isReconnect)
            if npcSystem and npcSystem.isInitialized then
                print("[NPC Favor] Sending initial state to new client")
                if NPCStateSyncEvent then
                    NPCStateSyncEvent.sendToConnection(connection)
                end
                if NPCSettingsSyncEvent then
                    NPCSettingsSyncEvent.sendAllToConnection(connection)
                end
            end
        end
    )
    print("[NPC Favor] Player join sync hook installed")
end

-- Console commands are registered via addConsoleCommand() in NPCFavorGUI:registerConsoleCommands()

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