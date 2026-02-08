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

--  Define base classes and utilities
if modDirectory then
    source(modDirectory .. "src/utils/VectorHelper.lua")
    source(modDirectory .. "src/utils/TimeHelper.lua")

    -- Configuration & settings
    source(modDirectory .. "src/settings/NPCConfig.lua")
    source(modDirectory .. "src/settings/NPCSettings.lua")
    source(modDirectory .. "src/settings/NPCFavorSettingsManager.lua")
    source(modDirectory .. "src/settings/NPCSettingsIntegration.lua")

    -- Multiplayer events (must load before NPCSystem which references them)
    source(modDirectory .. "src/events/NPCStateSyncEvent.lua")
    source(modDirectory .. "src/events/NPCInteractionEvent.lua")
    source(modDirectory .. "src/events/NPCSettingsSyncEvent.lua")

    -- Core systems in dependency order
    source(modDirectory .. "src/scripts/NPCRelationshipManager.lua")
    source(modDirectory .. "src/scripts/NPCFavorSystem.lua")
    source(modDirectory .. "src/scripts/NPCEntity.lua")
    source(modDirectory .. "src/scripts/NPCAI.lua")
    source(modDirectory .. "src/scripts/NPCScheduler.lua")
    source(modDirectory .. "src/scripts/NPCInteractionUI.lua")

    -- GUI
    source(modDirectory .. "src/gui/NPCDialog.lua")
    source(modDirectory .. "src/settings/NPCFavorGUI.lua")

    -- Main coordinator
    source(modDirectory .. "src/NPCSystem.lua")
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
    if not isMissionValid(mission) then
        return
    end
    
    if npcSystem then
        -- Register NPC dialog with g_gui
        if g_gui and NPCDialog then
            local npcDialog = NPCDialog.new()
            g_gui:loadGui(modDirectory .. "gui/NPCDialog.xml", "NPCDialog", npcDialog)
            npcSystem.npcDialogInstance = npcDialog

            -- Verify registration
            if g_gui.guis and g_gui.guis["NPCDialog"] then
                print("[NPC Favor] NPCDialog registered with g_gui")
            else
                print("[NPC Favor] WARNING: NPCDialog registration failed after loadGui")
            end
        end

        -- Initialize NPC entity model loading
        if npcSystem.entityManager and npcSystem.entityManager.initialize then
            npcSystem.entityManager:initialize(modDirectory)
        end

        npcSystem:onMissionLoaded()
    else
        -- Late initialization fallback
        npcSystem = NPCSystem.new(mission, modDirectory, modName)
        if npcSystem then
            getfenv(0)["g_NPCSystem"] = npcSystem
            g_NPCFavorMod = {
                version = MOD_VERSION,
                name = MOD_NAME,
                system = npcSystem
            }
            npcSystem:onMissionLoaded()
        else
            print("[NPC Favor] ERROR - Failed to create NPCSystem")
        end
    end
end

local function load(mission)
    if not isMissionValid(mission) then
        return
    end

    if npcSystem == nil then
        npcSystem = NPCSystem.new(mission, modDirectory, modName)

        if npcSystem then
            getfenv(0)["g_NPCSystem"] = npcSystem
            g_NPCFavorMod = {
                version = MOD_VERSION,
                name = MOD_NAME,
                system = npcSystem
            }

            -- Initialize console commands
            if npcSystem.gui then
                npcSystem.gui:registerConsoleCommands()
            end
        else
            print("[NPC Favor] ERROR - Failed to create NPCSystem")
        end
    end
end

local function unload()
    if npcSystem ~= nil then
        npcSystem:delete()
        npcSystem = nil
        getfenv(0)["g_NPCSystem"] = nil
        g_NPCFavorMod = nil
    end
end

-- FS25 Game Hooks
if Mission00 and Mission00.load then
    Mission00.load = Utils.prependedFunction(Mission00.load, load)
elseif g_currentMission and g_currentMission.load then
    g_currentMission.load = Utils.prependedFunction(g_currentMission.load, load)
end

if Mission00 and Mission00.loadMission00Finished then
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
elseif g_currentMission and g_currentMission.onMissionLoaded then
    g_currentMission.onMissionLoaded = Utils.appendedFunction(g_currentMission.onMissionLoaded, function(mission)
        loadedMission(mission, nil)
    end)
end

if FSBaseMission and FSBaseMission.delete then
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
end

if FSBaseMission and FSBaseMission.update then
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
local npcInteractOriginalFunc = nil

local function npcInteractActionCallback(self, actionName, inputValue, callbackState, isAnalog)
    if inputValue <= 0 then
        return
    end

    if not npcSystem then
        return
    end

    -- Don't open while another dialog is showing
    if g_gui:getIsDialogVisible() then
        return
    end

    -- Find nearest interactable NPC and open the dialog
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
            -- Verify dialog exists before attempting to show
            if not (g_gui.guis and g_gui.guis["NPCDialog"]) then
                print("[NPC Favor] ERROR: NPCDialog not registered with g_gui")
                return
            end

            -- Set data on dialog instance, then show via g_gui
            if npcSystem.npcDialogInstance then
                npcSystem.npcDialogInstance:setNPCData(nearest, npcSystem)
            end

            local ok, err = pcall(function()
                g_gui:showDialog("NPCDialog")
            end)
            if not ok then
                print("[NPC Favor] showDialog FAILED: " .. tostring(err))
            end
        end
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
            end
        end
    end

end

hookNPCInteractInput()

-- Update hook: control E key prompt visibility based on NPC proximity
if FSBaseMission and FSBaseMission.update then
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
        if g_inputBinding == nil or not npcSystem then
            return
        end

        -- E key: show "Talk to NPC" when near (hide when dialog is open)
        if npcInteractActionEventId ~= nil then
            local shouldShow = false
            local promptText = "Talk to NPC"
            local isDialogOpen = g_gui:getIsDialogVisible()

            if not isDialogOpen and npcSystem.nearbyNPCs then
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
    end)
end

-- Multiplayer: send full NPC state + settings to newly joining players
if FSBaseMission and FSBaseMission.sendInitialClientState then
    FSBaseMission.sendInitialClientState = Utils.appendedFunction(
        FSBaseMission.sendInitialClientState,
        function(mission, connection, isReconnect)
            if npcSystem and npcSystem.isInitialized then
                if NPCStateSyncEvent then
                    NPCStateSyncEvent.sendToConnection(connection)
                end
                if NPCSettingsSyncEvent then
                    NPCSettingsSyncEvent.sendAllToConnection(connection)
                end
            end
        end
    )
end

-- =========================================================
-- Save/Load Persistence (following UsedPlus pattern)
-- =========================================================
-- Save: hook FSCareerMissionInfo.saveToXMLFile
-- Load: called from NPCSystem:onMissionLoaded() after NPC init

-- Discover missionInfo for savegame directory access
local function discoverMissionInfo()
    -- Method 1: g_currentMission.missionInfo
    if g_currentMission and g_currentMission.missionInfo then
        return g_currentMission.missionInfo
    end

    -- Method 2: g_careerScreen.currentSavegame
    if g_careerScreen and g_careerScreen.currentSavegame then
        local savegame = g_careerScreen.currentSavegame
        if savegame and savegame.savegameDirectory then
            return { savegameDirectory = savegame.savegameDirectory }
        end
    end

    -- Method 3: g_currentMission.savegameDirectory
    if g_currentMission and g_currentMission.savegameDirectory then
        return { savegameDirectory = g_currentMission.savegameDirectory }
    end

    return nil
end

-- Hook save — FS25 calls this when the player saves their game
if FSCareerMissionInfo and FSCareerMissionInfo.saveToXMLFile then
    FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(
        FSCareerMissionInfo.saveToXMLFile,
        function(missionInfo)
            if npcSystem and npcSystem.isInitialized then
                npcSystem:saveToXMLFile(missionInfo)
            end
        end
    )
end

-- Hook mission start — load saved NPC data after initialization
if Mission00 and Mission00.onStartMission then
    Mission00.onStartMission = Utils.appendedFunction(
        Mission00.onStartMission,
        function(mission)
            if npcSystem and npcSystem.isInitialized then
                local missionInfo = discoverMissionInfo()
                if missionInfo then
                    npcSystem:loadFromXMLFile(missionInfo)
                end
            end
        end
    )
end

print("[NPC Favor] v" .. MOD_VERSION .. " loaded - type 'npcHelp' for commands")

-- Late-join: initialize if already in a mission
if g_currentMission and not npcSystem then
    load(g_currentMission)
    if g_currentMission.placeables and npcSystem then
        npcSystem:onMissionLoaded()
    end
end

addModEventListener({
    onLoad = function() end,
    onUnload = function()
        unload()
    end,
    onSavegameLoaded = function()
        if npcSystem then
            npcSystem:onMissionLoaded()
        end
    end
})