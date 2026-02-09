-- =========================================================
-- TODO / FUTURE VISION
-- =========================================================
-- LIFECYCLE:
-- [x] Mission load/unload hooks (Mission00.load, FSBaseMission.delete)
-- [x] Late-join initialization for mid-session mod loading
-- [x] Mission validity checks with performance caching
-- [x] Global system reference (g_NPCSystem) for cross-module access
-- [ ] Graceful degradation when dependencies fail to load
-- [ ] Hot-reload support for development without restarting mission
--
-- INPUT SYSTEM:
-- [x] E key interaction via RVB pattern (PlayerInputComponent hook)
-- [x] Dynamic prompt text showing nearest NPC name
-- [x] Dialog visibility suppression when another dialog is open
-- [ ] Configurable keybind (allow rebinding from E to another key)
-- [ ] Gamepad/controller support for NPC interaction
-- [ ] Multi-NPC selection wheel when several NPCs are nearby
--
-- SAVE/LOAD:
-- [x] XML persistence via FSCareerMissionInfo.saveToXMLFile hook
-- [x] Load from savegame on mission start
-- [x] Multiple missionInfo discovery fallbacks
-- [ ] Save file versioning and migration for future data format changes
-- [ ] Backup/restore of NPC save data on corruption
--
-- MULTIPLAYER:
-- [x] NPCStateSyncEvent for full state sync to joining players
-- [x] NPCSettingsSyncEvent for settings broadcast on join
-- [ ] Per-player interaction cooldowns to prevent spam
-- [ ] Conflict resolution when two players interact with same NPC
-- =========================================================

-- =========================================================
-- FS25 NPC Favor Mod (version 1.2.1.0)
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
local MOD_VERSION = "1.2.1.0"
local MOD_NAME = "FS25_NPCFavor"

local modDirectory = g_currentModDirectory
local modName = g_currentModName

print("[NPC Favor] Starting mod initialization...")

--  Define base classes and utilities
if modDirectory then
    print("[NPC Favor] Loading utility files...")
    source(modDirectory .. "src/utils/VectorHelper.lua")
    source(modDirectory .. "src/utils/TimeHelper.lua")

    -- Configuration & settings
    source(modDirectory .. "src/settings/NPCConfig.lua")
    source(modDirectory .. "src/settings/NPCSettings.lua")
    source(modDirectory .. "src/settings/NPCSettingsIntegration.lua")

    -- Multiplayer events (must load before NPCSystem which references them)
    source(modDirectory .. "src/events/NPCStateSyncEvent.lua")
    source(modDirectory .. "src/events/NPCInteractionEvent.lua")
    source(modDirectory .. "src/events/NPCSettingsSyncEvent.lua")

    -- Core systems in dependency order
    print("[NPC Favor] Loading core systems...")
    source(modDirectory .. "src/scripts/NPCRelationshipManager.lua")
    source(modDirectory .. "src/scripts/NPCFavorSystem.lua")
    source(modDirectory .. "src/scripts/NPCEntity.lua")
    source(modDirectory .. "src/scripts/NPCAI.lua")
    source(modDirectory .. "src/scripts/NPCScheduler.lua")
    source(modDirectory .. "src/scripts/NPCInteractionUI.lua")

    -- GUI
    source(modDirectory .. "src/gui/DialogLoader.lua")
    source(modDirectory .. "src/gui/NPCDialog.lua")
    source(modDirectory .. "src/gui/NPCListDialog.lua")
    source(modDirectory .. "src/settings/NPCFavorGUI.lua")

    -- Main coordinator
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
        -- Register all dialogs via DialogLoader
        if DialogLoader and g_gui then
            DialogLoader.init(modDirectory)
            DialogLoader.register("NPCDialog", NPCDialog, "gui/NPCDialog.xml")
            DialogLoader.register("NPCListDialog", NPCListDialog, "gui/NPCListDialog.xml")

            -- Eagerly load the NPC interaction dialog (used on E-key press)
            DialogLoader.ensureLoaded("NPCDialog")
            npcSystem.npcDialogInstance = DialogLoader.getDialog("NPCDialog")
        end

        -- Initialize NPC entity model loading
        if npcSystem.entityManager and npcSystem.entityManager.initialize then
            npcSystem.entityManager:initialize(modDirectory)
        end

        print("[NPC Favor] Calling onMissionLoaded...")
        npcSystem:onMissionLoaded()
    else
        print("[NPC Favor] ERROR - npcSystem is nil in loadedMission!")

        -- Late initialization fallback
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
        else
            print("[NPC Favor] ERROR - Failed to create NPCSystem")
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
        print("[NPC Favor] Creating NPCSystem instance...")
        npcSystem = NPCSystem.new(mission, modDirectory, modName)

        if npcSystem then
            getfenv(0)["g_NPCSystem"] = npcSystem
            g_NPCFavorMod = {
                version = MOD_VERSION,
                name = MOD_NAME,
                system = npcSystem
            }

            print("[NPC Favor] NPCSystem instance created successfully")

            -- Initialize console commands
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

    -- Clean up dialogs
    if DialogLoader then
        DialogLoader.cleanup()
    end

    if npcSystem ~= nil then
        npcSystem:delete()
        npcSystem = nil
        getfenv(0)["g_NPCSystem"] = nil
        g_NPCFavorMod = nil
        print("[NPC Favor] Unloaded successfully")
    end
end

-- FS25 Game Hooks
print("[NPC Favor] Setting up game hooks...")

if Mission00 and Mission00.load then
    print("[NPC Favor] Hooking Mission00.load")
    Mission00.load = Utils.prependedFunction(Mission00.load, load)
elseif g_currentMission and g_currentMission.load then
    print("[NPC Favor] Hooking g_currentMission.load")
    g_currentMission.load = Utils.prependedFunction(g_currentMission.load, load)
else
    print("[NPC Favor] WARNING - No load function found to hook!")
end

if Mission00 and Mission00.loadMission00Finished then
    print("[NPC Favor] Hooking Mission00.loadMission00Finished")
    Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, loadedMission)
else
    print("[NPC Favor] WARNING - Mission00.loadMission00Finished not found")

    if g_currentMission and g_currentMission.onMissionLoaded then
        print("[NPC Favor] Hooking g_currentMission.onMissionLoaded")
        g_currentMission.onMissionLoaded = Utils.appendedFunction(g_currentMission.onMissionLoaded, function(mission)
            loadedMission(mission, nil)
        end)
    end
end

if FSBaseMission and FSBaseMission.delete then
    print("[NPC Favor] Hooking FSBaseMission.delete")
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)
end

if FSBaseMission and FSBaseMission.update then
    print("[NPC Favor] Hooking FSBaseMission.update")
    FSBaseMission.update = Utils.appendedFunction(FSBaseMission.update, function(mission, dt)
        if npcSystem then
            npcSystem:update(dt)
        end
    end)
end

-- Hook draw for HUD rendering (renderOverlay/renderText are ONLY allowed in draw callbacks)
if FSBaseMission and FSBaseMission.draw then
    print("[NPC Favor] Hooking FSBaseMission.draw")
    FSBaseMission.draw = Utils.appendedFunction(FSBaseMission.draw, function(mission)
        if npcSystem then
            npcSystem:draw()
        end
    end)
end

-- =========================================================
-- Block player from entering NPC vehicles
-- =========================================================
-- Real vehicle spawning is currently disabled — FS25 provides no reliable
-- API to prevent player entry into spawned vehicles. The lockNPCVehicle()
-- code and hooks are preserved for future use when a solution is found.

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
            -- Freeze NPC while player is talking to them
            nearest.isTalking = true

            -- Show dialog via DialogLoader (handles lazy loading + data setting)
            if DialogLoader and DialogLoader.show then
                local dialog = DialogLoader.getDialog("NPCDialog")
                if dialog then
                    dialog:setNPCData(nearest, npcSystem)
                end
                local shown = DialogLoader.show("NPCDialog")
                if not shown then
                    nearest.isTalking = false
                    print("[NPC Favor] DialogLoader failed to show NPCDialog")
                end
            else
                -- Fallback to direct g_gui
                if npcSystem.npcDialogInstance then
                    npcSystem.npcDialogInstance:setNPCData(nearest, npcSystem)
                end
                local ok, err = pcall(function()
                    g_gui:showDialog("NPCDialog")
                end)
                if not ok then
                    nearest.isTalking = false
                    print("[NPC Favor] showDialog FAILED: " .. tostring(err))
                end
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
            local promptText = g_i18n:getText("input_NPC_INTERACT") or "Talk to NPC"
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
                    promptText = string.format(g_i18n:getText("npc_interact_talk_to") or "Talk to %s", nearest.name or "NPC")
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

-- Multiplayer compatibility check
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

-- Late-join: initialize if already in a mission
if g_currentMission and not npcSystem then
    print("[NPC Favor] Already in mission, attempting immediate initialization...")
    load(g_currentMission)
    if g_currentMission.placeables and npcSystem then
        print("[NPC Favor] Mission already loaded, calling onMissionLoaded...")
        npcSystem:onMissionLoaded()
    end
end

addModEventListener({
    onLoad = function()
        print("[NPC Favor] Mod event listener registered")
    end,
    onUnload = function()
        unload()
    end,
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
